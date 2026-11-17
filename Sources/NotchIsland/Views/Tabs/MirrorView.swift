import AVFoundation
import SwiftUI

/// Quick camera check. The camera only runs while this tab is open and stops as soon as the island closes.
struct MirrorView: View {
    @ObservedObject var camera: CameraController
    @ObservedObject var prefs: Preferences

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
                ZStack {
                    CameraPreview(session: camera.session)
                        .scaleEffect(x: prefs.mirrorFlip ? -1 : 1, y: 1)
                        .opacity(camera.isRunning ? 1 : 0)
                    if !camera.isRunning {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(width: 210, height: islandContentHeight - 4)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if camera.isRunning {
                        Circle().fill(Color.green).frame(width: 6, height: 6).padding(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.25), value: camera.isRunning)
            }
        }
    }
}
