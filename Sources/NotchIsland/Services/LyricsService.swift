import Foundation

struct LyricLine: Equatable {
    let time: Double
    let text: String
}

/// Fetches lyrics from LRCLIB (lrclib.net), a free, open lyrics database.
/// One request per song, only while the Now Playing tab is visible, and results are cached.
final class LyricsService: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case synced([LyricLine])
        case plain(String)
        case notFound
    }

    @Published private(set) var state: State = .idle

    private var cache: [String: State] = [:]
    private var currentKey = ""
    private var task: URLSessionDataTask?

    func load(title: String, artist: String, album: String, duration: Double) {
        let key = "\(artist.lowercased())|\(title.lowercased())"
        guard key != currentKey else { return }
        currentKey = key
        task?.cancel()
        if let cached = cache[key] {
            state = cached
            return
        }
        state = .loading

        var items = [URLQueryItem(name: "artist_name", value: artist), URLQueryItem(name: "track_name", value: title)]
        if !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
        if duration > 0 { items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }

        fetch(path: "get", items: items) { [weak self] result in
            guard let self else { return }
            if result != .notFound {
                return self.finish(key: key, result)
            }
            // Exact match failed (album or length differ slightly); fall back to a search.
            let searchItems = [URLQueryItem(name: "artist_name", value: artist), URLQueryItem(name: "track_name", value: title)]
            self.fetch(path: "search", items: searchItems) { [weak self] result in
                self?.finish(key: key, result)
            }
        }
    }

    func clear() {
        task?.cancel()
        currentKey = ""
        state = .idle
    }

    private func finish(key: String, _ result: State) {
        DispatchQueue.main.async {
            self.cache[key] = result
            if self.currentKey == key { self.state = result }
        }
    }

    private func fetch(path: String, items: [URLQueryItem], completion: @escaping (State) -> Void) {
        var components = URLComponents(string: "https://lrclib.net/api/\(path)")
        components?.queryItems = items
        guard let url = components?.url else { return completion(.notFound) }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("NotchIsland/3.3", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if (error as? URLError)?.code == .cancelled { return }
            guard let data, (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data)
            else { return completion(.notFound) }

            let candidates: [[String: Any]]
            if let object = json as? [String: Any] {
                candidates = [object]
            } else if let array = json as? [[String: Any]] {
                candidates = array
            } else {
                candidates = []
            }
            if let synced = candidates.lazy.compactMap({ $0["syncedLyrics"] as? String }).first(where: { !$0.isEmpty }) {
                let lines = Self.parse(synced)
                if !lines.isEmpty { return completion(.synced(lines)) }
            }
            if let plain = candidates.lazy.compactMap({ $0["plainLyrics"] as? String }).first(where: { !$0.isEmpty }) {
                return completion(.plain(plain))
            }
            completion(.notFound)
        }
        self.task = task
        task.resume()
    }

    /// Parses LRC text like "[01:23.45] Some words".
    static func parse(_ lrc: String) -> [LyricLine] {
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d{1,2}):(\d{1,2}(?:[.:]\d{1,3})?)\]"#) else { return [] }
        var lines: [LyricLine] = []
        for raw in lrc.components(separatedBy: .newlines) {
            let ns = raw as NSString
            let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
            guard let last = matches.last else { continue }
            let text = ns.substring(from: last.range.location + last.range.length).trimmingCharacters(in: .whitespaces)
            for match in matches {
                let minutes = Double(ns.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: match.range(at: 2)).replacingOccurrences(of: ":", with: ".")) ?? 0
                lines.append(LyricLine(time: minutes * 60 + seconds, text: text))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }
}
