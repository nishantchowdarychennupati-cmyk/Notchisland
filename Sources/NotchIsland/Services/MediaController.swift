import AppKit

struct NowPlaying: Equatable {
    enum Source: String, CaseIterable {
        case spotify, music, cider

        var appName: String {
            switch self {
            case .spotify: return "Spotify"
            case .music: return "Music"
            case .cider: return "Cider"
            }
        }

        var bundleID: String? {
            switch self {
            case .spotify: return "com.spotify.client"
            case .music: return "com.apple.Music"
            case .cider: return nil
            }
        }

        func isRunning() -> Bool {
            if let bundleID {
                return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
            }
            return NSWorkspace.shared.runningApplications.contains { $0.localizedName?.hasPrefix("Cider") == true }
        }
    }

    var source: Source
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    var duration: Double
    var position: Double
    var artworkURL: String
}

/// Now-playing info for Apple Music, Spotify and Cider.
///
/// Battery: Music and Spotify are event-driven (they broadcast distributed notifications on every change),
/// so we only run a single AppleScript query when something actually changes. Cider is polled over its
/// local API only while Cider is running.
final class MediaController: ObservableObject {
    @Published private(set) var current: NowPlaying?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var accentColor: NSColor?
    private(set) var sampledAt = Date()

    /// Called when a new track starts (title, artist).
    var onTrackChange: ((String, String) -> Void)?

    var isPlaying: Bool { current?.isPlaying ?? false }

    private let prefs: Preferences
    private let queue = DispatchQueue(label: "notchisland.media", qos: .utility)
    private var states: [NowPlaying.Source: NowPlaying] = [:]
    private var artworkKey = ""
    private var lastTrackKey = ""
    private var holdUntil = Date.distantPast
    private var ciderTimer: Timer?
    private var resyncTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(prefs: Preferences) {
        self.prefs = prefs

        let dnc = DistributedNotificationCenter.default()
        observers.append(dnc.addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.refresh(.spotify)
        })
        observers.append(dnc.addObserver(forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] _ in
            self?.refresh(.music)
        })

        let ws = NSWorkspace.shared.notificationCenter
        observers.append(ws.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateCiderPolling()
        })
        observers.append(ws.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            for source in NowPlaying.Source.allCases where source.bundleID == app?.bundleIdentifier || (source == .cider && app?.localizedName?.hasPrefix("Cider") == true) {
                self.states[source] = nil
            }
            self.publish()
            self.updateCiderPolling()
        })

        refreshAll()
        updateCiderPolling()
    }

    /// Called by the island so positions stay accurate only while someone is looking.
    func setVisible(_ visible: Bool) {
        resyncTimer?.invalidate()
        resyncTimer = nil
        guard visible else { return }
        refreshAll()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            self.refreshAll()
        }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        resyncTimer = t
    }

    /// Playback position extrapolated from the last sample.
    func position(at date: Date) -> Double {
        guard let current else { return 0 }
        let elapsed = current.isPlaying ? date.timeIntervalSince(sampledAt) : 0
        return min(current.position + elapsed, max(current.duration, 0))
    }

    // MARK: - Fetching

    func refreshAll() {
        for source in [NowPlaying.Source.spotify, .music] { refresh(source) }
        if prefs.ciderEnabled { refresh(.cider) }
    }

    private func refresh(_ source: NowPlaying.Source) {
        guard source.isRunning() else {
            if states[source] != nil { states[source] = nil; publish() }
            return
        }
        if source == .cider {
            fetchCider()
            return
        }
        queue.async { [weak self] in
            guard let self else { return }
            let value = self.queryAppleScript(source)
            DispatchQueue.main.async {
                self.states[source] = value
                self.publish()
            }
        }
    }

    private func queryAppleScript(_ source: NowPlaying.Source) -> NowPlaying? {
        let artExpr = source == .spotify ? "(artwork url of current track)" : "\"\""
        let durExpr = source == .spotify ? "((duration of current track) / 1000)" : "(duration of current track)"
        let script = """
        tell application "\(source.appName)"
            if player state is stopped then return "stopped"
            set t to name of current track
            set a to artist of current track
            set al to album of current track
            set d to \(durExpr) as string
            set p to player position as string
            return (player state as string) & "||" & t & "||" & a & "||" & \(artExpr) & "||" & d & "||" & p & "||" & al
        end tell
        """
        var error: NSDictionary?
        guard let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue,
              output != "stopped"
        else { return nil }

        let parts = output.components(separatedBy: "||")
        guard parts.count >= 7 else { return nil }
        func number(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }

        return NowPlaying(
            source: source, title: parts[1], artist: parts[2], album: parts[6],
            isPlaying: parts[0] == "playing", duration: number(parts[4]), position: number(parts[5]),
            artworkURL: parts[3]
        )
    }

    // MARK: - Cider (local RPC API on port 10767)

    private func updateCiderPolling() {
        let shouldPoll = prefs.ciderEnabled && NowPlaying.Source.cider.isRunning()
        if shouldPoll && ciderTimer == nil {
            let t = Timer(timeInterval: 2.5, repeats: true) { [weak self] _ in self?.fetchCider() }
            t.tolerance = 1
            RunLoop.main.add(t, forMode: .common)
            ciderTimer = t
            fetchCider()
        } else if !shouldPoll, let t = ciderTimer {
            t.invalidate()
            ciderTimer = nil
            states[.cider] = nil
            publish()
        }
    }

    private func ciderRequest(_ path: String, method: String = "GET", body: [String: Any]? = nil) -> URLRequest? {
        guard let url = URL(string: "http://localhost:10767/api/v1/playback/\(path)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 2)
        request.httpMethod = method
        if !prefs.ciderToken.isEmpty { request.setValue(prefs.ciderToken, forHTTPHeaderField: "apptoken") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func fetchCider() {
        guard let request = ciderRequest("now-playing") else { return }
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self else { return }
            var value: NowPlaying?
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let info = json["info"] as? [String: Any] {
                let artwork = (info["artwork"] as? [String: Any])?["url"] as? String ?? ""
                let duration = (info["durationInMillis"] as? Double ?? 0) / 1000
                let position = info["currentPlaybackTime"] as? Double ?? 0
                let playing = info["isPlaying"] as? Bool ?? ((json["is_playing"] as? Bool) ?? true)
                value = NowPlaying(
                    source: .cider,
                    title: info["name"] as? String ?? "",
                    artist: info["artistName"] as? String ?? "",
                    album: info["albumName"] as? String ?? "",
                    isPlaying: playing,
                    duration: duration,
                    position: position,
                    artworkURL: artwork.replacingOccurrences(of: "{w}", with: "300").replacingOccurrences(of: "{h}", with: "300")
                )
                if value?.title.isEmpty == true { value = nil }
            }
            DispatchQueue.main.async {
                self.states[.cider] = value
                self.publish()
            }
        }.resume()
    }

    // MARK: - Publishing

    private func publish() {
        if Date() < holdUntil { return }
        let candidates = states.values.filter { track in
            switch prefs.preferredPlayer {
            case .auto: return true
            case .music: return track.source == .music
            case .spotify: return track.source == .spotify
            case .cider: return track.source == .cider
            }
        }
        let order: [NowPlaying.Source] = [.music, .spotify, .cider]
        let pick = candidates.first(where: \.isPlaying)
            ?? candidates.sorted { (order.firstIndex(of: $0.source) ?? 0) < (order.firstIndex(of: $1.source) ?? 0) }.first

        sampledAt = Date()
        if current != pick { current = pick }

        guard let pick else {
            artworkKey = ""
            if artwork != nil { artwork = nil }
            if accentColor != nil { accentColor = nil }
            return
        }
        let key = "\(pick.source.rawValue)|\(pick.title)|\(pick.artist)|\(pick.album)"
        if key != artworkKey {
            artworkKey = key
            loadArtwork(for: pick, key: key)
        }
        let trackKey = "\(pick.title)|\(pick.artist)"
        if trackKey != lastTrackKey {
            let isFirst = lastTrackKey.isEmpty
            lastTrackKey = trackKey
            if !isFirst && pick.isPlaying { onTrackChange?(pick.title, pick.artist) }
        }
    }

    private func loadArtwork(for track: NowPlaying, key: String) {
        let deliver: (NSImage?) -> Void = { [weak self] image in
            DispatchQueue.main.async {
                guard let self, self.artworkKey == key else { return }
                self.artwork = image
                self.accentColor = image?.vibrantAverageColor()
            }
        }
        switch track.source {
        case .spotify, .cider:
            guard let url = URL(string: track.artworkURL), !track.artworkURL.isEmpty else { return deliver(nil) }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                deliver(data.flatMap(NSImage.init(data:)))
            }.resume()
        case .music:
            queue.async {
                var error: NSDictionary?
                let script = NSAppleScript(source: "tell application \"Music\" to get raw data of artwork 1 of current track")
                let data = script?.executeAndReturnError(&error).data
                deliver(data.flatMap(NSImage.init(data:)))
            }
        }
    }

    // MARK: - Controls

    func playPause() {
        if var track = current {
            track.position = position(at: Date())
            track.isPlaying.toggle()
            sampledAt = Date()
            current = track
            states[track.source] = track
        }
        send(apple: "playpause", cider: "playpause")
    }

    func nextTrack() { send(apple: "next track", cider: "next") }
    func previousTrack() { send(apple: "previous track", cider: "previous") }

    func seek(to seconds: Double) {
        if var track = current {
            track.position = seconds
            sampledAt = Date()
            current = track
            states[track.source] = track
        }
        send(apple: "set player position to \(Int(seconds))", cider: "seek", body: ["position": Int(seconds)])
    }

    func launch(_ source: NowPlaying.Source) {
        guard let id = source.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    func isInstalled(_ source: NowPlaying.Source) -> Bool {
        guard let id = source.bundleID else { return false }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
    }

    private func send(apple command: String, cider: String, body: [String: Any]? = nil) {
        guard let source = current?.source else { return }
        holdUntil = Date().addingTimeInterval(0.6)
        let refreshLater = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { self?.refresh(source) }
        }
        if source == .cider {
            guard let request = ciderRequest(cider, method: "POST", body: body) else { return }
            URLSession.shared.dataTask(with: request) { _, _, _ in refreshLater() }.resume()
            return
        }
        queue.async {
            var error: NSDictionary?
            NSAppleScript(source: "tell application \"\(source.appName)\" to \(command)")?.executeAndReturnError(&error)
            refreshLater()
        }
    }
}
