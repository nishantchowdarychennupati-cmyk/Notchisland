import Foundation

/// Stopwatch with laps. It stores only start times, so it costs nothing while running;
/// views that show it redraw on their own schedule.
final class Stopwatch: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var accumulated: TimeInterval = 0
    /// Total elapsed time at each lap, newest first.
    @Published private(set) var laps: [TimeInterval] = []
    private(set) var startedAt: Date?

    var hasTime: Bool { isRunning || accumulated > 0 }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        accumulated + (startedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    func start() {
        guard !isRunning else { return }
        startedAt = Date()
        isRunning = true
    }

    func pause() {
        guard isRunning, let startedAt else { return }
        accumulated += Date().timeIntervalSince(startedAt)
        self.startedAt = nil
        isRunning = false
    }

    func toggle() { isRunning ? pause() : start() }

    func lap() {
        guard isRunning else { return }
        laps.insert(elapsed(), at: 0)
    }

    func reset() {
        startedAt = nil
        isRunning = false
        accumulated = 0
        laps = []
    }
}

/// "1:23.45" (with hundredths) or "1:23" / "1:02:03".
func formatStopwatch(_ t: TimeInterval, hundredths: Bool) -> String {
    let total = max(t, 0)
    let hours = Int(total) / 3600
    let minutes = (Int(total) % 3600) / 60
    let seconds = Int(total) % 60
    if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
    if hundredths {
        let centis = Int((total - floor(total)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, centis)
    }
    return String(format: "%d:%02d", minutes, seconds)
}
