import SwiftUI

struct ExpandedView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(spacing: 6) {
            header
            ZStack {
                content(for: model.tab)
                    .id(model.tab)
                    .transition(prefs.tabTransition.transition(forward: model.tabForward))
            }
            .frame(height: model.contentHeight)
            .padding(.horizontal, 18)
            .clipped()
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private func content(for tab: IslandTab) -> some View {
        switch tab {
        case .home: NowPlayingView(model: model, prefs: prefs)
        case .timer: TimerTabView(timer: model.timer, prefs: prefs)
        case .agenda: AgendaView(calendar: model.calendar, prefs: prefs)
        case .shelf: ShelfView(shelf: model.shelf, accent: model.accent, isTargeted: model.isDropTargeted)
        case .clipboard: ClipboardView(store: model.clipboard, prefs: prefs, accent: model.accent)
        case .system: SystemView(model: model)
        case .mirror: MirrorView(camera: model.camera, prefs: prefs, height: model.contentHeight, accent: model.accent)
        case .actions: ActionsView(shortcuts: model.shortcuts, dictation: model.dictation, prefs: prefs, accent: model.accent)
        }
    }

    /// Header row sits beside the physical notch.
    private var header: some View {
        HStack(spacing: 8) {
            TabSwitcher(model: model, tabs: prefs.enabledTabs, style: prefs.tabIndicator,
                        shelfCount: model.shelf.items.count, accent: model.accent)
            Spacer(minLength: model.notchSize.width + 20)
            if prefs.batteryInHeader {
                BatteryBadge(battery: model.battery, showPercent: prefs.batteryPercent)
            }
            Button { model.openSettings() } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(IconButtonStyle(size: 24))
            .help("NotchIsland Settings")
        }
        .frame(height: model.notchSize.height)
        .padding(.horizontal, 16)
    }
}

struct TabSwitcher: View {
    @ObservedObject var model: IslandModel
    let tabs: [IslandTab]
    let style: TabIndicator
    let shelfCount: Int
    let accent: Color
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 1) {
            ForEach(tabs) { tab in
                let selected = model.tab == tab
                Button {
                    model.select(tab)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 10, weight: .semibold))
                        if style == .labels && selected {
                            Text(shortTitle(tab))
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize()
                                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                        }
                    }
                    .foregroundStyle(selected ? (style == .pill || style == .labels ? Color.white : accent) : Color.white.opacity(0.5))
                    .padding(.horizontal, style == .labels && selected ? 8 : 0)
                    .frame(minWidth: 22, minHeight: 20)
                    .background { indicator(selected: selected) }
                    .overlay(alignment: .topTrailing) {
                        if tab == .shelf && shelfCount > 0 {
                            Circle().fill(accent).frame(width: 5, height: 5).offset(x: -2, y: 2)
                        }
                    }
                    .contentShape(Capsule())
                    .scaleEffect(selected ? 1.05 : 1)
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
        }
        .padding(2)
        .background(Capsule().fill(.white.opacity(0.08)))
        .animation(islandSpring, value: model.tab)
    }

    @ViewBuilder private func indicator(selected: Bool) -> some View {
        if selected {
            switch style {
            case .pill, .labels:
                Capsule().fill(.white.opacity(0.18)).matchedGeometryEffect(id: "tab", in: ns)
            case .underline:
                VStack {
                    Spacer()
                    Capsule().fill(accent).frame(width: 12, height: 2.5)
                }
                .matchedGeometryEffect(id: "tab", in: ns)
            case .dot:
                VStack {
                    Spacer()
                    Circle().fill(accent).frame(width: 4, height: 4).offset(y: 2)
                }
                .matchedGeometryEffect(id: "tab", in: ns)
            }
        }
    }

    private func shortTitle(_ tab: IslandTab) -> String {
        switch tab {
        case .actions: return "Actions"
        case .shelf: return "Shelf"
        default: return tab.title
        }
    }
}

struct BatteryBadge: View {
    @ObservedObject var battery: BatteryMonitor
    var showPercent: Bool

    var body: some View {
        if battery.hasBattery {
            HStack(spacing: 5) {
                if showPercent {
                    Text("\(battery.level)%")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                }
                ZStack {
                    Image(systemName: battery.symbolName)
                        .font(.system(size: 15))
                        .foregroundStyle(battery.level <= 20 && !battery.isPluggedIn ? Color.red : Color.white)
                    if battery.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.green)
                            .offset(x: -1)
                    }
                }
            }
        }
    }
}
