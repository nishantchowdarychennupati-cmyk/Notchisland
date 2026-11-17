import SwiftUI

/// Height of the content area below the header in the expanded island.
let islandContentHeight: CGFloat = 126

struct ExpandedView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences
    @State private var direction: Edge = .trailing

    var body: some View {
        VStack(spacing: 6) {
            header
            ZStack {
                content(for: model.tab)
                    .id(model.tab)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: direction)).combined(with: .scale(scale: 0.97)),
                        removal: .opacity
                    ))
            }
            .frame(height: islandContentHeight)
            .padding(.horizontal, 18)
            .clipped()
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .onChange(of: model.tab) { old, new in
            let all = IslandTab.allCases
            direction = (all.firstIndex(of: new) ?? 0) > (all.firstIndex(of: old) ?? 0) ? .trailing : .leading
        }
    }

    @ViewBuilder private func content(for tab: IslandTab) -> some View {
        switch tab {
        case .home: NowPlayingView(model: model, prefs: prefs)
        case .timer: TimerTabView(timer: model.timer, prefs: prefs)
        case .agenda: AgendaView(calendar: model.calendar, prefs: prefs)
        case .shelf: ShelfView(shelf: model.shelf, accent: model.accent, isTargeted: model.isDropTargeted)
        case .clipboard: ClipboardView(store: model.clipboard, prefs: prefs, accent: model.accent)
        case .system: SystemView(model: model)
        case .mirror: MirrorView(camera: model.camera, prefs: prefs)
        case .actions: ActionsView(shortcuts: model.shortcuts, dictation: model.dictation, prefs: prefs, accent: model.accent)
        }
    }

    /// Header row sits beside the physical notch.
    private var header: some View {
        HStack(spacing: 8) {
            TabSwitcher(tabs: prefs.enabledTabs, selection: $model.tab,
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
    let tabs: [IslandTab]
    @Binding var selection: IslandTab
    let shelfCount: Int
    let accent: Color
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 1) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(islandSpring) { selection = tab }
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(selection == tab ? Color.white : Color.white.opacity(0.5))
                        .frame(width: 22, height: 20)
                        .background {
                            if selection == tab {
                                Capsule().fill(.white.opacity(0.18)).matchedGeometryEffect(id: "tab", in: ns)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if tab == .shelf && shelfCount > 0 {
                                Circle().fill(accent).frame(width: 5, height: 5).offset(x: -2, y: 2)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
        }
        .padding(2)
        .background(Capsule().fill(.white.opacity(0.08)))
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
