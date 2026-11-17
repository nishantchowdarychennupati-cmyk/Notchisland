import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, appearance, activities, widgets, media, shelf, about
    var id: Self { self }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .activities: return "Live Activities"
        case .widgets: return "Widgets"
        case .media: return "Media"
        case .shelf: return "File Shelf"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .activities: return "sparkles"
        case .widgets: return "square.grid.2x2.fill"
        case .media: return "music.note"
        case .shelf: return "tray.full.fill"
        case .about: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return .gray
        case .appearance: return .blue
        case .activities: return .orange
        case .widgets: return .purple
        case .media: return .pink
        case .shelf: return .teal
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
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            detail(pane ?? .general)
                .formStyle(.grouped)
                .navigationTitle((pane ?? .general).title)
        }
        .frame(minWidth: 680, minHeight: 460)
    }

    @ViewBuilder private func detail(_ pane: SettingsPane) -> some View {
        switch pane {
        case .general: GeneralPane(prefs: prefs)
        case .appearance: AppearancePane(model: model, prefs: prefs)
        case .activities: ActivitiesPane(prefs: prefs)
        case .widgets: WidgetsPane(prefs: prefs, calendar: model.calendar)
        case .media: MediaPane(prefs: prefs)
        case .shelf: ShelfPane(prefs: prefs, shelf: model.shelf)
        case .about: AboutPane()
        }
    }
}

struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.gradient)
            )
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
                    ColorPicker("Custom color", selection: customColor, supportsOpacity: false)
                }
            }

            Section("Size") {
                SliderRow(title: "Expanded width", value: $prefs.expandedWidth, range: 520...860) { "\(Int($0)) pt" }
                SliderRow(title: "Corner radius", value: $prefs.cornerRadius, range: 14...42) { "\(Int($0)) pt" }
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
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(model.accent.gradient)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 5) {
                        Capsule().fill(.white.opacity(0.9)).frame(width: 70, height: 6)
                        Capsule().fill(.white.opacity(0.45)).frame(width: 46, height: 5)
                        Capsule().fill(model.accent).frame(width: 90, height: 3)
                    }
                    Spacer()
                    AudioVisualizer(style: prefs.visualizer, active: true, color: model.accent, height: 12)
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

// MARK: - Live Activities

struct ActivitiesPane: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                Toggle("Now playing", isOn: $prefs.mediaActivity)
                if prefs.mediaActivity {
                    Toggle("Keep showing when paused", isOn: $prefs.showPausedMedia)
                }
                Toggle("Timer countdown", isOn: $prefs.timerActivity)
                Toggle("File shelf badge", isOn: $prefs.shelfBadge)
            } header: {
                Text("Show beside the notch")
            } footer: {
                Text("These appear around the notch while the island is closed.")
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

// MARK: - Widgets

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

            Section("Calendar") {
                Toggle("Show next event", isOn: $prefs.calendarWidget)
                LabeledContent("Access") {
                    if calendar.hasAccess {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if calendar.isDenied {
                        Button("Open Privacy Settings") { SystemSettingsLink.open("Privacy_Calendars") }
                    } else {
                        Button("Allow Access") { calendar.requestAccess() }
                    }
                }
            }

            Section("Timer") {
                Toggle("Show timer", isOn: $prefs.timerWidget)
                Stepper("First preset: \(prefs.timerPreset1) min", value: $prefs.timerPreset1, in: 1...180)
                Stepper("Second preset: \(prefs.timerPreset2) min", value: $prefs.timerPreset2, in: 1...180)
                Stepper("Third preset: \(prefs.timerPreset3) min", value: $prefs.timerPreset3, in: 1...180)
                Picker("Sound", selection: $prefs.timerSound) {
                    ForEach(Preferences.timerSounds, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: prefs.timerSound) { _, sound in
                    NSSound(named: sound)?.play()
                }
            }
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
                Text("Automatic shows whichever of Music or Spotify is playing.")
            }

            Section("Now Playing") {
                Toggle("Progress bar with scrubbing", isOn: $prefs.showProgress)
                Toggle("Album art glow", isOn: $prefs.artworkGlow)
            }

            Section {
                LabeledContent("Permissions") {
                    Button("Open Automation Settings") { SystemSettingsLink.open("Privacy_Automation") }
                }
            } footer: {
                Text("NotchIsland asks Music and Spotify for the current track. If nothing shows up, make sure NotchIsland is allowed under Privacy & Security → Automation.")
            }
        }
    }
}

// MARK: - Shelf

struct ShelfPane: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var shelf: ShelfStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable file shelf", isOn: $prefs.shelfEnabled)
                if prefs.shelfEnabled {
                    Toggle("Open the shelf when dragging files to the notch", isOn: $prefs.shelfOpenOnDrag)
                }
            } footer: {
                Text("Drag files onto the notch to park them, then drag them out wherever you need them, or AirDrop them all at once. Files stay where they are on disk; the shelf only keeps a reference.")
            }

            if prefs.shelfEnabled {
                Section("On the shelf") {
                    LabeledContent("Items", value: "\(shelf.items.count)")
                    Button("Clear Shelf", role: .destructive) { shelf.clear() }
                        .disabled(shelf.items.isEmpty)
                }
            }
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
