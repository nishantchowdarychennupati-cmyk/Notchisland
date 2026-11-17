import Foundation

/// Countdown timer with pause support and a Pomodoro (focus / break cycle) mode.
final class QuickTimer: ObservableObject {
    enum Kind: Equatable {
        case simple
        case focus(round: Int)
        case shortBreak(round: Int)
        case longBreak

        var label: String {
            switch self {
            case .simple: return "Timer"
            case .focus: return "Focus"
            case .shortBreak: return "Break"
            case .longBreak: return "Long Break"
            }
        }

        var isPomodoro: Bool { self != .simple }
        var isBreak: Bool {
            switch self {
            case .shortBreak, .longBreak: return true
            default: return false
            }
        }
    }

    struct PomodoroConfig {
        var focus: Double, shortBreak: Double, longBreak: Double, rounds: Int
    }

    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining: TimeInterval?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0
    @Published private(set) var kind: Kind = .simple

    /// Called when a plain timer ends.
    var onFinish: (() -> Void)?
    /// Called when a Pomodoro phase changes (new phase).
    var onPhaseChange: ((Kind) -> Void)?

    private var ticker: Timer?
    private var config = PomodoroConfig(focus: 25, shortBreak: 5, longBreak: 15, rounds: 4)

    var isRunning: Bool { endDate != nil || pausedRemaining != nil }
    var isPaused: Bool { pausedRemaining != nil }
    var formatted: String { formatTime(remaining.rounded(.up)) }
    var fractionRemaining: Double { total > 0 ? min(1, remaining / total) : 0 }
    var roundsTotal: Int { config.rounds }

    func start(minutes: Double) {
        kind = .simple
        begin(seconds: minutes * 60)
    }

    func startPomodoro(_ config: PomodoroConfig) {
        self.config = config
        kind = .focus(round: 1)
        begin(seconds: config.focus * 60)
    }

    /// Skips to the next Pomodoro phase.
    func skipPhase() {
        guard kind.isPomodoro else { return cancel() }
        advancePomodoro()
    }

    func add(minutes: Double) {
        let extra = minutes * 60
        if let paused = pausedRemaining {
            pausedRemaining = paused + extra
            remaining = paused + extra
        } else if let endDate {
            self.endDate = endDate.addingTimeInterval(extra)
            tick()
        } else {
            return start(minutes: minutes)
        }
        total = max(total, remaining)
    }

    func pause() {
        guard let endDate else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        self.endDate = nil
        ticker?.invalidate()
        ticker = nil
    }

    func resume() {
        guard let paused = pausedRemaining else { return }
        pausedRemaining = nil
        endDate = Date().addingTimeInterval(paused)
        startTicker()
    }

    func cancel() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        pausedRemaining = nil
        remaining = 0
        kind = .simple
    }

    private func begin(seconds: Double) {
        total = seconds
        pausedRemaining = nil
        endDate = Date().addingTimeInterval(seconds)
        remaining = seconds
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        // One tick per second is all the display needs; tolerance lets macOS coalesce wake-ups.
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        guard let endDate else { return }
        let left = max(0, endDate.timeIntervalSinceNow)
        remaining = left
        guard left <= 0.05 else { return }
        if kind.isPomodoro {
            advancePomodoro()
        } else {
            cancel()
            onFinish?()
        }
    }

    private func advancePomodoro() {
        let next: Kind
        switch kind {
        case .focus(let round):
            next = round >= config.rounds ? .longBreak : .shortBreak(round: round)
        case .shortBreak(let round):
            next = .focus(round: round + 1)
        case .longBreak, .simple:
            next = .focus(round: 1)
        }
        kind = next
        switch next {
        case .focus: begin(seconds: config.focus * 60)
        case .shortBreak: begin(seconds: config.shortBreak * 60)
        case .longBreak: begin(seconds: config.longBreak * 60)
        case .simple: break
        }
        onPhaseChange?(next)
    }
}
