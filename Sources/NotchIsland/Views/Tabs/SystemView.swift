import SwiftUI

/// Volume and brightness sliders, output device, and live system stats.
struct SystemView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var audio: SystemAudio
    @ObservedObject var brightness: BrightnessController
    @ObservedObject var stats: SystemStats
    @ObservedObject var battery: BatteryMonitor

    init(model: IslandModel) {
        self.model = model
        audio = model.audio
        brightness = model.brightness
        stats = model.stats
        battery = model.battery
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                IslandSlider(
                    value: audio.isMuted ? 0 : Double(audio.volume),
                    symbol: CompactView.volumeSymbol(audio.volume, muted: audio.isMuted),
                    color: .white
                ) { audio.setVolume(Float($0)) }
                if brightness.isAvailable {
                    IslandSlider(value: Double(brightness.brightness),
                                 symbol: brightness.brightness < 0.5 ? "sun.min.fill" : "sun.max.fill",
                                 color: .yellow) { brightness.set(Float($0)) }
                }
                HStack(spacing: 6) {
                    Image(systemName: audio.outputSymbol).font(.system(size: 11))
                    Text(audio.outputName)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button { audio.toggleMute() } label: {
                        Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    }
                    .buttonStyle(IconButtonStyle(size: 20))
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(10)
            .frame(width: 200)
            .frame(maxHeight: .infinity)
            .islandCard()

            HStack(spacing: 8) {
                StatTile(title: "CPU", value: stats.cpu, color: .cyan) {
                    Sparkline(values: stats.cpuHistory, color: .cyan).frame(height: 18)
                }
                StatTile(title: "GPU", value: stats.gpu ?? 0, color: .purple, unavailable: stats.gpu == nil) {
                    EmptyView()
                }
                StatTile(title: "Memory", value: stats.memoryFraction, color: .green) {
                    Text(formatBytes(stats.memoryUsed))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label(formatBytes(stats.downBytesPerSec, perSecond: true), systemImage: "arrow.down")
                    Label(formatBytes(stats.upBytesPerSec, perSecond: true), systemImage: "arrow.up")
                    if battery.hasBattery {
                        Label(batteryText, systemImage: battery.isCharging ? "bolt.fill" : "battery.75")
                    }
                    if stats.thermal != .nominal {
                        Label(thermalText, systemImage: "thermometer.medium").foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .islandCard()
        }
    }

    private var batteryText: String {
        if let minutes = battery.minutesRemaining {
            let time = "\(minutes / 60)h \(minutes % 60)m"
            return battery.isCharging ? "Full in \(time)" : "\(time) left"
        }
        return "\(battery.level)%"
    }

    private var thermalText: String {
        switch stats.thermal {
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Very hot"
        default: return "Normal"
        }
    }
}

struct StatTile<Extra: View>: View {
    let title: String
    let value: Double
    let color: Color
    var unavailable = false
    @ViewBuilder let extra: () -> Extra

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RingGauge(value: unavailable ? 0 : value, color: color, lineWidth: 4)
                Text(unavailable ? "–" : "\(Int((value * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            }
            .frame(width: 46, height: 46)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            extra()
        }
        .frame(width: 64)
    }
}
