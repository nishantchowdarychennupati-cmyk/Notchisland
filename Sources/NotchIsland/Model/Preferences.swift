import SwiftUI

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
    case bars, wave, off
    var id: Self { self }
    var title: String {
        switch self {
        case .bars: return "Bars"
        case .wave: return "Wave"
        case .off: return "Off"
        }
    }
}

enum PreferredPlayer: String, CaseIterable, Identifiable {
    case auto, music, spotify
    var id: Self { self }
    var title: String {
        switch self {
        case .auto: return "Automatic"
        case .music: return "Apple Music"
        case .spotify: return "Spotify"
        }
    }
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
    @Published var hoverDelay: Double = 0.15 { didSet { save(hoverDelay, "hoverDelay") } }
    @Published var closeDelay: Double = 0.35 { didSet { save(closeDelay, "closeDelay") } }
    @Published var haptics: Bool = true { didSet { save(haptics, "haptics") } }
    @Published var showMenuBarIcon: Bool = true { didSet { save(showMenuBarIcon, "showMenuBarIcon") } }
    @Published var showInFullScreen: Bool = true { didSet { save(showInFullScreen, "showInFullScreen") } }
    @Published var displayChoice: DisplayChoice = .builtIn { didSet { save(displayChoice.rawValue, "displayChoice") } }

    // Appearance
    @Published var islandStyle: IslandStyle = .black { didSet { save(islandStyle.rawValue, "islandStyle") } }
    @Published var accentMode: AccentMode = .artwork { didSet { save(accentMode.rawValue, "accentMode") } }
    @Published var customAccentHex: String = "#FF9F0A" { didSet { save(customAccentHex, "customAccentHex") } }
    @Published var expandedWidth: Double = 640 { didSet { save(expandedWidth, "expandedWidth") } }
    @Published var cornerRadius: Double = 30 { didSet { save(cornerRadius, "cornerRadius") } }
    @Published var showShadow: Bool = true { didSet { save(showShadow, "showShadow") } }
    @Published var roundedFont: Bool = true { didSet { save(roundedFont, "roundedFont") } }
    @Published var visualizer: VisualizerStyle = .bars { didSet { save(visualizer.rawValue, "visualizer") } }
    @Published var compactArtwork: Bool = true { didSet { save(compactArtwork, "compactArtwork") } }

    // Live activities
    @Published var mediaActivity: Bool = true { didSet { save(mediaActivity, "mediaActivity") } }
    @Published var showPausedMedia: Bool = false { didSet { save(showPausedMedia, "showPausedMedia") } }
    @Published var chargingAlert: Bool = true { didSet { save(chargingAlert, "chargingAlert") } }
    @Published var lowBatteryAlert: Bool = true { didSet { save(lowBatteryAlert, "lowBatteryAlert") } }
    @Published var lowBatteryThreshold: Int = 20 { didSet { save(lowBatteryThreshold, "lowBatteryThreshold") } }
    @Published var timerActivity: Bool = true { didSet { save(timerActivity, "timerActivity") } }
    @Published var calendarAlerts: Bool = true { didSet { save(calendarAlerts, "calendarAlerts") } }
    @Published var calendarAlertMinutes: Int = 5 { didSet { save(calendarAlertMinutes, "calendarAlertMinutes") } }
    @Published var shelfBadge: Bool = true { didSet { save(shelfBadge, "shelfBadge") } }

    // Widgets
    @Published var calendarWidget: Bool = true { didSet { save(calendarWidget, "calendarWidget") } }
    @Published var timerWidget: Bool = true { didSet { save(timerWidget, "timerWidget") } }
    @Published var batteryInHeader: Bool = true { didSet { save(batteryInHeader, "batteryInHeader") } }
    @Published var batteryPercent: Bool = true { didSet { save(batteryPercent, "batteryPercent") } }
    @Published var timerPreset1: Int = 5 { didSet { save(timerPreset1, "timerPreset1") } }
    @Published var timerPreset2: Int = 15 { didSet { save(timerPreset2, "timerPreset2") } }
    @Published var timerPreset3: Int = 25 { didSet { save(timerPreset3, "timerPreset3") } }
    @Published var timerSound: String = "Glass" { didSet { save(timerSound, "timerSound") } }

    // Media
    @Published var preferredPlayer: PreferredPlayer = .auto { didSet { save(preferredPlayer.rawValue, "preferredPlayer") } }
    @Published var showProgress: Bool = true { didSet { save(showProgress, "showProgress") } }
    @Published var artworkGlow: Bool = true { didSet { save(artworkGlow, "artworkGlow") } }

    // Shelf
    @Published var shelfEnabled: Bool = true { didSet { save(shelfEnabled, "shelfEnabled") } }
    @Published var shelfOpenOnDrag: Bool = true { didSet { save(shelfOpenOnDrag, "shelfOpenOnDrag") } }

    var timerPresets: [Int] { [timerPreset1, timerPreset2, timerPreset3] }

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
        hoverDelay = v("hoverDelay", 0.15)
        closeDelay = v("closeDelay", 0.35)
        haptics = v("haptics", true)
        showMenuBarIcon = v("showMenuBarIcon", true)
        showInFullScreen = v("showInFullScreen", true)
        displayChoice = e("displayChoice", DisplayChoice.builtIn)

        islandStyle = e("islandStyle", IslandStyle.black)
        accentMode = e("accentMode", AccentMode.artwork)
        customAccentHex = v("customAccentHex", "#FF9F0A")
        expandedWidth = v("expandedWidth", 640.0)
        cornerRadius = v("cornerRadius", 30.0)
        showShadow = v("showShadow", true)
        roundedFont = v("roundedFont", true)
        visualizer = e("visualizer", VisualizerStyle.bars)
        compactArtwork = v("compactArtwork", true)

        mediaActivity = v("mediaActivity", true)
        showPausedMedia = v("showPausedMedia", false)
        chargingAlert = v("chargingAlert", true)
        lowBatteryAlert = v("lowBatteryAlert", true)
        lowBatteryThreshold = v("lowBatteryThreshold", 20)
        timerActivity = v("timerActivity", true)
        calendarAlerts = v("calendarAlerts", true)
        calendarAlertMinutes = v("calendarAlertMinutes", 5)
        shelfBadge = v("shelfBadge", true)

        calendarWidget = v("calendarWidget", true)
        timerWidget = v("timerWidget", true)
        batteryInHeader = v("batteryInHeader", true)
        batteryPercent = v("batteryPercent", true)
        timerPreset1 = v("timerPreset1", 5)
        timerPreset2 = v("timerPreset2", 15)
        timerPreset3 = v("timerPreset3", 25)
        timerSound = v("timerSound", "Glass")

        preferredPlayer = e("preferredPlayer", PreferredPlayer.auto)
        showProgress = v("showProgress", true)
        artworkGlow = v("artworkGlow", true)

        shelfEnabled = v("shelfEnabled", true)
        shelfOpenOnDrag = v("shelfOpenOnDrag", true)
    }
}
