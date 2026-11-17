import AppKit
import Combine
import SwiftUI

/// Short-lived alerts that pop the island out, like a charging notice.
enum Peek: Equatable {
    case charging(Int)
    case lowBattery(Int)
    case timerDone
    case event(title: String, minutes: Int)
    case shelfAdded(Int)
}

enum IslandTab: String {
    case home, shelf
}

/// What the closed island currently shows beside the notch.
enum CompactContent: Equatable {
    case none
    case peek(Peek)
    case timer
    case media
    case shelf
}

final class IslandModel: ObservableObject {
    @Published var isOpen = false
    @Published var tab: IslandTab = .home
    @Published var isDropTargeted = false
    @Published var hasNotch = true
    @Published var notchSize = CGSize(width: 200, height: 32)
    @Published private(set) var peek: Peek?

    let prefs = Preferences.shared
    let media: MediaController
    let battery = BatteryMonitor()
    let timer = QuickTimer()
    let calendar: CalendarService
    let shelf = ShelfStore()

    /// Set by the app delegate so views can open the settings window.
    var openSettingsHandler: (() -> Void)?

    private var peekWork: DispatchWorkItem?
    private var lowBatteryShown = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        media = MediaController(prefs: Preferences.shared)
        calendar = CalendarService(prefs: Preferences.shared)

        battery.onPluggedIn = { [weak self] level in
            guard let self, self.prefs.chargingAlert else { return }
            self.lowBatteryShown = false
            self.showPeek(.charging(level), for: 3)
        }
        timer.onFinish = { [weak self] in
            guard let self else { return }
            NSSound(named: self.prefs.timerSound)?.play()
            self.showPeek(.timerDone, for: 6)
        }
        calendar.onEventSoon = { [weak self] title, minutes in
            guard let self, self.prefs.calendarAlerts else { return }
            self.showPeek(.event(title: title, minutes: minutes), for: 6)
        }

        battery.$level
            .combineLatest(battery.$isPluggedIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level, plugged in self?.checkLowBattery(level: level, plugged: plugged) }
            .store(in: &cancellables)

        // Re-publish child changes so geometry and accent stay in sync.
        let children = [media.objectWillChange, timer.objectWillChange, battery.objectWillChange,
                        calendar.objectWillChange, shelf.objectWillChange, prefs.objectWillChange]
        for publisher in children {
            publisher.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        }

        if (prefs.calendarWidget || prefs.calendarAlerts) && calendar.needsPermission {
            calendar.requestAccess()
        }
    }

    // MARK: - Open / close

    func open(tab: IslandTab? = nil) {
        if let tab { self.tab = tab }
        guard !isOpen else { return }
        isOpen = true
        if prefs.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.isOpen else { return }
            self.tab = .home
        }
    }

    func openSettings() {
        close()
        openSettingsHandler?()
    }

    // MARK: - Alerts

    func showPeek(_ peek: Peek, for seconds: TimeInterval) {
        peekWork?.cancel()
        self.peek = peek
        let work = DispatchWorkItem { [weak self] in self?.peek = nil }
        peekWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func checkLowBattery(level: Int, plugged: Bool) {
        guard battery.hasBattery else { return }
        if plugged || level > prefs.lowBatteryThreshold {
            lowBatteryShown = false
            return
        }
        if prefs.lowBatteryAlert && !lowBatteryShown {
            lowBatteryShown = true
            showPeek(.lowBattery(level), for: 5)
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard prefs.shelfEnabled else { return false }
        return shelf.handleDrop(providers) { [weak self] count in
            guard let self, count > 0 else { return }
            self.tab = .shelf
            if !self.isOpen { self.showPeek(.shelfAdded(count), for: 2.5) }
        }
    }

    // MARK: - Geometry

    var compact: CompactContent {
        if let peek { return .peek(peek) }
        if timer.isRunning && prefs.timerActivity { return .timer }
        if prefs.mediaActivity, let track = media.current, track.isPlaying || prefs.showPausedMedia { return .media }
        if prefs.shelfEnabled && prefs.shelfBadge && !shelf.items.isEmpty { return .shelf }
        return .none
    }

    /// Width added on each side of the notch while closed.
    var compactSide: CGFloat {
        switch compact {
        case .none: return 0
        case .peek: return 78
        case .timer: return 66
        case .media: return 44
        case .shelf: return 40
        }
    }

    /// Size of the island body (excluding the small flares at the top corners).
    var currentSize: CGSize {
        if isOpen {
            let width = max(CGFloat(prefs.expandedWidth), notchSize.width + 260)
            return CGSize(width: width, height: notchSize.height + 140)
        }
        return CGSize(width: notchSize.width + 2 * compactSide, height: notchSize.height)
    }

    var topRadius: CGFloat { isOpen ? 14 : 6 }
    var bottomRadius: CGFloat { isOpen ? CGFloat(prefs.cornerRadius) : 10 }

    /// Hide the closed pill on screens without a notch when there's nothing to show.
    var isVisible: Bool { hasNotch || isOpen || compactSide > 0 }

    var accent: Color {
        switch prefs.accentMode {
        case .artwork:
            if let color = media.accentColor { return Color(nsColor: color) }
            return Color(nsColor: .controlAccentColor)
        case .system:
            return Color(nsColor: .controlAccentColor)
        case .custom:
            return Color(hex: prefs.customAccentHex) ?? .orange
        }
    }
}

/// Countdown timer with pause support.
final class QuickTimer: ObservableObject {
    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining: TimeInterval?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0
    var onFinish: (() -> Void)?

    private var ticker: Timer?

    var isRunning: Bool { endDate != nil || pausedRemaining != nil }
    var isPaused: Bool { pausedRemaining != nil }
    var formatted: String { formatTime(remaining.rounded(.up)) }
    var fractionRemaining: Double { total > 0 ? min(1, remaining / total) : 0 }

    func start(minutes: Double) {
        total = minutes * 60
        pausedRemaining = nil
        endDate = Date().addingTimeInterval(total)
        startTicker()
        tick()
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
    }

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        guard let endDate else { return }
        let left = max(0, endDate.timeIntervalSinceNow)
        if Int(left.rounded(.up)) != Int(remaining.rounded(.up)) || left == 0 {
            remaining = left
        }
        if left <= 0 {
            cancel()
            onFinish?()
        }
    }
}
