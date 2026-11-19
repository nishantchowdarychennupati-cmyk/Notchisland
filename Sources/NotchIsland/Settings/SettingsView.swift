import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, appearance, animation, gestures, tabs, activities, widgets, media, mirror, clipboard, actions, performance, about
    var id: Self { self }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .animation: return "Animation"
        case .gestures: return "Trackpad Gestures"
        case .tabs: return "Tabs"
        case .activities: return "Live Activities & HUDs"
        case .widgets: return "Timer & Calendar"
        case .media: return "Media"
        case .mirror: return "Mirror"
        case .clipboard: return "Clipboard"
        case .actions: return "Shortcuts & Dictation"
        case .performance: return "Battery & Performance"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .animation: return "sparkles"
        case .gestures: return "hand.draw.fill"
        case .tabs: return "square.grid.3x1.below.line.grid.1x2.fill"
        case .activities: return "slider.horizontal.below.rectangle"
        case .widgets: return "timer"
        case .media: return "music.note"
        case .mirror: return "camera.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .actions: return "wand.and.stars"
        case .performance: return "leaf.fill"
        case .about: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return .gray
        case .appearance: return .blue
        case .animation: return .indigo
        case .gestures: return .cyan
        case .tabs: return .purple
        case .activities: return .orange
        case .widgets: return .red
        case .media: return .pink
        case .mirror: return .brown
        case .clipboard: return .teal
        case .actions: return .mint
        case .performance: return .green
        case .about: return .gray
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences
    @State private var pane: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { item in
                Label {
                    Text(item.title)
                } icon: {
                    SettingsIcon(symbol: item.symbol, color: item.color)
                }
                .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            detail(pane ?? .general)
                .formStyle(.grouped)
                .navigationTitle((pane ?? .general).title)
        }
        .frame(minWidth: 720, minHeight: 500)
    }

    @ViewBuilder private func detail(_ pane: SettingsPane) -> some View {
        switch pane {
        case .general: GeneralPane(prefs: prefs)
        case .appearance: AppearancePane(model: model, prefs: prefs)
        case .animation: AnimationPane(model: model, prefs: prefs)
        case .gestures: GesturesPane(prefs: prefs)
        case .mirror: MirrorPane(prefs: prefs, accent: model.accent)
        case .tabs: TabsPane(prefs: prefs, shelf: model.shelf)
        case .activities: ActivitiesPane(prefs: prefs)
        case .widgets: WidgetsPane(prefs: prefs, calendar: model.calendar)
        case .media: MediaPane(prefs: prefs)
        case .clipboard: ClipboardPane(prefs: prefs, store: model.clipboard)
        case .actions: ActionsPane(prefs: prefs, shortcuts: model.shortcuts)
        case .performance: PerformancePane(prefs: prefs, power: model.power)
        case .about: AboutPane()
        }
    }
}

struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.gradient))
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Slider(value: $value, in: range)
                    .frame(minWidth: 160)
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }
}

// MARK: - General

struct GeneralPane: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject private var login = LaunchAtLogin.shared
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $login.isEnabled)
                Toggle("Show icon in menu bar", isOn: $prefs.showMenuBarIcon)
            } footer: {
                if !prefs.showMenuBarIcon {
                    Text("Open NotchIsland again from Applications, or click the gear in the island, to get back here.")
                }
            }

            Section("Interaction") {
                Picker("Open the island", selection: $prefs.openMode) {
                    ForEach(OpenMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if prefs.openMode == .hover {
                    SliderRow(title: "Hover delay", value: $prefs.hoverDelay, range: 0...0.8) { String(format: "%.2fs", $0) }
                }
                SliderRow(title: "Close delay", value: $prefs.closeDelay, range: 0.1...1.5) { String(format: "%.2fs", $0) }
                Toggle("Haptic feedback", isOn: $prefs.haptics)
            }

            Section("Display") {
                Picker("Show on", selection: $prefs.displayChoice) {
                    ForEach(DisplayChoice.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Show over full-screen apps", isOn: $prefs.showInFullScreen)
            }

            Section {
                Button("Reset All Settings…", role: .destructive) { confirmReset = true }
            }
        }
        .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { prefs.reset() }
        }
    }
}

// MARK: - Appearance

struct AppearancePane: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(hex: prefs.customAccentHex) ?? .orange },
            set: { prefs.customAccentHex = $0.hexString }
        )
    }

    private let swatches = ["#FF9F0A", "#FF375F", "#BF5AF2", "#0A84FF", "#64D2FF", "#30D158", "#FFD60A", "#FFFFFF"]

    var body: some View {
        Form {
            Section {
                IslandPreview(model: model, prefs: prefs)
                    .frame(height: 170)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Picker("Material", selection: $prefs.islandStyle) {
                    ForEach(IslandStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Drop shadow", isOn: $prefs.showShadow)
                Toggle("Rounded font", isOn: $prefs.roundedFont)
            } header: {
                Text("Style")
            } footer: {
                if prefs.islandStyle == .glass {
                    Text("Liquid Glass uses the system glass material on macOS 26 and later, and a frosted blur on older versions.")
                }
            }

            Section("Color") {
                Picker("Accent color", selection: $prefs.accentMode) {
                    ForEach(AccentMode.allCases) { Text($0.title).tag($0) }
                }
                if prefs.accentMode == .custom {
                    LabeledContent("Presets") {
                        HStack(spacing: 8) {
                            ForEach(swatches, id: \.self) { hex in
                                Button { prefs.customAccentHex = hex } label: {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .orange)
                                        .frame(width: 18, height: 18)
                                        .overlay(Circle().strokeBorder(.primary.opacity(prefs.customAccentHex == hex ? 0.8 : 0.15), lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    ColorPicker("Custom color", selection: customColor, supportsOpacity: false)
                }
            }

            Section("Size") {
                SliderRow(title: "Expanded width", value: $prefs.expandedWidth, range: 600...900) { "\(Int($0)) pt" }
                SliderRow(title: "Corner radius", value: $prefs.cornerRadius, range: 14...44) { "\(Int($0)) pt" }
                SliderRow(title: "Content height", value: $prefs.contentHeight, range: 110...170) { "\(Int($0)) pt" }
            }

            Section("Closed island") {
                Picker("Music visualizer", selection: $prefs.visualizer) {
                    ForEach(VisualizerStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Show album art", isOn: $prefs.compactArtwork)
            }
        }
    }
}

/// Live, scaled-down preview of the island on a fake desktop.
struct IslandPreview: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences

    var body: some View {
        let scale: CGFloat = 0.5
        let width = CGFloat(prefs.expandedWidth) * scale
        let shape = NotchShape(topRadius: 7, bottomRadius: CGFloat(prefs.cornerRadius) * scale)

        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.35, blue: 0.75), Color(red: 0.6, green: 0.3, blue: 0.7), Color(red: 0.95, green: 0.55, blue: 0.4)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Rectangle().fill(.black.opacity(0.25)).frame(height: 14)

            ZStack(alignment: .top) {
                IslandBackground(shape: shape, style: prefs.islandStyle, isOpen: true, notchHeight: 16,
                                 accent: model.accent, dropTargeted: false)
                GlowBorder(shape: shape, style: prefs.glowStyle, accent: model.accent, animate: true)
                HStack(spacing: 10) {
                    ArtworkView(image: model.media.artwork, cornerRadius: 8, accent: model.accent, spinning: prefs.artworkSpin)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 5) {
                        Capsule().fill(.white.opacity(0.9)).frame(width: 70, height: 6)
                        Capsule().fill(.white.opacity(0.45)).frame(width: 46, height: 5)
                        Capsule().fill(model.accent).frame(width: 90, height: 3)
                    }
                    Spacer()
                    AudioVisualizer(style: prefs.visualizer, playing: true, animate: true, color: model.accent, height: 12)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
            }
            .frame(width: width + 14, height: 80)
            .shadow(color: .black.opacity(prefs.showShadow ? 0.5 : 0), radius: 10, y: 4)
            .fontDesign(prefs.roundedFont ? .rounded : .default)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(10)
        .animation(islandSpring, value: prefs.expandedWidth)
        .animation(islandSpring, value: prefs.cornerRadius)
    }
}

// MARK: - Animation

struct AnimationPane: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences
    @State private var demoOpen = false

    var body: some View {
        Form {
            Section {
                Picker("Spring style", selection: $prefs.animationStyle) {
                    ForEach(AnimationStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Try it") {
                    Button(demoOpen ? "Close" : "Open") {
                        withAnimation(prefs.animationStyle.animation) { demoOpen.toggle() }
                    }
                }
                ZStack(alignment: .top) {
                    Color.black.opacity(0.05)
                    NotchShape(topRadius: 6, bottomRadius: demoOpen ? 20 : 8)
                        .fill(.black)
                        .frame(width: demoOpen ? 260 : 110, height: demoOpen ? 80 : 18)
                }
                .frame(height: 90)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("Motion")
            } footer: {
                Text("When Reduce Motion is on in System Settings, NotchIsland uses simple fades instead.")
            }

            Section("Transitions") {
                Picker("Opening content", selection: $prefs.contentEntrance) {
                    ForEach(ContentEntrance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Switching tabs", selection: $prefs.tabTransition) {
                    ForEach(TabTransition.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Tab indicator", selection: $prefs.tabIndicator) {
                    ForEach(TabIndicator.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Effects") {
                Picker("Border glow", selection: $prefs.glowStyle) {
                    ForEach(GlowStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                SliderRow(title: "Glow intensity", value: $prefs.glowIntensity, range: 0.4...2) { String(format: "%.1f×", $0) }
                Toggle("Breathing glow while music plays", isOn: $prefs.idleBreathing)
                Toggle("Grow slightly when hovering", isOn: $prefs.hoverGrow)
                Toggle("Bounce icons on alerts", isOn: $prefs.alertBounce)
                Toggle("Spin album art like a record", isOn: $prefs.artworkSpin)
            }
        }
    }
}

// MARK: - Gestures

struct GesturesPane: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                Toggle("Swipe left or right to switch tabs", isOn: $prefs.swipeTabs)
                if prefs.swipeTabs {
                    Picker("Style", selection: $prefs.swipeStyle) {
                        ForEach(SwipeStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if prefs.swipeStyle == .continuous {
                        Toggle("Keep gliding after a flick (momentum)", isOn: $prefs.swipeMomentum)
                    }
                    SliderRow(title: "Sensitivity", value: $prefs.swipeSensitivity, range: 0.5...2) { String(format: "%.1f×", $0) }
                    Toggle("Reverse swipe direction", isOn: $prefs.swipeReversed)
                    Toggle("Wrap around from last tab to first", isOn: $prefs.wrapTabs)
                }
                Toggle("Haptic tick when the tab changes", isOn: $prefs.tabHaptics)
            } header: {
                Text("Two-finger swipe")
            } footer: {
                Text("Swipe with two fingers on the trackpad while the cursor is over the open island. Continuous moves through tabs as your fingers travel, like a slider; you can also drag across the tab bar with the mouse. On the Clipboard and File Shelf tabs, swipe over the top row (where the tabs are) so the lists can still scroll.")
            }

            Section {
                Toggle("Scroll down on the notch to open", isOn: $prefs.scrollToOpen)
            } footer: {
                Text("Swipe down with two fingers over the notch to open the island; swipe up over the top row to close it.")
            }
        }
    }
}

// MARK: - Mirror

struct MirrorPane: View {
    @ObservedObject var prefs: Preferences
    let accent: Color

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    ForEach(MirrorShape.allCases) { shape in
                        Button { prefs.mirrorShape = shape } label: {
                            VStack(spacing: 6) {
                                shape.shape
                                    .fill(LinearGradient(colors: [accent.opacity(0.8), .purple.opacity(0.7)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 34 * shape.aspect, height: 34)
                                    .overlay(shape.shape.stroke(prefs.mirrorShape == shape ? Color.primary : .clear, lineWidth: 2))
                                Text(shape.title).font(.caption)
                                    .foregroundStyle(prefs.mirrorShape == shape ? HierarchicalShapeStyle.primary : HierarchicalShapeStyle.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } header: {
                Text("Shape")
            }

            Section("Size & framing") {
                SliderRow(title: "Size", value: $prefs.mirrorSize, range: 100...230) { "\(Int($0)) pt" }
                SliderRow(title: "Zoom", value: $prefs.mirrorZoom, range: 1...2) { String(format: "%.1f×", $0) }
                Toggle("Mirror the image", isOn: $prefs.mirrorFlip)
                Toggle("Accent border", isOn: $prefs.mirrorBorder)
            }

            Section("Look") {
                Picker("Filter", selection: $prefs.mirrorFilter) {
                    ForEach(MirrorFilter.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Ring light", isOn: $prefs.mirrorRingLight)
                if prefs.mirrorRingLight {
                    SliderRow(title: "Ring brightness", value: $prefs.mirrorRingIntensity, range: 0.2...1) { "\(Int($0 * 100))%" }
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("The camera only runs while the Mirror tab is open and turns off the moment the island closes. Larger sizes make the island taller while the Mirror tab is showing. Shape, filter, zoom and ring light can also be changed right in the Mirror tab.")
            }
        }
    }
}

// MARK: - Tabs

struct TabsPane: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var shelf: ShelfStore

    var body: some View {
        Form {
            Section {
                ForEach(IslandTab.allCases) { tab in
                    Toggle(isOn: prefs.binding(for: tab)) {
                        Label(tab.title, systemImage: tab.symbol)
                    }
                    .disabled(tab == .home)
                }
            } header: {
                Text("Tabs in the expanded island")
            } footer: {
                Text("Turning a tab off also switches off what it does in the background (for example, Clipboard stops recording).")
            }

            Section {
                Picker("When the island opens", selection: $prefs.rememberTab) {
                    Text("Return to the last tab").tag(true)
                    Text("Always show one tab").tag(false)
                }
                if !prefs.rememberTab {
                    Picker("Open to", selection: $prefs.defaultTab) {
                        ForEach(prefs.enabledTabs) { Text($0.title).tag($0) }
                    }
                }
            } footer: {
                Text(prefs.rememberTab ? "NotchIsland remembers the tab you were on, even after a restart." : "")
            }

            if prefs.isEnabled(.shelf) {
                Section("File Shelf") {
                    Toggle("Open the shelf when dragging files to the notch", isOn: $prefs.shelfOpenOnDrag)
                    LabeledContent("Items on shelf", value: "\(shelf.items.count)")
                    Button("Clear Shelf", role: .destructive) { shelf.clear() }
                        .disabled(shelf.items.isEmpty)
                }
            }
        }
    }
}

// MARK: - Live Activities & HUDs

struct ActivitiesPane: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                Toggle("Volume", isOn: $prefs.hudVolume)
                Toggle("Brightness", isOn: $prefs.hudBrightness)
                Toggle("Audio device connected (AirPods, speakers…)", isOn: $prefs.hudDevices)
            } header: {
                Text("HUDs")
            } footer: {
                Text("Shows a sleek slider in the notch when you change volume or brightness with the keys. Automatic brightness changes from the light sensor are ignored. macOS may still show its own indicator as well.")
            }

            Section {
                Toggle("Now playing", isOn: $prefs.mediaActivity)
                if prefs.mediaActivity {
                    Toggle("Keep showing when paused", isOn: $prefs.showPausedMedia)
                    Toggle("Show the new song when the track changes", isOn: $prefs.trackChangeAlert)
                }
                Toggle("Timer and Focus countdown", isOn: $prefs.timerActivity)
                Toggle("File shelf badge", isOn: $prefs.shelfBadge)
            } header: {
                Text("Beside the notch")
            }

            Section("Battery") {
                Toggle("Charging alert", isOn: $prefs.chargingAlert)
                Toggle("Low battery alert", isOn: $prefs.lowBatteryAlert)
                if prefs.lowBatteryAlert {
                    Stepper("Alert at \(prefs.lowBatteryThreshold)%", value: $prefs.lowBatteryThreshold, in: 5...50, step: 5)
                }
            }

            Section("Calendar") {
                Toggle("Upcoming event alert", isOn: $prefs.calendarAlerts)
                if prefs.calendarAlerts {
                    Stepper("Alert \(prefs.calendarAlertMinutes) min before", value: $prefs.calendarAlertMinutes, in: 1...30)
                }
            }
        }
    }
}

// MARK: - Widgets & Timer

struct WidgetsPane: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var calendar: CalendarService

    var body: some View {
        Form {
            Section("Header") {
                Toggle("Battery", isOn: $prefs.batteryInHeader)
                if prefs.batteryInHeader {
                    Toggle("Show percentage", isOn: $prefs.batteryPercent)
                }
            }

            Section("Calendar & Reminders") {
                LabeledContent("Calendar access") {
                    accessView(granted: calendar.hasAccess, denied: calendar.isDenied, anchor: "Privacy_Calendars") {
                        calendar.requestAccess()
                    }
                }
                Toggle("Show reminders in Agenda", isOn: $prefs.showReminders)
                if prefs.showReminders {
                    LabeledContent("Reminders access") {
                        accessView(granted: calendar.hasReminderAccess, denied: calendar.reminderDenied, anchor: "Privacy_Reminders") {
                            calendar.requestReminderAccess()
                        }
                    }
                }
            }

            Section("Timer presets") {
                Stepper("First: \(prefs.timerPreset1) min", value: $prefs.timerPreset1, in: 1...180)
                Stepper("Second: \(prefs.timerPreset2) min", value: $prefs.timerPreset2, in: 1...180)
                Stepper("Third: \(prefs.timerPreset3) min", value: $prefs.timerPreset3, in: 1...180)
                Picker("Sound", selection: $prefs.timerSound) {
                    ForEach(Preferences.timerSounds, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: prefs.timerSound) { _, sound in
                    NSSound(named: sound)?.play()
                }
            }

            Section {
                Stepper("Focus: \(prefs.pomodoroFocus) min", value: $prefs.pomodoroFocus, in: 5...120, step: 5)
                Stepper("Short break: \(prefs.pomodoroShortBreak) min", value: $prefs.pomodoroShortBreak, in: 1...30)
                Stepper("Long break: \(prefs.pomodoroLongBreak) min", value: $prefs.pomodoroLongBreak, in: 5...60, step: 5)
                Stepper("Rounds before long break: \(prefs.pomodoroRounds)", value: $prefs.pomodoroRounds, in: 2...8)
            } header: {
                Text("Focus (Pomodoro)")
            } footer: {
                Text("Press Start Focus in the Timer tab. NotchIsland alternates focus and breaks and chimes at each switch.")
            }
        }
    }

    @ViewBuilder
    private func accessView(granted: Bool, denied: Bool, anchor: String, request: @escaping () -> Void) -> some View {
        if granted {
            Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else if denied {
            Button("Open Privacy Settings") { SystemSettingsLink.open(anchor) }
        } else {
            Button("Allow Access", action: request)
        }
    }
}

// MARK: - Media

struct MediaPane: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                Picker("Player", selection: $prefs.preferredPlayer) {
                    ForEach(PreferredPlayer.allCases) { Text($0.title).tag($0) }
                }
            } footer: {
                Text("Automatic shows whichever of Music, Spotify or Cider is playing.")
            }

            Section("Now Playing") {
                Toggle("Progress bar with scrubbing", isOn: $prefs.showProgress)
                Toggle("Album art glow", isOn: $prefs.artworkGlow)
            }

            Section {
                Toggle("Show lyrics in Now Playing", isOn: $prefs.showLyrics)
                if prefs.showLyrics {
                    Picker("Layout", selection: $prefs.lyricsStyle) {
                        ForEach(LyricsStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Glow on the current line", isOn: $prefs.lyricsGlow)
                }
            } header: {
                Text("Lyrics")
            } footer: {
                Text("Synced lyrics come from LRCLIB (lrclib.net), a free community lyrics database. Only the song's title, artist, album and length are sent, once per song, while the Now Playing tab is open.")
            }

            Section {
                Toggle("Cider support", isOn: $prefs.ciderEnabled)
                if prefs.ciderEnabled {
                    TextField("API token (optional)", text: $prefs.ciderToken)
                        .textFieldStyle(.roundedBorder)
                }
            } header: {
                Text("Cider")
            } footer: {
                Text("In Cider, open Settings → Connectivity and turn on WebSockets/RPC. If you set an API token there, paste it here.")
            }

            Section {
                LabeledContent("Permissions") {
                    Button("Open Automation Settings") { SystemSettingsLink.open("Privacy_Automation") }
                }
            } footer: {
                Text("NotchIsland asks Music and Spotify for the current track. If nothing shows up, make sure NotchIsland is allowed under Privacy & Security → Automation. Apple doesn't let third-party apps read other apps' now-playing info (such as browsers) on recent macOS versions.")
            }
        }
    }
}

// MARK: - Clipboard

struct ClipboardPane: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var store: ClipboardStore
    @State private var newSnippet = ""
    @State private var canPaste = ClipboardStore.canPaste

    var body: some View {
        Form {
            Section {
                Toggle("Clipboard tab", isOn: prefs.binding(for: .clipboard))
                Stepper("Keep \(prefs.clipboardLimit) items", value: $prefs.clipboardLimit, in: 10...200, step: 10)
                Toggle("Ignore passwords and secrets", isOn: $prefs.clipboardIgnoreConcealed)
                Toggle("Remember history after quitting", isOn: $prefs.clipboardPersist)
                    .onChange(of: prefs.clipboardPersist) { _, on in
                        if on { store.save() } else { store.deleteSavedHistory() }
                    }
            } header: {
                Text("History")
            } footer: {
                Text("History stays on this Mac. Items copied from password managers are skipped.")
            }

            Section {
                Toggle("Paste directly into the app you're using", isOn: $prefs.clipboardPasteDirectly)
                if prefs.clipboardPasteDirectly && !canPaste {
                    LabeledContent("Needs Accessibility permission") {
                        Button("Grant…") {
                            ClipboardStore.requestPastePermission()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { canPaste = ClipboardStore.canPaste }
                        }
                    }
                }
            } footer: {
                Text("Otherwise clicking an item just copies it, ready for ⌘V.")
            }

            Section("Snippets") {
                ForEach(Array(prefs.snippets.enumerated()), id: \.offset) { index, snippet in
                    HStack {
                        Text(snippet).lineLimit(2)
                        Spacer()
                        Button(role: .destructive) {
                            prefs.snippets.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("New snippet", text: $newSnippet)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addSnippet)
                    Button("Add", action: addSnippet)
                        .disabled(newSnippet.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                Button("Clear History", role: .destructive) { store.clear() }
            }
        }
        .onAppear { canPaste = ClipboardStore.canPaste }
    }

    private func addSnippet() {
        let text = newSnippet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        prefs.snippets.append(text)
        newSnippet = ""
    }
}

// MARK: - Shortcuts & Dictation

struct ActionsPane: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var shortcuts: ShortcutsService

    var body: some View {
        Form {
            Section {
                if shortcuts.isLoading {
                    ProgressView()
                } else if shortcuts.all.isEmpty {
                    Text("No shortcuts found. Create some in the Shortcuts app.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(shortcuts.all, id: \.self) { name in
                        Toggle(name, isOn: Binding(
                            get: { prefs.pinnedShortcuts.contains(name) },
                            set: { on in
                                prefs.pinnedShortcuts.removeAll { $0 == name }
                                if on { prefs.pinnedShortcuts.append(name) }
                            }
                        ))
                    }
                }
                HStack {
                    Button("Refresh") { shortcuts.reload() }
                    Button("Open Shortcuts") { shortcuts.openApp() }
                }
            } header: {
                Text("Pinned shortcuts")
            } footer: {
                Text("Pinned shortcuts appear as buttons in the Shortcuts & Dictation tab. If none are pinned, the first few are shown.")
            }

            Section {
                Toggle("Copy the text when I stop", isOn: $prefs.dictationAutoCopy)
                Toggle("Process speech on this Mac when possible", isOn: $prefs.dictationOnDevice)
                LabeledContent("Permissions") {
                    HStack {
                        Button("Microphone") { SystemSettingsLink.open("Privacy_Microphone") }
                        Button("Speech") { SystemSettingsLink.open("Privacy_SpeechRecognition") }
                    }
                }
            } header: {
                Text("Dictation")
            }
        }
        .onAppear { shortcuts.loadIfNeeded() }
    }
}

// MARK: - Battery & Performance

struct PerformancePane: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var power: PowerManager

    var body: some View {
        Form {
            Section {
                Picker("Animate the music visualizer", selection: $prefs.visualizerAnimation) {
                    ForEach(VisualizerAnimation.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Reduce effects in Low Power Mode", isOn: $prefs.lowPowerReduce)
                LabeledContent("Low Power Mode", value: power.isLowPowerMode ? "On" : "Off")
            } header: {
                Text("Animations")
            } footer: {
                Text("The visualizer, rainbow glow and spinning art are the only things that redraw continuously, so these settings have the biggest effect on battery.")
            }

            Section("System stats") {
                SliderRow(title: "Update every", value: $prefs.statsInterval, range: 1...5) { String(format: "%.0fs", $0) }
            }

            Section("How NotchIsland saves power") {
                Label("Reacts to mouse movement instead of constantly checking the cursor", systemImage: "cursorarrow.motionlines")
                Label("Music and Spotify tell NotchIsland when songs change; nothing is polled", systemImage: "music.note")
                Label("Volume, output device and battery changes come straight from macOS", systemImage: "bolt.horizontal")
                Label("Camera, system stats and Shortcuts run only while their tab is open", systemImage: "eye")
                Label("Background checks pause while the screen is asleep or locked", systemImage: "moon.zzz")
                Label("Timers use tolerance so macOS can group wake-ups", systemImage: "timer")
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - About

struct AboutPane: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("NotchIsland")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Version \(version)")
                .foregroundStyle(.secondary)
            Text("Turns the MacBook notch into a live, interactive island.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 6) {
                tip("cursorarrow.motionlines", "Hover over the notch to expand it.")
                tip("doc.on.doc", "Drag files onto the notch to add them to the shelf.")
                tip("music.note", "Click or drag the progress bar to seek.")
                tip("gearshape", "Use the gear in the island to come back here.")
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}
