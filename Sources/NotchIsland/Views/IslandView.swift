import SwiftUI
import UniformTypeIdentifiers

let islandSpring = Animation.spring(response: 0.42, dampingFraction: 0.8)

struct IslandView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences

    var body: some View {
        let size = model.currentSize
        let flare = model.topRadius
        let shape = NotchShape(topRadius: flare, bottomRadius: model.bottomRadius)

        ZStack(alignment: .top) {
            IslandBackground(
                shape: shape,
                style: prefs.islandStyle,
                isOpen: model.isOpen,
                notchHeight: model.notchSize.height,
                accent: model.accent,
                dropTargeted: model.isDropTargeted
            )
            .shadow(color: .black.opacity(model.isOpen && prefs.showShadow ? 0.55 : 0), radius: 20, y: 8)

            ZStack(alignment: .top) {
                if model.isOpen {
                    ExpandedView(model: model, prefs: prefs)
                        .transition(.asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.94, anchor: .top))
                                .animation(islandSpring.delay(0.06)),
                            removal: .opacity.animation(.easeOut(duration: 0.1))
                        ))
                } else {
                    CompactView(model: model, prefs: prefs)
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipped()
        }
        .frame(width: size.width + 2 * flare, height: size.height)
        .opacity(model.isVisible ? 1 : 0)
        .contentShape(shape)
        .onTapGesture {
            if !model.isOpen { model.open() }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $model.isDropTargeted) { providers in
            model.handleDrop(providers)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fontDesign(prefs.roundedFont ? .rounded : .default)
        .environment(\.colorScheme, .dark)
        .animation(islandSpring, value: size)
        .animation(islandSpring, value: model.isOpen)
        .animation(islandSpring, value: model.compact)
    }
}

/// Black notch fill, or Liquid Glass that fades to black under the physical notch.
struct IslandBackground: View {
    let shape: NotchShape
    let style: IslandStyle
    let isOpen: Bool
    let notchHeight: CGFloat
    let accent: Color
    let dropTargeted: Bool

    var body: some View {
        ZStack {
            if style == .glass && isOpen {
                Color.clear.liquidGlass(in: shape)
                VStack(spacing: 0) {
                    Color.black.frame(height: notchHeight)
                    LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 36)
                    Color.black.opacity(0.35)
                }
                .clipShape(shape)
                .transition(.opacity)
            } else {
                shape.fill(Color.black)
            }

            if dropTargeted {
                shape
                    .stroke(accent, lineWidth: 2)
                    .shadow(color: accent.opacity(0.6), radius: 8)
            }
        }
    }
}

// MARK: - Closed state

struct CompactView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences

    var body: some View {
        let side = model.compactSide
        let content = model.compact

        HStack(spacing: 0) {
            leading(content)
                .frame(width: side)
                .id(leadingKey(content))
                .transition(.blurReplace)
            Color.clear.frame(width: model.notchSize.width)
            trailing(content)
                .frame(width: side)
                .id(trailingKey(content))
                .transition(.blurReplace)
        }
        .frame(height: model.notchSize.height)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
    }

    @ViewBuilder private func leading(_ content: CompactContent) -> some View {
        switch content {
        case .none:
            EmptyView()
        case .peek(let peek):
            switch peek {
            case .charging:
                Image(systemName: "bolt.fill").foregroundStyle(.green)
            case .lowBattery:
                Image(systemName: "battery.25").foregroundStyle(.red)
            case .timerDone:
                Image(systemName: "bell.fill").foregroundStyle(.orange).symbolEffect(.bounce, value: model.peek)
            case .event:
                Image(systemName: "calendar").foregroundStyle(.red)
            case .shelfAdded:
                Image(systemName: "tray.and.arrow.down.fill").foregroundStyle(model.accent)
            }
        case .timer:
            Image(systemName: model.timer.isPaused ? "pause.circle.fill" : "timer").foregroundStyle(.orange)
        case .media:
            if prefs.compactArtwork {
                ArtworkView(image: model.media.artwork, cornerRadius: 6, accent: model.accent)
                    .frame(width: 22, height: 22)
                    .scaleEffect(model.media.isPlaying ? 1 : 0.85)
            } else {
                Image(systemName: "music.note").foregroundStyle(model.accent)
            }
        case .shelf:
            Image(systemName: "tray.full.fill").foregroundStyle(.white.opacity(0.8))
        }
    }

    @ViewBuilder private func trailing(_ content: CompactContent) -> some View {
        switch content {
        case .none:
            EmptyView()
        case .peek(let peek):
            switch peek {
            case .charging(let level):
                Text("\(level)%").foregroundStyle(.green).monospacedDigit()
            case .lowBattery(let level):
                Text("\(level)%").foregroundStyle(.red).monospacedDigit()
            case .timerDone:
                Text("Done").foregroundStyle(.orange)
            case .event(_, let minutes):
                Text("in \(minutes)m").foregroundStyle(.red)
            case .shelfAdded(let count):
                Text("+\(count)").foregroundStyle(model.accent)
            }
        case .timer:
            Text(model.timer.formatted)
                .foregroundStyle(.orange)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        case .media:
            AudioVisualizer(style: prefs.visualizer, active: model.media.isPlaying, color: model.accent)
        case .shelf:
            Text("\(model.shelf.items.count)").foregroundStyle(.white.opacity(0.8)).monospacedDigit()
        }
    }

    private func leadingKey(_ c: CompactContent) -> String { key(c) + "-l" }
    private func trailingKey(_ c: CompactContent) -> String { key(c) + "-r" }

    private func key(_ c: CompactContent) -> String {
        switch c {
        case .none: return "none"
        case .peek(let p):
            switch p {
            case .charging: return "charging"
            case .lowBattery: return "low"
            case .timerDone: return "done"
            case .event: return "event"
            case .shelfAdded: return "shelfAdded"
            }
        case .timer: return "timer"
        case .media: return "media"
        case .shelf: return "shelf"
        }
    }
}
