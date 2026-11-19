import AppKit
import Combine
import SwiftUI

/// Short-lived pop-outs shown beside the notch while the island is closed.
enum Peek: Equatable {
    case charging(Int)
    case lowBattery(Int)
    case timerDone
    case pomodoro(String)
    case event(title: String, minutes: Int)
    case shelfAdded(Int)
    case volume(Float, muted: Bool)
    case brightness(Float)
    case device(name: String, symbol: String)
    case track(title: String, artist: String)
    case shortcut(name: String, ok: Bool)
    case copied

    /// Identity used for transitions: values of the same kind update in place (e.g. a volume bar).
    var key: String {
        switch self {
        case .charging: return "charging"
        case .lowBattery: return "low"
        case .timerDone: return "done"
        case .pomodoro: return "pomodoro"
        case .event: return "event"
        case .shelfAdded: return "shelf"
        case .volume: return "volume"
        case .brightness: return "brightness"
        case .device: return "device"
        case .track: return "track"
        case .shortcut: return "shortcut"
        case .copied: return "copied"
        }
    }

    /// Width added on each side of the notch.
    var side: CGFloat {
        switch self {
        case .volume, .brightness: return 104
        case .device, .track: return 116
        case .shortcut, .pomodoro: return 100
        default: return 78
        }
    }
}

/// What the closed island shows beside the notch.
enum CompactContent: Equatable {
    case none
    case peek(Peek)
    case recording
    case timer
    case stopwatch
    case media
    case shelf

    var key: String {
        switch self {
        case .none: return "none"
        case .peek(let p): return "peek-" + p.key
        case .recording: return "recording"
        case .timer: return "timer"
        case .stopwatch: return "stopwatch"
        case .media: return "media"
        case .shelf: return "shelf"
        }
    }
}

final class IslandModel: ObservableObject {
    @Published var isOpen = false
    @Published var tab: IslandTab = .home {
        didSet { UserDefaults.standard.set(tab.rawValue, forKey: "lastTab") }
    }
    /// -1...1 while a continuous swipe is between tabs; drives the sliding tab indicator.
    @Published var swipeProgress: Double = 0
    @Published var timerMode: TimerMode = .timer
    @Published var isDropTargeted = false
    @Published var isHovering = false
    /// Direction of the last tab change, used for directional transitions.
    @Published private(set) var tabForward = true
    @Published var hasNotch = true
    @Published var notchSize = CGSize(width: 200, height: 32)
    @Published private(set) var peek: Peek?

    let prefs = Preferences.shared
    let power = PowerManager()
    let media: MediaController
    let battery = BatteryMonitor()
    let timer = QuickTimer()
    let stopwatch = Stopwatch()
    let calendar: CalendarService
    let shelf = ShelfStore()
    let clipboard: ClipboardStore
    let audio = SystemAudio()
    let brightness = BrightnessController()
    let stats = SystemStats()
    let camera = CameraController()
    let shortcuts = ShortcutsService()
    let lyrics = LyricsService()
    let dictation: DictationService

    /// Set by the app delegate so views can open the settings window.
    var openSettingsHandler: (() -> Void)?

    private var peekWork: DispatchWorkItem?
    private var lowBatteryShown = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        let prefs = Preferences.shared
        media = MediaController(prefs: prefs)
        calendar = CalendarService(prefs: prefs)
        clipboard = ClipboardStore(prefs: prefs)
        dictation = DictationService(prefs: prefs)
        // Start on the tab you last used (if enabled), otherwise the default tab.
        if prefs.rememberTab, let raw = UserDefaults.standard.string(forKey: "lastTab"),
           let last = IslandTab(rawValue: raw), prefs.isEnabled(last) {
            tab = last
        } else {
            tab = prefs.defaultTab
        }

        wireEvents()
        wireServices()

        if (prefs.calendarAlerts || prefs.isEnabled(.agenda)) && calendar.needsPermission {
            calendar.requestAccess()
        }
    }

    // MARK: - Event wiring

    private func wireEvents() {
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
        timer.onPhaseChange = { [weak self] kind in
            guard let self else { return }
            NSSound(named: self.prefs.timerSound)?.play()
            self.showPeek(.pomodoro(kind.isBreak ? "Break time" : "Focus"), for: 5)
        }
        calendar.onEventSoon = { [weak self] title, minutes in
            guard let self, self.prefs.calendarAlerts else { return }
            self.showPeek(.event(title: title, minutes: minutes), for: 6)
        }
        audio.onVolumeChange = { [weak self] volume, muted in
            guard let self, self.prefs.hudVolume else { return }
            self.showPeek(.volume(volume, muted: muted), for: 1.6)
        }
        audio.onOutputChange = { [weak self] name, symbol in
            guard let self, self.prefs.hudDevices else { return }
            self.showPeek(.device(name: name, symbol: symbol), for: 3)
        }
        brightness.onChange = { [weak self] value in
            guard let self, self.prefs.hudBrightness else { return }
            self.showPeek(.brightness(value), for: 1.6)
        }
        media.onTrackChange = { [weak self] title, artist in
            guard let self, self.prefs.trackChangeAlert, self.prefs.mediaActivity, !self.isOpen else { return }
            if let peek = self.peek, peek.key != "track" { return }
            self.showPeek(.track(title: title, artist: artist), for: 3)
        }
        shortcuts.onFinish = { [weak self] name, ok in
            self?.showPeek(.shortcut(name: name, ok: ok), for: 2.5)
        }
        dictation.onFinished = { [weak self] text in
            guard let self, self.prefs.dictationAutoCopy else { return }
            self.clipboard.copyText(text)
            if !self.isOpen { self.showPeek(.copied, for: 2) }
        }

        battery.$level
            .combineLatest(battery.$isPluggedIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level, plugged in self?.checkLowBattery(level: level, plugged: plugged) }
            .store(in: &cancellables)

        // Re-publish child changes so geometry and accent stay in sync.
        let children: [ObservableObjectPublisher] = [
            media.objectWillChange, timer.objectWillChange, battery.objectWillChange,
            calendar.objectWillChange, shelf.objectWillChange, prefs.objectWillChange,
            dictation.objectWillChange, power.objectWillChange, stopwatch.objectWillChange
        ]
        for publisher in children {
            publisher.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        }
    }

    /// Starts and stops services so that only what's on screen (or switched on) uses power.
    private func wireServices() {
        Publishers.CombineLatest($isOpen, $tab)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] open, tab in self?.updateVisibleServices(open: open, tab: tab) }
            .store(in: &cancellables)

        prefs.objectWillChange.merge(with: power.objectWillChange)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateBackgroundServices() }
            .store(in: &cancellables)

        updateBackgroundServices()
    }

    private func updateVisibleServices(open: Bool, tab: IslandTab) {
        let visible: IslandTab? = open ? tab : nil
        media.setVisible(visible == .home)
        if visible == .system {
            stats.start(interval: prefs.statsInterval)
            brightness.check(announce: false)
        } else {
            stats.stop()
        }
        if visible == .mirror { camera.start() } else { camera.stop() }
        if visible == .actions { shortcuts.loadIfNeeded() }
        if visible == .agenda { calendar.reload() }
    }

    private func updateBackgroundServices() {
        let awake = !power.isScreenAsleep
        if prefs.isEnabled(.clipboard) && awake { clipboard.start() } else { clipboard.stop() }
        if prefs.hudBrightness && awake { brightness.startMonitoring() } else { brightness.stopMonitoring() }
    }

    // MARK: - Open / close

    func open(tab: IslandTab? = nil) {
        if let tab {
            self.tab = tab
        } else if !isOpen, !prefs.rememberTab, prefs.isEnabled(prefs.defaultTab) {
            self.tab = prefs.defaultTab
        }
        if !prefs.isEnabled(self.tab) { self.tab = .home }
        guard !isOpen else { return }
        isOpen = true
        if prefs.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
    }

    /// Selects a tab, remembering the direction for the transition.
    func select(_ newTab: IslandTab) {
        guard newTab != tab else { return }
        let all = IslandTab.allCases
        tabForward = (all.firstIndex(of: newTab) ?? 0) > (all.firstIndex(of: tab) ?? 0)
        withAnimation(islandSpring) { tab = newTab }
        if prefs.tabHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    /// Moves to the next/previous enabled tab (used by trackpad swipes). Returns false at the ends.
    @discardableResult
    func switchTab(by offset: Int) -> Bool {
        let tabs = prefs.enabledTabs
        guard tabs.count > 1, let index = tabs.firstIndex(of: tab) else { return false }
        var next = index + offset
        if prefs.wrapTabs {
            next = (next % tabs.count + tabs.count) % tabs.count
        } else if next < 0 || next >= tabs.count {
            return false
        }
        select(tabs[next])
        return true
    }

    func openSettings() {
        close()
        openSettingsHandler?()
    }

    // MARK: - Alerts

    func showPeek(_ peek: Peek, for seconds: TimeInterval) {
        guard !power.isScreenAsleep else { return }
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
        guard prefs.isEnabled(.shelf) else { return false }
        return shelf.handleDrop(providers) { [weak self] count in
            guard let self, count > 0 else { return }
            self.tab = .shelf
            if !self.isOpen { self.showPeek(.shelfAdded(count), for: 2.5) }
        }
    }

    // MARK: - Geometry

    var compact: CompactContent {
        if let peek { return .peek(peek) }
        if dictation.isRecording { return .recording }
        if timer.isRunning && prefs.timerActivity { return .timer }
        if stopwatch.isRunning && prefs.timerActivity { return .stopwatch }
        if prefs.mediaActivity, let track = media.current, track.isPlaying || prefs.showPausedMedia { return .media }
        if prefs.isEnabled(.shelf) && prefs.shelfBadge && !shelf.items.isEmpty { return .shelf }
        return .none
    }

    /// Width added on each side of the notch while closed.
    var compactSide: CGFloat {
        switch compact {
        case .none: return 0
        case .peek(let p): return p.side
        case .recording: return 60
        case .timer: return 70
        case .stopwatch: return 70
        case .media: return 44
        case .shelf: return 40
        }
    }

    /// Size of the island body (excluding the small flares at the top corners).
    var currentSize: CGSize {
        if isOpen {
            let width = max(CGFloat(prefs.expandedWidth), notchSize.width + 300)
            return CGSize(width: width, height: notchSize.height + 32 + contentHeight)
        }
        let grow = isHovering && prefs.hoverGrow
        return CGSize(
            width: notchSize.width + 2 * compactSide + (grow ? 14 : 0),
            height: notchSize.height + (grow ? 3 : 0)
        )
    }

    /// Height of the tab content area; the Mirror tab can be taller.
    var contentHeight: CGFloat {
        tab == .mirror ? CGFloat(max(prefs.mirrorSize, prefs.contentHeight)) : CGFloat(prefs.contentHeight)
    }

    var topRadius: CGFloat { isOpen ? 14 : 6 }
    var bottomRadius: CGFloat { isOpen ? CGFloat(prefs.cornerRadius) : 10 }

    /// Hide the closed pill on screens without a notch when there's nothing to show.
    var isVisible: Bool { hasNotch || isOpen || compactSide > 0 }

    /// Fewer moving parts in Low Power Mode, if the user wants that.
    var reduceEffects: Bool { prefs.lowPowerReduce && power.isLowPowerMode }

    var animateVisualizer: Bool {
        guard media.isPlaying, !reduceEffects else { return false }
        switch prefs.visualizerAnimation {
        case .always: return true
        case .pluggedIn: return battery.isPluggedIn
        case .never: return false
        }
    }

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
