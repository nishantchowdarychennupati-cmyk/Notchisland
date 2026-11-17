import AVFoundation
import SwiftUI

/// Quick camera check. The camera only runs while this tab is open and stops as soon as the island closes.
struct MirrorView: View {
    @ObservedObject var camera: CameraController
    @ObservedObject var prefs: Preferences
    let height: CGFloat
    let accent: Color

    var body: some View {
        Group {
            if camera.status == .denied || camera.status == .restricted {
                PermissionPrompt(symbol: "camera.fill", title: "Camera access is off",
                                 message: "Allow NotchIsland to use the camera for the mirror.",
                                 buttonTitle: "Open Settings") {
                    SystemSettingsLink.open("Privacy_Camera")
                }
            } else if !camera.hasCamera {
                PermissionPrompt(symbol: "video.slash.fill", title: "No camera found",
                                 message: "Connect a camera or open your MacBook's lid.",
                                 buttonTitle: "OK") {}
            } else {
                HStack(spacing: 16) {
                    Spacer(minLength: 0)
                    MirrorCamera(camera: camera, prefs: prefs, height: height - 6, accent: accent)
                    MirrorControls(prefs: prefs, accent: accent)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

/// The camera itself, clipped to the chosen shape, with optional ring light and border.
struct MirrorCamera: View {
    @ObservedObject var camera: CameraController
    @ObservedObject var prefs: Preferences
    let height: CGFloat
    let accent: Color

    var body: some View {
        let shape = prefs.mirrorShape.shape
        let ringInset: CGFloat = prefs.mirrorRingLight ? 10 * CGFloat(prefs.mirrorRingIntensity) + 4 : 0
        let h = max(height - ringInset * 2, 40)
        let w = h * prefs.mirrorShape.aspect

        ZStack {
            if prefs.mirrorRingLight {
                // Soft "ring light": a bright, warm glow behind the camera that lights your face in dark rooms.
                shape
                    .fill(Color(red: 1, green: 0.97, blue: 0.9).opacity(0.35 + 0.6 * prefs.mirrorRingIntensity))
                    .frame(width: w + ringInset * 2, height: h + ringInset * 2)
                    .shadow(color: .white.opacity(0.8 * prefs.mirrorRingIntensity), radius: 18 * prefs.mirrorRingIntensity)
                    .transition(.scale.combined(with: .opacity))
            }

            ZStack {
                Color(white: 0.08)
                CameraPreview(session: camera.session, filter: prefs.mirrorFilter)
                    .scaleEffect(x: (prefs.mirrorFlip ? -1 : 1) * prefs.mirrorZoom, y: prefs.mirrorZoom)
                    .opacity(camera.isRunning ? 1 : 0)
                if !camera.isRunning {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: w, height: h)
            .clipShape(shape)
            .overlay {
                if prefs.mirrorBorder {
                    shape.stroke(accent.opacity(0.9), lineWidth: 2)
                }
            }
            .overlay(alignment: .top) {
                if camera.isRunning {
                    Circle().fill(Color.green).frame(width: 6, height: 6).padding(.top, 8)
                }
            }
        }
        .frame(width: w + ringInset * 2, height: h + ringInset * 2)
        .animation(islandSpring, value: prefs.mirrorShape)
        .animation(islandSpring, value: prefs.mirrorRingLight)
        .animation(islandSpring, value: prefs.mirrorSize)
        .animation(.easeOut(duration: 0.25), value: camera.isRunning)
    }
}

/// Quick controls beside the mirror: shape, filter, zoom and ring light.
struct MirrorControls: View {
    @ObservedObject var prefs: Preferences
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 2) {
                ForEach(MirrorShape.allCases) { shape in
                    Button { prefs.mirrorShape = shape } label: {
                        Image(systemName: shape.symbol)
                            .font(.system(size: 10))
                            .foregroundStyle(prefs.mirrorShape == shape ? accent : Color.white.opacity(0.55))
                            .frame(width: 22, height: 20)
                            .background(Capsule().fill(.white.opacity(prefs.mirrorShape == shape ? 0.15 : 0)))
                    }
                    .buttonStyle(.plain)
                    .help(shape.title)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(MirrorFilter.allCases) { filter in
                        Button(filter.title) { prefs.mirrorFilter = filter }
                            .buttonStyle(PillButtonStyle(tint: accent, prominent: prefs.mirrorFilter == filter))
                    }
                }
            }
            .frame(width: 150)

            HStack(spacing: 6) {
                Image(systemName: "plus.magnifyingglass").font(.system(size: 10))
                Slider(value: $prefs.mirrorZoom, in: 1...2)
                    .controlSize(.mini)
                    .frame(width: 80)
                Button { prefs.mirrorRingLight.toggle() } label: {
                    Image(systemName: prefs.mirrorRingLight ? "lightbulb.fill" : "lightbulb")
                        .foregroundStyle(prefs.mirrorRingLight ? Color.yellow : Color.white)
                }
                .buttonStyle(IconButtonStyle(size: 22))
                .help("Ring light")
            }
            .foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: 156)
    }
}
