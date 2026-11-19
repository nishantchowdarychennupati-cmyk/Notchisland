import SwiftUI
import UniformTypeIdentifiers

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

            if model.isOpen || model.compactSide > 0 {
                GlowBorder(shape: shape, style: prefs.glowStyle, accent: model.accent,
                           animate: model.isOpen && !model.reduceEffects, intensity: prefs.glowIntensity)
                    .allowsHitTesting(false)
            }

            if prefs.idleBreathing && !model.isOpen && model.compact == .media && model.animateVisualizer {
                BreathingGlow(shape: shape, color: model.accent, intensity: prefs.glowIntensity)
                    .allowsHitTesting(false)
            }

            ZStack(alignment: .top) {
                if model.isOpen {
                    ExpandedView(model: model, prefs: prefs)
                        .transition(.asymmetric(
                            insertion: prefs.contentEntrance.transition.animation(islandSpring.delay(0.05)),
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
        .animation(islandSpring, value: model.compact.key)
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
        let grow: CGFloat = model.isHovering && prefs.hoverGrow ? 7 : 0

        HStack(spacing: 0) {
            leading(content)
                .frame(width: side + grow)
                .id(content.key + "-l")
                .transition(.blurReplace.combined(with: .scale(0.6)))
            Color.clear.frame(width: model.notchSize.width)
            trailing(content)
                .frame(width: side + grow)
                .id(content.key + "-r")
                .transition(.blurReplace.combined(with: .scale(0.6)))
        }
        .frame(height: model.notchSize.height)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
    }

    private var bounce: Bool { prefs.alertBounce && !model.reduceEffects }

    @ViewBuilder private func leading(_ content: CompactContent) -> some View {
        switch content {
        case .none:
            EmptyView()
        case .peek(let peek):
            peekLeading(peek)
        case .recording:
            Image(systemName: "mic.fill")
                .foregroundStyle(.red)
                .symbolEffect(.pulse, isActive: !model.reduceEffects)
        case .timer:
            Image(systemName: model.timer.isPaused ? "pause.circle.fill" : (model.timer.kind.isPomodoro ? "brain.head.profile" : "timer"))
                .foregroundStyle(model.timer.kind.isBreak ? Color.green : Color.orange)
        case .stopwatch:
            Image(systemName: "stopwatch").foregroundStyle(.orange)
        case .media:
            if prefs.compactArtwork {
                ArtworkView(image: model.media.artwork, cornerRadius: 6, accent: model.accent,
                            spinning: prefs.artworkSpin && model.animateVisualizer)
                    .frame(width: 22, height: 22)
                    .scaleEffect(model.media.isPlaying ? 1 : 0.85)
            } else {
                Image(systemName: "music.note").foregroundStyle(model.accent)
            }
        case .shelf:
            Image(systemName: "tray.full.fill").foregroundStyle(.white.opacity(0.8))
        }
    }

    @ViewBuilder private func peekLeading(_ peek: Peek) -> some View {
        switch peek {
        case .charging:
            Image(systemName: "bolt.fill").foregroundStyle(.green)
                .symbolEffect(.bounce, value: bounce ? model.peek : nil)
        case .lowBattery:
            Image(systemName: "battery.25").foregroundStyle(.red)
        case .timerDone:
            Image(systemName: "bell.fill").foregroundStyle(.orange)
                .symbolEffect(.bounce, value: bounce ? model.peek : nil)
        case .pomodoro:
            Image(systemName: "brain.head.profile").foregroundStyle(.orange)
        case .event:
            Image(systemName: "calendar").foregroundStyle(.red)
        case .shelfAdded:
            Image(systemName: "tray.and.arrow.down.fill").foregroundStyle(model.accent)
        case .volume(let v, let muted):
            Image(systemName: Self.volumeSymbol(v, muted: muted))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22)
        case .brightness(let v):
            Image(systemName: v < 0.5 ? "sun.min.fill" : "sun.max.fill")
                .contentTransition(.symbolEffect(.replace))
        case .device(_, let symbol):
            Image(systemName: symbol).foregroundStyle(.white)
                .symbolEffect(.bounce, value: bounce ? model.peek : nil)
        case .track:
            ArtworkView(image: model.media.artwork, cornerRadius: 6, accent: model.accent)
                .frame(width: 22, height: 22)
        case .shortcut(_, let ok):
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(ok ? Color.green : Color.red)
        case .copied:
            Image(systemName: "doc.on.clipboard.fill").foregroundStyle(model.accent)
        }
    }

    @ViewBuilder private func trailing(_ content: CompactContent) -> some View {
        switch content {
        case .none:
            EmptyView()
        case .peek(let peek):
            peekTrailing(peek)
        case .recording:
            AudioLevelDots(level: model.dictation.level)
        case .timer:
            Text(model.timer.formatted)
                .foregroundStyle(model.timer.kind.isBreak ? Color.green : Color.orange)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        case .stopwatch:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(formatStopwatch(model.stopwatch.elapsed(at: context.date), hundredths: false))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }
        case .media:
            AudioVisualizer(style: prefs.visualizer, playing: model.media.isPlaying,
                            animate: model.animateVisualizer, color: model.accent)
        case .shelf:
            Text("\(model.shelf.items.count)").foregroundStyle(.white.opacity(0.8)).monospacedDigit()
        }
    }

    @ViewBuilder private func peekTrailing(_ peek: Peek) -> some View {
        switch peek {
        case .charging(let level):
            Text("\(level)%").foregroundStyle(.green).monospacedDigit()
        case .lowBattery(let level):
            Text("\(level)%").foregroundStyle(.red).monospacedDigit()
        case .timerDone:
            Text("Done").foregroundStyle(.orange)
        case .pomodoro(let text):
            Text(text).foregroundStyle(.orange).lineLimit(1)
        case .event(_, let minutes):
            Text("in \(minutes)m").foregroundStyle(.red)
        case .shelfAdded(let count):
            Text("+\(count)").foregroundStyle(model.accent)
        case .volume(let v, let muted):
            LevelBar(value: muted ? 0 : Double(v), color: model.accent).padding(.horizontal, 12)
        case .brightness(let v):
            LevelBar(value: Double(v), color: .yellow).padding(.horizontal, 12)
        case .device(let name, _):
            Text(name).lineLimit(1).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 8)
        case .track(let title, _):
            Text(title).lineLimit(1).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 8)
        case .shortcut(let name, _):
            Text(name).lineLimit(1).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 8)
        case .copied:
            Text("Copied").foregroundStyle(model.accent)
        }
    }

    static func volumeSymbol(_ v: Float, muted: Bool) -> String {
        if muted || v == 0 { return "speaker.slash.fill" }
        if v < 0.34 { return "speaker.wave.1.fill" }
        if v < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

/// Live microphone level shown while dictating.
struct AudioLevelDots: View {
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(Color.red)
                    .frame(width: 2.5, height: 4 + 10 * CGFloat(level) * CGFloat([0.5, 0.8, 1, 0.8, 0.5][i]))
            }
        }
        .frame(height: 14)
        .animation(.easeOut(duration: 0.1), value: level)
    }
}
