import AppKit
import SwiftUI

// MARK: - Option types

enum OpenMode: String, CaseIterable, Identifiable {
    case hover, click
    var id: Self { self }
    var title: String { self == .hover ? "On Hover" : "On Click" }
}

enum DisplayChoice: String, CaseIterable, Identifiable {
    case builtIn, main
    var id: Self { self }
    var title: String { self == .builtIn ? "Built-in Display" : "Main Display" }
}

enum IslandStyle: String, CaseIterable, Identifiable {
    case black, glass
    var id: Self { self }
    var title: String { self == .black ? "Notch Black" : "Liquid Glass" }
}

enum AccentMode: String, CaseIterable, Identifiable {
    case artwork, system, custom
    var id: Self { self }
    var title: String {
        switch self {
        case .artwork: return "From Album Art"
        case .system: return "System Accent"
        case .custom: return "Custom"
        }
    }
}

enum VisualizerStyle: String, CaseIterable, Identifiable {
    case bars, wave, pulse, off
    var id: Self { self }
    var title: String {
        switch self {
        case .bars: return "Bars"
        case .wave: return "Wave"
        case .pulse: return "Pulse"
        case .off: return "Static"
        }
    }
}

enum VisualizerAnimation: String, CaseIterable, Identifiable {
    case always, pluggedIn, never
    var id: Self { self }
    var title: String {
        switch self {
        case .always: return "Always"
        case .pluggedIn: return "Only When Charging"
        case .never: return "Never"
        }
    }
}

enum PreferredPlayer: String, CaseIterable, Identifiable {
    case auto, music, spotify, cider
    var id: Self { self }
    var title: String {
        switch self {
        case .auto: return "Automatic"
        case .music: return "Apple Music"
        case .spotify: return "Spotify"
        case .cider: return "Cider"
        }
    }
}

enum AnimationStyle: String, CaseIterable, Identifiable {
    case snappy, bouncy, smooth, gentle
    var id: Self { self }
    var title: String {
        switch self {
        case .snappy: return "Snappy"
        case .bouncy: return "Bouncy"
        case .smooth: return "Smooth"
        case .gentle: return "Gentle"
        }
    }

    var animation: Animation {
        switch self {
        case .snappy: return .spring(response: 0.3, dampingFraction: 0.86)
        case .bouncy: return .spring(response: 0.46, dampingFraction: 0.62)
        case .smooth: return .spring(response: 0.42, dampingFraction: 0.82)
        case .gentle: return .spring(response: 0.6, dampingFraction: 0.95)
        }
    }
}

enum GlowStyle: String, CaseIterable, Identifiable {
    case off, accent, rainbow
    var id: Self { self }
    var title: String {
        switch self {
        case .off: return "Off"
        case .accent: return "Accent"
        case .rainbow: return "Rainbow"
        }
    }
}

enum IslandTab: String, CaseIterable, Identifiable {
    // `home` keeps its stored name so existing settings carry over; it's shown as "Now Playing".
    case home, timer, agenda, shelf, clipboard, system, mirror, actions
    var id: Self { self }

    var title: String {
        switch self {
        case .home: return "Now Playing"
        case .timer: return "Timer"
        case .agenda: return "Agenda"
        case .shelf: return "File Shelf"
        case .clipboard: return "Clipboard"
        case .system: return "System"
        case .mirror: return "Mirror"
        case .actions: return "Shortcuts & Dictation"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "music.note"
        case .timer: return "timer"
        case .agenda: return "calendar"
        case .shelf: return "tray.full.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .system: return "cpu"
        case .mirror: return "camera.fill"
        case .actions: return "wand.and.stars"
        }
    }
}

// MARK: - Preferences store

/// Global animation used by the island, following the user's chosen style and Reduce Motion.
var islandSpring: Animation {
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return .easeInOut(duration: 0.18) }
    return Preferences.shared.animationStyle.animation
}

/// All user settings, persisted in UserDefaults.
final class Preferences: ObservableObject {
    static let shared = Preferences()
    static let timerSounds = ["Glass", "Hero", "Ping", "Purr", "Submarine", "Funk", "Blow", "Tink"]

    private var isLoading = false
    private func save(_ value: Any, _ key: String) {
        guard !isLoading else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    // General
    @Published var openMode: OpenMode = .hover { didSet { save(openMode.rawValue, "openMode") } }
    @Published var hoverDelay: Double = 0.12 { didSet { save(hoverDelay, "hoverDelay") } }
    @Published var closeDelay: Double = 0.35 { didSet { save(closeDelay, "closeDelay") } }
    @Published var haptics: Bool = true { didSet { save(haptics, "haptics") } }
    @Published var showMenuBarIcon: Bool = true { didSet { save(showMenuBarIcon, "showMenuBarIcon") } }
    @Published var showInFullScreen: Bool = true { didSet { save(showInFullScreen, "showInFullScreen") } }
    @Published var displayChoice: DisplayChoice = .builtIn { didSet { save(displayChoice.rawValue, "displayChoice") } }

    // Appearance
    @Published var islandStyle: IslandStyle = .black { didSet { save(islandStyle.rawValue, "islandStyle") } }
    @Published var accentMode: AccentMode = .artwork { didSet { save(accentMode.rawValue, "accentMode") } }
    @Published var customAccentHex: String = "#FF9F0A" { didSet { save(customAccentHex, "customAccentHex") } }
    @Published var expandedWidth: Double = 680 { didSet { save(expandedWidth, "expandedWidth") } }
    @Published var cornerRadius: Double = 32 { didSet { save(cornerRadius, "cornerRadius") } }
    @Published var showShadow: Bool = true { didSet { save(showShadow, "showShadow") } }
    @Published var roundedFont: Bool = true { didSet { save(roundedFont, "roundedFont") } }
    @Published var visualizer: VisualizerStyle = .bars { didSet { save(visualizer.rawValue, "visualizer") } }
    @Published var compactArtwork: Bool = true { didSet { save(compactArtwork, "compactArtwork") } }

    // Animation
    @Published var animationStyle: AnimationStyle = .bouncy { didSet { save(animationStyle.rawValue, "animationStyle") } }
    @Published var glowStyle: GlowStyle = .off { didSet { save(glowStyle.rawValue, "glowStyle") } }
    @Published var hoverGrow: Bool = true { didSet { save(hoverGrow, "hoverGrow") } }
    @Published var alertBounce: Bool = true { didSet { save(alertBounce, "alertBounce") } }
    @Published var artworkSpin: Bool = false { didSet { save(artworkSpin, "artworkSpin") } }

    // Tabs
    @Published var enabledTabsRaw: [String] = IslandTab.allCases.map(\.rawValue) { didSet { save(enabledTabsRaw, "enabledTabs") } }
    @Published var defaultTab: IslandTab = .home { didSet { save(defaultTab.rawValue, "defaultTab") } }
    @Published var shelfOpenOnDrag: Bool = true { didSet { save(shelfOpenOnDrag, "shelfOpenOnDrag") } }

    // Live activities
    @Published var mediaActivity: Bool = true { didSet { save(mediaActivity, "mediaActivity") } }
    @Published var showPausedMedia: Bool = false { didSet { save(showPausedMedia, "showPausedMedia") } }
    @Published var trackChangeAlert: Bool = true { didSet { save(trackChangeAlert, "trackChangeAlert") } }
    @Published var chargingAlert: Bool = true { didSet { save(chargingAlert, "chargingAlert") } }
    @Published var lowBatteryAlert: Bool = true { didSet { save(lowBatteryAlert, "lowBatteryAlert") } }
    @Published var lowBatteryThreshold: Int = 20 { didSet { save(lowBatteryThreshold, "lowBatteryThreshold") } }
    @Published var timerActivity: Bool = true { didSet { save(timerActivity, "timerActivity") } }
    @Published var calendarAlerts: Bool = true { didSet { save(calendarAlerts, "calendarAlerts") } }
    @Published var calendarAlertMinutes: Int = 5 { didSet { save(calendarAlertMinutes, "calendarAlertMinutes") } }
    @Published var shelfBadge: Bool = true { didSet { save(shelfBadge, "shelfBadge") } }

    // HUDs
    @Published var hudVolume: Bool = true { didSet { save(hudVolume, "hudVolume") } }
    @Published var hudBrightness: Bool = true { didSet { save(hudBrightness, "hudBrightness") } }
    @Published var hudDevices: Bool = true { didSet { save(hudDevices, "hudDevices") } }

    // Widgets
    @Published var batteryInHeader: Bool = true { didSet { save(batteryInHeader, "batteryInHeader") } }
    @Published var batteryPercent: Bool = true { didSet { save(batteryPercent, "batteryPercent") } }
    @Published var timerPreset1: Int = 5 { didSet { save(timerPreset1, "timerPreset1") } }
    @Published var timerPreset2: Int = 15 { didSet { save(timerPreset2, "timerPreset2") } }
    @Published var timerPreset3: Int = 25 { didSet { save(timerPreset3, "timerPreset3") } }
    @Published var timerSound: String = "Glass" { didSet { save(timerSound, "timerSound") } }
    @Published var pomodoroFocus: Int = 25 { didSet { save(pomodoroFocus, "pomodoroFocus") } }
    @Published var pomodoroShortBreak: Int = 5 { didSet { save(pomodoroShortBreak, "pomodoroShortBreak") } }
    @Published var pomodoroLongBreak: Int = 15 { didSet { save(pomodoroLongBreak, "pomodoroLongBreak") } }
    @Published var pomodoroRounds: Int = 4 { didSet { save(pomodoroRounds, "pomodoroRounds") } }
    @Published var showReminders: Bool = true { didSet { save(showReminders, "showReminders") } }

    // Media
    @Published var preferredPlayer: PreferredPlayer = .auto { didSet { save(preferredPlayer.rawValue, "preferredPlayer") } }
    @Published var showProgress: Bool = true { didSet { save(showProgress, "showProgress") } }
    @Published var artworkGlow: Bool = true { didSet { save(artworkGlow, "artworkGlow") } }
    @Published var ciderEnabled: Bool = true { didSet { save(ciderEnabled, "ciderEnabled") } }
    @Published var ciderToken: String = "" { didSet { save(ciderToken, "ciderToken") } }

    // Clipboard
    @Published var clipboardLimit: Int = 30 { didSet { save(clipboardLimit, "clipboardLimit") } }
    @Published var clipboardPersist: Bool = false { didSet { save(clipboardPersist, "clipboardPersist") } }
    @Published var clipboardIgnoreConcealed: Bool = true { didSet { save(clipboardIgnoreConcealed, "clipboardIgnoreConcealed") } }
    @Published var clipboardPasteDirectly: Bool = false { didSet { save(clipboardPasteDirectly, "clipboardPasteDirectly") } }
    @Published var snippets: [String] = ["Thanks so much!", "Let me get back to you on this."] { didSet { save(snippets, "snippets") } }

    // Mirror, shortcuts, dictation
    @Published var mirrorFlip: Bool = true { didSet { save(mirrorFlip, "mirrorFlip") } }
    @Published var pinnedShortcuts: [String] = [] { didSet { save(pinnedShortcuts, "pinnedShortcuts") } }
    @Published var dictationAutoCopy: Bool = true { didSet { save(dictationAutoCopy, "dictationAutoCopy") } }
    @Published var dictationOnDevice: Bool = true { didSet { save(dictationOnDevice, "dictationOnDevice") } }

    // Battery & performance
    @Published var visualizerAnimation: VisualizerAnimation = .always { didSet { save(visualizerAnimation.rawValue, "visualizerAnimation") } }
    @Published var lowPowerReduce: Bool = true { didSet { save(lowPowerReduce, "lowPowerReduce") } }
    @Published var statsInterval: Double = 2 { didSet { save(statsInterval, "statsInterval") } }

    // Mirror
    @Published var mirrorShape: MirrorShape = .rounded { didSet { save(mirrorShape.rawValue, "mirrorShape") } }
    @Published var mirrorSize: Double = 126 { didSet { save(mirrorSize, "mirrorSize") } }
    @Published var mirrorFilter: MirrorFilter = .none { didSet { save(mirrorFilter.rawValue, "mirrorFilter") } }
    @Published var mirrorZoom: Double = 1 { didSet { save(mirrorZoom, "mirrorZoom") } }
    @Published var mirrorRingLight: Bool = false { didSet { save(mirrorRingLight, "mirrorRingLight") } }
    @Published var mirrorRingIntensity: Double = 0.7 { didSet { save(mirrorRingIntensity, "mirrorRingIntensity") } }
    @Published var mirrorBorder: Bool = true { didSet { save(mirrorBorder, "mirrorBorder") } }

    // Motion & layout
    @Published var tabTransition: TabTransition = .slide { didSet { save(tabTransition.rawValue, "tabTransition") } }
    @Published var contentEntrance: ContentEntrance = .rise { didSet { save(contentEntrance.rawValue, "contentEntrance") } }
    @Published var tabIndicator: TabIndicator = .pill { didSet { save(tabIndicator.rawValue, "tabIndicator") } }
    @Published var idleBreathing: Bool = false { didSet { save(idleBreathing, "idleBreathing") } }
    @Published var glowIntensity: Double = 1 { didSet { save(glowIntensity, "glowIntensity") } }
    @Published var contentHeight: Double = 126 { didSet { save(contentHeight, "contentHeight") } }

    // Lyrics
    @Published var showLyrics: Bool = true { didSet { save(showLyrics, "showLyrics") } }
    @Published var lyricsStyle: LyricsStyle = .threeLines { didSet { save(lyricsStyle.rawValue, "lyricsStyle") } }
    @Published var lyricsGlow: Bool = true { didSet { save(lyricsGlow, "lyricsGlow") } }

    // Gestures
    @Published var swipeTabs: Bool = true { didSet { save(swipeTabs, "swipeTabs") } }
    @Published var swipeReversed: Bool = false { didSet { save(swipeReversed, "swipeReversed") } }
    @Published var swipeSensitivity: Double = 1 { didSet { save(swipeSensitivity, "swipeSensitivity") } }
    @Published var wrapTabs: Bool = false { didSet { save(wrapTabs, "wrapTabs") } }
    @Published var scrollToOpen: Bool = true { didSet { save(scrollToOpen, "scrollToOpen") } }
    @Published var tabHaptics: Bool = true { didSet { save(tabHaptics, "tabHaptics") } }
    @Published var swipeStyle: SwipeStyle = .continuous { didSet { save(swipeStyle.rawValue, "swipeStyle") } }
    @Published var swipeMomentum: Bool = true { didSet { save(swipeMomentum, "swipeMomentum") } }
    @Published var rememberTab: Bool = true { didSet { save(rememberTab, "rememberTab") } }

    // MARK: Derived

    var timerPresets: [Int] { [timerPreset1, timerPreset2, timerPreset3] }

    var enabledTabs: [IslandTab] {
        IslandTab.allCases.filter { $0 == .home || enabledTabsRaw.contains($0.rawValue) }
    }

    func isEnabled(_ tab: IslandTab) -> Bool { tab == .home || enabledTabsRaw.contains(tab.rawValue) }

    func setEnabled(_ tab: IslandTab, _ on: Bool) {
        var set = enabledTabsRaw.filter { $0 != tab.rawValue }
        if on { set.append(tab.rawValue) }
        enabledTabsRaw = set
        if !on && defaultTab == tab { defaultTab = .home }
    }

    func binding(for tab: IslandTab) -> Binding<Bool> {
        Binding(get: { self.isEnabled(tab) }, set: { self.setEnabled(tab, $0) })
    }

    private init() {
        load()
    }

    /// Restores every setting to its default value.
    func reset() {
        if let id = Bundle.main.bundleIdentifier {
            let keep = UserDefaults.standard.object(forKey: "hasLaunchedBefore")
            UserDefaults.standard.removePersistentDomain(forName: id)
            if let keep { UserDefaults.standard.set(keep, forKey: "hasLaunchedBefore") }
        }
        load()
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        let d = UserDefaults.standard
        func v<T>(_ key: String, _ fallback: T) -> T { d.object(forKey: key) as? T ?? fallback }
        func e<E: RawRepresentable>(_ key: String, _ fallback: E) -> E where E.RawValue == String {
            E(rawValue: d.string(forKey: key) ?? "") ?? fallback
        }

        openMode = e("openMode", OpenMode.hover)
        hoverDelay = v("hoverDelay", 0.12)
        closeDelay = v("closeDelay", 0.35)
        haptics = v("haptics", true)
        showMenuBarIcon = v("showMenuBarIcon", true)
        showInFullScreen = v("showInFullScreen", true)
        displayChoice = e("displayChoice", DisplayChoice.builtIn)

        islandStyle = e("islandStyle", IslandStyle.black)
        accentMode = e("accentMode", AccentMode.artwork)
        customAccentHex = v("customAccentHex", "#FF9F0A")
        expandedWidth = v("expandedWidth", 680.0)
        cornerRadius = v("cornerRadius", 32.0)
        showShadow = v("showShadow", true)
        roundedFont = v("roundedFont", true)
        visualizer = e("visualizer", VisualizerStyle.bars)
        compactArtwork = v("compactArtwork", true)

        animationStyle = e("animationStyle", AnimationStyle.bouncy)
        glowStyle = e("glowStyle", GlowStyle.off)
        hoverGrow = v("hoverGrow", true)
        alertBounce = v("alertBounce", true)
        artworkSpin = v("artworkSpin", false)

        enabledTabsRaw = v("enabledTabs", IslandTab.allCases.map(\.rawValue))
        // One-time migration: the Timer tab is new in 3.1, so switch it on for existing setups.
        if !d.bool(forKey: "migratedTimerTab") {
            if !enabledTabsRaw.contains(IslandTab.timer.rawValue) {
                enabledTabsRaw.insert(IslandTab.timer.rawValue, at: min(1, enabledTabsRaw.count))
                d.set(enabledTabsRaw, forKey: "enabledTabs")
            }
            d.set(true, forKey: "migratedTimerTab")
        }
        defaultTab = e("defaultTab", IslandTab.home)
        shelfOpenOnDrag = v("shelfOpenOnDrag", true)

        mediaActivity = v("mediaActivity", true)
        showPausedMedia = v("showPausedMedia", false)
        trackChangeAlert = v("trackChangeAlert", true)
        chargingAlert = v("chargingAlert", true)
        lowBatteryAlert = v("lowBatteryAlert", true)
        lowBatteryThreshold = v("lowBatteryThreshold", 20)
        timerActivity = v("timerActivity", true)
        calendarAlerts = v("calendarAlerts", true)
        calendarAlertMinutes = v("calendarAlertMinutes", 5)
        shelfBadge = v("shelfBadge", true)

        hudVolume = v("hudVolume", true)
        hudBrightness = v("hudBrightness", true)
        hudDevices = v("hudDevices", true)

        batteryInHeader = v("batteryInHeader", true)
        batteryPercent = v("batteryPercent", true)
        timerPreset1 = v("timerPreset1", 5)
        timerPreset2 = v("timerPreset2", 15)
        timerPreset3 = v("timerPreset3", 25)
        timerSound = v("timerSound", "Glass")
        pomodoroFocus = v("pomodoroFocus", 25)
        pomodoroShortBreak = v("pomodoroShortBreak", 5)
        pomodoroLongBreak = v("pomodoroLongBreak", 15)
        pomodoroRounds = v("pomodoroRounds", 4)
        showReminders = v("showReminders", true)

        preferredPlayer = e("preferredPlayer", PreferredPlayer.auto)
        showProgress = v("showProgress", true)
        artworkGlow = v("artworkGlow", true)
        ciderEnabled = v("ciderEnabled", true)
        ciderToken = v("ciderToken", "")

        clipboardLimit = v("clipboardLimit", 30)
        clipboardPersist = v("clipboardPersist", false)
        clipboardIgnoreConcealed = v("clipboardIgnoreConcealed", true)
        clipboardPasteDirectly = v("clipboardPasteDirectly", false)
        snippets = v("snippets", ["Thanks so much!", "Let me get back to you on this."])

        mirrorFlip = v("mirrorFlip", true)
        pinnedShortcuts = v("pinnedShortcuts", [String]())
        dictationAutoCopy = v("dictationAutoCopy", true)
        dictationOnDevice = v("dictationOnDevice", true)

        visualizerAnimation = e("visualizerAnimation", VisualizerAnimation.always)
        lowPowerReduce = v("lowPowerReduce", true)
        statsInterval = v("statsInterval", 2.0)
        mirrorShape = e("mirrorShape", MirrorShape.rounded)
        mirrorSize = v("mirrorSize", 126.0)
        mirrorFilter = e("mirrorFilter", MirrorFilter.none)
        mirrorZoom = v("mirrorZoom", 1.0)
        mirrorRingLight = v("mirrorRingLight", false)
        mirrorRingIntensity = v("mirrorRingIntensity", 0.7)
        mirrorBorder = v("mirrorBorder", true)

        tabTransition = e("tabTransition", TabTransition.slide)
        contentEntrance = e("contentEntrance", ContentEntrance.rise)
        tabIndicator = e("tabIndicator", TabIndicator.pill)
        idleBreathing = v("idleBreathing", false)
        glowIntensity = v("glowIntensity", 1.0)
        contentHeight = v("contentHeight", 126.0)

        showLyrics = v("showLyrics", true)
        lyricsStyle = e("lyricsStyle", LyricsStyle.threeLines)
        lyricsGlow = v("lyricsGlow", true)

        swipeTabs = v("swipeTabs", true)
        swipeReversed = v("swipeReversed", false)
        swipeSensitivity = v("swipeSensitivity", 1.0)
        wrapTabs = v("wrapTabs", false)
        scrollToOpen = v("scrollToOpen", true)
        tabHaptics = v("tabHaptics", true)
        swipeStyle = e("swipeStyle", SwipeStyle.continuous)
        swipeMomentum = v("swipeMomentum", true)
        rememberTab = v("rememberTab", true)
    }
}
