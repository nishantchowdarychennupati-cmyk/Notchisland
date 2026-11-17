import EventKit
import SwiftUI

struct ExpandedView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(spacing: 6) {
            header
            Group {
                switch model.tab {
                case .home:
                    HomeView(model: model, prefs: prefs)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                case .shelf:
                    ShelfView(shelf: model.shelf, accent: model.accent, isTargeted: model.isDropTargeted)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(height: 108)
            .padding(.horizontal, 20)
            .animation(islandSpring, value: model.tab)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }

    /// Header row sits beside the physical notch.
    private var header: some View {
        HStack(spacing: 8) {
            if prefs.shelfEnabled {
                TabSwitcher(selection: $model.tab, shelfCount: model.shelf.items.count, accent: model.accent)
            } else {
                TimelineView(.everyMinute) { context in
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer(minLength: model.notchSize.width + 24)
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
        .padding(.horizontal, 18)
    }
}

struct TabSwitcher: View {
    @Binding var selection: IslandTab
    let shelfCount: Int
    let accent: Color
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            tab(.home, symbol: "house.fill")
            tab(.shelf, symbol: "tray.full.fill", badge: shelfCount)
        }
        .padding(2)
        .background(Capsule().fill(.white.opacity(0.08)))
    }

    private func tab(_ value: IslandTab, symbol: String, badge: Int = 0) -> some View {
        Button {
            withAnimation(islandSpring) { selection = value }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                if badge > 0 {
                    Text("\(badge)").font(.system(size: 10, weight: .bold)).monospacedDigit()
                }
            }
            .foregroundStyle(selection == value ? Color.white : Color.white.opacity(0.55))
            .padding(.horizontal, 9)
            .frame(height: 20)
            .background {
                if selection == value {
                    Capsule().fill(.white.opacity(0.18)).matchedGeometryEffect(id: "tab", in: ns)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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

// MARK: - Home

struct HomeView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences

    var body: some View {
        HStack(spacing: 12) {
            MediaPanel(media: model.media, prefs: prefs, accent: model.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            if prefs.timerWidget {
                TimerWidget(timer: model.timer, presets: prefs.timerPresets)
                    .frame(width: 118)
            }
            if prefs.calendarWidget {
                CalendarWidget(calendar: model.calendar)
                    .frame(width: 150)
            }
        }
    }
}

struct MediaPanel: View {
    @ObservedObject var media: MediaController
    @ObservedObject var prefs: Preferences
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if prefs.artworkGlow, let art = media.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .blur(radius: 18)
                        .opacity(media.isPlaying ? 0.55 : 0.25)
                }
                ArtworkView(image: media.artwork, cornerRadius: 14, accent: accent)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
            }
            .scaleEffect(media.isPlaying || media.current == nil ? 1 : 0.9)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: media.isPlaying)

            if let track = media.current {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if prefs.visualizer != .off {
                            AudioVisualizer(style: prefs.visualizer, active: track.isPlaying, color: accent, height: 12)
                        }
                    }
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    if prefs.showProgress && track.duration > 0 {
                        TimelineView(.periodic(from: .now, by: 0.5)) { context in
                            ScrubBar(
                                position: media.position(at: context.date),
                                duration: track.duration,
                                accent: accent,
                                onSeek: { media.seek(to: $0) }
                            )
                        }
                        .frame(height: 14)
                    }

                    HStack(spacing: 24) {
                        controlButton("backward.fill", action: media.previousTrack)
                        controlButton(track.isPlaying ? "pause.fill" : "play.fill", size: 20, action: media.playPause)
                        controlButton("forward.fill", action: media.nextTrack)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nothing Playing")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Start music to see it here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                    HStack(spacing: 6) {
                        if media.isInstalled(.music) {
                            Button("Music") { media.launch(.music) }
                        }
                        if media.isInstalled(.spotify) {
                            Button("Spotify") { media.launch(.spotify) }
                        }
                    }
                    .buttonStyle(PillButtonStyle())
                }
            }
        }
    }

    private func controlButton(_ symbol: String, size: CGFloat = 15, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 28, height: 24)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Progress bar that can be clicked or dragged to seek.
struct ScrubBar: View {
    let position: Double
    let duration: Double
    let accent: Color
    let onSeek: (Double) -> Void

    @State private var dragFraction: Double?
    @State private var hovering = false

    var body: some View {
        let fraction = dragFraction ?? (duration > 0 ? position / duration : 0)
        let clamped = min(max(fraction, 0), 1)
        let active = hovering || dragFraction != nil

        HStack(spacing: 8) {
            Text(formatTime(clamped * duration))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(accent).frame(width: max(0, geo.size.width * clamped))
                }
                .frame(height: active ? 6 : 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragFraction = min(max(value.location.x / max(geo.size.width, 1), 0), 1)
                        }
                        .onEnded { value in
                            let f = min(max(value.location.x / max(geo.size.width, 1), 0), 1)
                            onSeek(f * duration)
                            dragFraction = nil
                        }
                )
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.15), value: active)
            }
            Text("-" + formatTime(duration - clamped * duration))
        }
        .font(.system(size: 10, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.55))
    }
}

// MARK: - Widgets

struct TimerWidget: View {
    @ObservedObject var timer: QuickTimer
    let presets: [Int]

    var body: some View {
        VStack(spacing: 6) {
            if timer.isRunning {
                ZStack {
                    Circle().stroke(.white.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: timer.fractionRemaining)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: timer.fractionRemaining)
                    Text(timer.formatted)
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                        .contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 58, height: 58)

                HStack(spacing: 2) {
                    Button { timer.isPaused ? timer.resume() : timer.pause() } label: {
                        Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                    }
                    Button { timer.add(minutes: 1) } label: { Image(systemName: "plus") }
                    Button { timer.cancel() } label: { Image(systemName: "xmark") }
                }
                .buttonStyle(IconButtonStyle(size: 22))
            } else {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Timer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 4) {
                    ForEach(Array(presets.enumerated()), id: \.offset) { _, minutes in
                        Button("\(minutes)m") { timer.start(minutes: Double(minutes)) }
                    }
                }
                .buttonStyle(PillButtonStyle(tint: .orange))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .islandCard()
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: timer.isRunning)
    }
}

struct CalendarWidget: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TimelineView(.everyMinute) { context in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(context.date, format: .dateTime.weekday(.abbreviated))
                        .textCase(.uppercase)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                    Text(context.date, format: .dateTime.day())
                        .font(.system(size: 18, weight: .semibold))
                }
            }

            if calendar.hasAccess {
                if let event = calendar.upcoming.first {
                    EventRow(event: event)
                    if calendar.upcoming.count > 1 {
                        Text("+\(calendar.upcoming.count - 1) more")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                } else {
                    Text("No more events")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
            } else {
                Text(calendar.isDenied ? "Access denied" : "See your next event")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                Button(calendar.isDenied ? "Open Settings" : "Allow") {
                    if calendar.isDenied {
                        SystemSettingsLink.open("Privacy_Calendars")
                    } else {
                        calendar.requestAccess()
                    }
                }
                .buttonStyle(PillButtonStyle(tint: .red))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .islandCard()
    }
}

struct EventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(nsColor: event.calendar?.color ?? .systemBlue))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Event")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                TimelineView(.everyMinute) { context in
                    Text(timeText(now: context.date))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func timeText(now: Date) -> String {
        let start: Date = event.startDate
        let end: Date = event.endDate
        let time = start.formatted(date: .omitted, time: .shortened)
        if start <= now { return "Now · until \(end.formatted(date: .omitted, time: .shortened))" }
        let minutes = Int(start.timeIntervalSince(now) / 60)
        if minutes < 60 { return "In \(max(minutes, 1)) min · \(time)" }
        if Calendar.current.isDateInToday(start) { return time }
        if Calendar.current.isDateInTomorrow(start) { return "Tomorrow · \(time)" }
        return start.formatted(date: .abbreviated, time: .shortened)
    }
}
