import AppKit
import SwiftUI

/// The island outline: flat top that flares into the menu bar, rounded bottom corners.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let t = min(topRadius, rect.width / 4)
        let b = max(0, min(bottomRadius, rect.height - t, (rect.width - 2 * t) / 2))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t),
                       control: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t + b, y: rect.maxY),
                       control: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - t, y: rect.maxY - b),
                       control: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Liquid Glass (macOS 26+) with graceful fallback

extension View {
    /// Liquid Glass on macOS 26 and later; a frosted material on older systems.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background(VisualEffectBackground().clipShape(shape))
        }
        #else
        self.background(VisualEffectBackground().clipShape(shape))
        #endif
    }

    /// Subtle translucent card used for widgets inside the island.
    func islandCard(cornerRadius: CGFloat = 16) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

/// Always-active behind-window blur (SwiftUI materials dim in non-key panels).
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// Animated border glow around the island. The rainbow only animates while visible and not in Low Power Mode.
struct GlowBorder: View {
    let shape: NotchShape
    let style: GlowStyle
    let accent: Color
    let animate: Bool
    var intensity: Double = 1

    var body: some View {
        switch style {
        case .off:
            EmptyView()
        case .accent:
            shape
                .stroke(accent.opacity(min(1, 0.8 * intensity)), lineWidth: 1.5 * intensity)
                .shadow(color: accent.opacity(min(1, 0.7 * intensity)), radius: 8 * intensity)
        case .rainbow:
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animate)) { context in
                let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 360
                shape
                    .stroke(
                        AngularGradient(
                            colors: [.pink, .orange, .yellow, .green, .cyan, .blue, .purple, .pink],
                            center: .center,
                            angle: .degrees(angle)
                        ),
                        lineWidth: 1.8 * intensity
                    )
                    .shadow(color: .purple.opacity(min(1, 0.6 * intensity)), radius: 10 * intensity)
            }
        }
    }
}

/// Slow glow pulse around the closed island while music plays.
struct BreathingGlow: View {
    let shape: NotchShape
    let color: Color
    var intensity: Double = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { context in
            let phase = 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 1.6)
            shape
                .stroke(color.opacity(0.25 + 0.45 * phase), lineWidth: 1.2 * intensity)
                .shadow(color: color.opacity(0.6 * phase * min(intensity, 1.5)), radius: (4 + 8 * phase) * intensity)
        }
    }
}

// MARK: - Artwork

struct ArtworkView: View {
    let image: NSImage?
    let cornerRadius: CGFloat
    var accent: Color = .white
    var spinning = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [accent.opacity(0.45), Color(white: 0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .clipShape(spinning ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
        .modifier(SpinModifier(active: spinning))
        .animation(.easeInOut(duration: 0.3), value: image != nil)
    }
}

/// Slowly rotates a view like a record (only while playing).
struct SpinModifier: ViewModifier {
    let active: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12) / 12 * 360
                content.rotationEffect(.degrees(angle))
            }
        } else {
            content
        }
    }
}

// MARK: - Audio visualizer

struct AudioVisualizer: View {
    var style: VisualizerStyle
    var playing: Bool
    var animate: Bool
    var color: Color
    var height: CGFloat = 14

    var body: some View {
        switch style {
        case .off:
            Image(systemName: playing ? "waveform" : "pause.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        case .pulse:
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !animate)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let s = animate ? 0.7 + 0.3 * abs(sin(t * 3.2)) : 0.6
                ZStack {
                    Circle().fill(color.opacity(0.25)).frame(width: height * s * 1.3, height: height * s * 1.3)
                    Circle().fill(color).frame(width: height * 0.55, height: height * 0.55)
                }
                .frame(width: height * 1.3, height: height)
            }
        case .bars, .wave:
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !animate)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let count = style == .bars ? 4 : 6
                HStack(spacing: style == .bars ? 2 : 1.5) {
                    ForEach(0..<count, id: \.self) { i in
                        Capsule()
                            .fill(color)
                            .frame(width: style == .bars ? 2.5 : 2, height: height * level(i, t))
                    }
                }
                .frame(height: height)
            }
        }
    }

    private func level(_ i: Int, _ t: TimeInterval) -> CGFloat {
        let d = Double(i)
        guard animate else { return playing ? CGFloat(0.35 + 0.25 * sin(d * 1.7)) : 0.22 }
        switch style {
        case .bars:
            return CGFloat(0.28 + 0.72 * abs(sin(t * (3.1 + d * 1.7) + d * 1.3)) * (0.75 + 0.25 * sin(t * 1.3 + d)))
        default:
            return CGFloat(0.3 + 0.7 * (0.5 + 0.5 * sin(t * 6 - d * 0.9)))
        }
    }
}

// MARK: - HUD bar and meters

/// iOS-style level bar used by the volume and brightness HUDs.
struct LevelBar: View {
    let value: Double
    var color: Color = .white

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: max(4, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 5)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: value)
    }
}

/// Draggable slider in the island's style.
struct IslandSlider: View {
    let value: Double
    let symbol: String
    var color: Color = .white
    let onChange: (Double) -> Void

    @State private var dragValue: Double?

    var body: some View {
        let shown = dragValue ?? value
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule()
                    .fill(color)
                    .frame(width: max(28, geo.size.width * min(max(shown, 0), 1)))
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(shown > 0.12 ? Color.black.opacity(0.7) : Color.white)
                    .padding(.leading, 9)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let v = min(max(g.location.x / max(geo.size.width, 1), 0), 1)
                        dragValue = v
                        onChange(v)
                    }
                    .onEnded { _ in dragValue = nil }
            )
        }
        .frame(height: 26)
    }
}

/// Small line chart for CPU history.
struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: geo.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1)),
                    y: geo.size.height * (1 - CGFloat(min(max(value, 0), 1)))
                )
            }
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    for p in points { path.addLine(to: p) }
                    if let last = points.last { path.addLine(to: CGPoint(x: last.x, y: geo.size.height)) }
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for p in points.dropFirst() { path.addLine(to: p) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// Circular gauge.
struct RingGauge: View {
    let value: Double
    let color: Color
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: value)
        }
    }
}

// MARK: - Button styles

struct PillButtonStyle: ButtonStyle {
    var tint: Color = .white
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(prominent ? Color.black : tint)
            .background(
                Capsule().fill(prominent ? tint.opacity(configuration.isPressed ? 0.75 : 0.95)
                                         : Color.white.opacity(configuration.isPressed ? 0.24 : 0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, size: size)
    }

    private struct IconButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let size: CGFloat
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white.opacity(hovering ? 1 : 0.8))
                .frame(width: size, height: size)
                .background(Circle().fill(.white.opacity(configuration.isPressed ? 0.22 : (hovering ? 0.12 : 0))))
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed ? 0.88 : 1)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Row-style button with hover highlight (lists in the island).
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration)
    }

    private struct RowBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(configuration.isPressed ? 0.16 : (hovering ? 0.09 : 0)))
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

/// Placeholder shown when a tab needs a permission.
struct PermissionPrompt: View {
    let symbol: String
    let title: String
    let message: String
    let buttonTitle: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                Button(buttonTitle, action: action)
                    .buttonStyle(PillButtonStyle(tint: tint))
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .islandCard()
    }
}
