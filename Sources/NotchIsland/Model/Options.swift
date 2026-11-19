import CoreImage
import SwiftUI

// MARK: - Mirror

enum MirrorShape: String, CaseIterable, Identifiable {
    case rounded, circle, capsule, squircle, hexagon, heart
    var id: Self { self }

    var title: String {
        switch self {
        case .rounded: return "Rounded"
        case .circle: return "Circle"
        case .capsule: return "Capsule"
        case .squircle: return "Squircle"
        case .hexagon: return "Hexagon"
        case .heart: return "Heart"
        }
    }

    var symbol: String {
        switch self {
        case .rounded: return "rectangle.fill"
        case .circle: return "circle.fill"
        case .capsule: return "capsule.fill"
        case .squircle: return "app.fill"
        case .hexagon: return "hexagon.fill"
        case .heart: return "heart.fill"
        }
    }

    /// Width relative to height.
    var aspect: CGFloat {
        switch self {
        case .rounded: return 4.0 / 3.0
        case .capsule: return 1.9
        default: return 1
        }
    }

    var shape: AnyShape {
        switch self {
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .circle: return AnyShape(Circle())
        case .capsule: return AnyShape(Capsule())
        case .squircle: return AnyShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        case .hexagon: return AnyShape(HexagonShape())
        case .heart: return AnyShape(HeartShape())
        }
    }
}

enum MirrorFilter: String, CaseIterable, Identifiable {
    case none, mono, noir, chrome, warm, cool, fade
    var id: Self { self }

    var title: String {
        switch self {
        case .none: return "Natural"
        case .mono: return "Mono"
        case .noir: return "Noir"
        case .chrome: return "Vivid"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .fade: return "Fade"
        }
    }

    /// Core Image filter applied to the camera layer.
    var ciName: String? {
        switch self {
        case .none: return nil
        case .mono: return "CIPhotoEffectMono"
        case .noir: return "CIPhotoEffectNoir"
        case .chrome: return "CIPhotoEffectChrome"
        case .warm: return "CIPhotoEffectInstant"
        case .cool: return "CIPhotoEffectProcess"
        case .fade: return "CIPhotoEffectFade"
        }
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let point = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.98))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.32),
                   control1: CGPoint(x: rect.minX + w * 0.32, y: rect.minY + h * 0.78),
                   control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.58))
        p.addArc(center: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.3), radius: w * 0.25,
                 startAngle: .degrees(175), endAngle: .degrees(-10), clockwise: false)
        p.addArc(center: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * 0.3), radius: w * 0.25,
                 startAngle: .degrees(190), endAngle: .degrees(5), clockwise: false)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.98),
                   control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.58),
                   control2: CGPoint(x: rect.minX + w * 0.68, y: rect.minY + h * 0.78))
        p.closeSubpath()
        return p
    }
}

// MARK: - Motion

enum TabTransition: String, CaseIterable, Identifiable {
    case slide, fade, zoom, flip, blur
    var id: Self { self }

    var title: String {
        switch self {
        case .slide: return "Slide"
        case .fade: return "Fade"
        case .zoom: return "Zoom"
        case .flip: return "Flip"
        case .blur: return "Blur"
        }
    }

    func transition(forward: Bool) -> AnyTransition {
        switch self {
        case .slide:
            return .asymmetric(
                insertion: .opacity.combined(with: .move(edge: forward ? .trailing : .leading)),
                removal: .opacity.combined(with: .move(edge: forward ? .leading : .trailing))
            )
        case .fade:
            return .opacity
        case .zoom:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.85)),
                removal: .opacity.combined(with: .scale(scale: 1.1))
            )
        case .flip:
            return .asymmetric(
                insertion: .modifier(active: FlipModifier(angle: forward ? 70 : -70), identity: FlipModifier(angle: 0))
                    .combined(with: .opacity),
                removal: .modifier(active: FlipModifier(angle: forward ? -70 : 70), identity: FlipModifier(angle: 0))
                    .combined(with: .opacity)
            )
        case .blur:
            return AnyTransition(.blurReplace)
        }
    }
}

struct FlipModifier: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    }
}

enum ContentEntrance: String, CaseIterable, Identifiable {
    case rise, zoom, fade, blur, drop
    var id: Self { self }

    var title: String {
        switch self {
        case .rise: return "Rise"
        case .zoom: return "Zoom"
        case .fade: return "Fade"
        case .blur: return "Blur"
        case .drop: return "Drop"
        }
    }

    var transition: AnyTransition {
        switch self {
        case .rise: return .opacity.combined(with: .scale(scale: 0.92, anchor: .top)).combined(with: .offset(y: -6))
        case .zoom: return .opacity.combined(with: .scale(scale: 0.7, anchor: .top))
        case .fade: return .opacity
        case .blur: return AnyTransition(.blurReplace)
        case .drop: return .opacity.combined(with: .offset(y: -30))
        }
    }
}

enum TabIndicator: String, CaseIterable, Identifiable {
    case pill, underline, dot, labels
    var id: Self { self }

    var title: String {
        switch self {
        case .pill: return "Pill"
        case .underline: return "Underline"
        case .dot: return "Dot"
        case .labels: return "Pill + Name"
        }
    }
}

enum LyricsStyle: String, CaseIterable, Identifiable {
    case threeLines, singleLine
    var id: Self { self }
    var title: String { self == .threeLines ? "Three Lines" : "Current Line Only" }
}

enum TimerMode: String, CaseIterable, Identifiable {
    case timer, stopwatch
    var id: Self { self }
    var title: String { self == .timer ? "Timer" : "Stopwatch" }
    var symbol: String { self == .timer ? "timer" : "stopwatch" }
}

enum SwipeStyle: String, CaseIterable, Identifiable {
    case single, continuous
    var id: Self { self }
    var title: String { self == .single ? "One Tab per Swipe" : "Continuous (Slider)" }
}
