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

// MARK: - Artwork

struct ArtworkView: View {
    let image: NSImage?
    let cornerRadius: CGFloat
    var accent: Color = .white

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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(.easeInOut(duration: 0.3), value: image != nil)
    }
}

// MARK: - Audio visualizer

struct AudioVisualizer: View {
    var style: VisualizerStyle
    var active: Bool
    var color: Color
    var height: CGFloat = 14

    var body: some View {
        switch style {
        case .off:
            Image(systemName: active ? "waveform" : "pause.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        case .bars, .wave:
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !active)) { context in
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
        guard active else { return 0.22 }
        let d = Double(i)
        switch style {
        case .bars:
            return CGFloat(0.28 + 0.72 * abs(sin(t * (3.1 + d * 1.7) + d * 1.3)) * (0.75 + 0.25 * sin(t * 1.3 + d)))
        default:
            return CGFloat(0.3 + 0.7 * (0.5 + 0.5 * sin(t * 6 - d * 0.9)))
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
