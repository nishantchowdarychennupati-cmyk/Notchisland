import AppKit

struct NowPlaying: Equatable {
    enum Source: String {
        case spotify, music

        var appName: String { self == .spotify ? "Spotify" : "Music" }
        var bundleID: String { self == .spotify ? "com.spotify.client" : "com.apple.Music" }
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

/// Reads now-playing info from Music and Spotify via AppleScript.
/// (Apple's private MediaRemote framework is locked down on recent macOS, so we ask the apps directly.)
final class MediaController: ObservableObject {
    @Published private(set) var current: NowPlaying?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var accentColor: NSColor?
    private(set) var sampledAt = Date()

    var isPlaying: Bool { current?.isPlaying ?? false }

    private let prefs: Preferences
    private let queue = DispatchQueue(label: "notchisland.applescript", qos: .userInitiated)
    private var timer: Timer?
    private var artworkKey = ""
    private var holdUntil = Date.distantPast

    init(prefs: Preferences) {
        self.prefs = prefs
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()
    }

    /// Playback position extrapolated from the last sample.
    func position(at date: Date) -> Double {
        guard let current else { return 0 }
        let elapsed = current.isPlaying ? date.timeIntervalSince(sampledAt) : 0
        return min(current.position + elapsed, max(current.duration, 0))
    }

    // MARK: - Polling

    func poll() {
        var sources: [NowPlaying.Source] = [.spotify, .music]
        switch prefs.preferredPlayer {
        case .music: sources = [.music]
        case .spotify: sources = [.spotify]
        case .auto: break
        }
        // Only talk to apps that are already running, so we never launch them.
        let running = sources.filter {
            !NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleID).isEmpty
        }
        queue.async { [weak self] in
            guard let self else { return }
            let results = running.compactMap { self.query($0) }
            let pick = results.first(where: \.isPlaying) ?? results.first
            DispatchQueue.main.async { self.apply(pick) }
        }
    }

    private func query(_ source: NowPlaying.Source) -> NowPlaying? {
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
            source: source,
            title: parts[1],
            artist: parts[2],
            album: parts[6],
            isPlaying: parts[0] == "playing",
            duration: number(parts[4]),
            position: number(parts[5]),
            artworkURL: parts[3]
        )
    }

    private func apply(_ value: NowPlaying?) {
        // Ignore stale polls right after a user action so the UI doesn't flicker.
        if Date() < holdUntil { return }
        sampledAt = Date()
        if current != value { current = value }

        guard let value else {
            artworkKey = ""
            if artwork != nil { artwork = nil }
            if accentColor != nil { accentColor = nil }
            return
        }
        let key = "\(value.source.rawValue)|\(value.title)|\(value.artist)|\(value.album)"
        if key != artworkKey {
            artworkKey = key
            loadArtwork(for: value, key: key)
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
        case .spotify:
            guard let url = URL(string: track.artworkURL) else { return deliver(nil) }
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
        }
        send("playpause")
    }

    func nextTrack() { send("next track") }
    func previousTrack() { send("previous track") }

    func seek(to seconds: Double) {
        if var track = current {
            track.position = seconds
            sampledAt = Date()
            current = track
        }
        send("set player position to \(Int(seconds))")
    }

    func launch(_ source: NowPlaying.Source) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    func isInstalled(_ source: NowPlaying.Source) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) != nil
    }

    private func send(_ command: String) {
        guard let source = current?.source else { return }
        holdUntil = Date().addingTimeInterval(0.6)
        queue.async { [weak self] in
            var error: NSDictionary?
            NSAppleScript(source: "tell application \"\(source.appName)\" to \(command)")?.executeAndReturnError(&error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { self?.poll() }
        }
    }
}
