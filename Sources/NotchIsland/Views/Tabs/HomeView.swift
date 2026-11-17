import EventKit
import SwiftUI

struct HomeView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var prefs: Preferences

    var body: some View {
        HStack(spacing: 12) {
            MediaPanel(media: model.media, prefs: prefs, accent: model.accent, animate: model.animateVisualizer)
                .frame(maxWidth: .infinity, alignment: .leading)
            if prefs.timerWidget {
                TimerWidget(timer: model.timer, prefs: prefs)
                    .frame(width: 124)
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
    let animate: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if prefs.artworkGlow, let art = media.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 84, height: 84)
                        .blur(radius: 18)
                        .opacity(media.isPlaying ? 0.6 : 0.25)
                }
                ArtworkView(image: media.artwork, cornerRadius: 16, accent: accent,
                            spinning: prefs.artworkSpin && animate)
                    .frame(width: 84, height: 84)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
            }
            .scaleEffect(media.isPlaying || media.current == nil ? 1 : 0.9)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: media.isPlaying)

            if let track = media.current {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 4) {
                            AudioVisualizer(style: prefs.visualizer, playing: track.isPlaying, animate: animate,
                                            color: accent, height: 12)
                            Text(track.source.appName)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }

                    if prefs.showProgress && track.duration > 0 {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            ScrubBar(
                                position: media.position(at: context.date),
                                duration: track.duration,
                                accent: accent,
                                onSeek: { media.seek(to: $0) }
                            )
                        }
                        .frame(height: 14)
                    }

                    HStack(spacing: 26) {
                        controlButton("backward.fill", action: media.previousTrack)
                        controlButton(track.isPlaying ? "pause.fill" : "play.fill", size: 22, action: media.playPause)
                        controlButton("forward.fill", action: media.nextTrack)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nothing Playing")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Play something in Music, Spotify or Cider.")
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

    private func controlButton(_ symbol: String, size: CGFloat = 16, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 30, height: 26)
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

struct TimerWidget: View {
    @ObservedObject var timer: QuickTimer
    @ObservedObject var prefs: Preferences

    private var tint: Color { timer.kind.isBreak ? .green : .orange }

    var body: some View {
        VStack(spacing: 6) {
            if timer.isRunning {
                ZStack {
                    RingGauge(value: timer.fractionRemaining, color: tint)
                    VStack(spacing: 0) {
                        Text(timer.formatted)
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                            .contentTransition(.numericText(countsDown: true))
                        if timer.kind.isPomodoro {
                            Text(phaseText)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }
                .frame(width: 62, height: 62)

                HStack(spacing: 2) {
                    Button { timer.isPaused ? timer.resume() : timer.pause() } label: {
                        Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                    }
                    if timer.kind.isPomodoro {
                        Button { timer.skipPhase() } label: { Image(systemName: "forward.end.fill") }
                    } else {
                        Button { timer.add(minutes: 1) } label: { Image(systemName: "plus") }
                    }
                    Button { timer.cancel() } label: { Image(systemName: "xmark") }
                }
                .buttonStyle(IconButtonStyle(size: 22))
            } else {
                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
                HStack(spacing: 4) {
                    ForEach(Array(prefs.timerPresets.enumerated()), id: \.offset) { _, minutes in
                        Button("\(minutes)m") { timer.start(minutes: Double(minutes)) }
                    }
                }
                .buttonStyle(PillButtonStyle(tint: .orange))
                Button {
                    timer.startPomodoro(.init(
                        focus: Double(prefs.pomodoroFocus), shortBreak: Double(prefs.pomodoroShortBreak),
                        longBreak: Double(prefs.pomodoroLongBreak), rounds: prefs.pomodoroRounds
                    ))
                } label: {
                    Label("Focus", systemImage: "brain.head.profile")
                }
                .buttonStyle(PillButtonStyle(tint: .orange, prominent: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .islandCard()
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: timer.isRunning)
    }

    private var phaseText: String {
        switch timer.kind {
        case .focus(let round): return "FOCUS \(round)/\(timer.roundsTotal)"
        case .shortBreak: return "BREAK"
        case .longBreak: return "LONG BREAK"
        case .simple: return ""
        }
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
                    Text(Self.timeText(for: event, now: context.date))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    static func timeText(for event: EKEvent, now: Date) -> String {
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
