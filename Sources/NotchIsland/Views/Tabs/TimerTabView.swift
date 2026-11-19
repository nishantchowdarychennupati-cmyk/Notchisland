import SwiftUI

/// The Timer tab: a countdown/Focus timer and a stopwatch, switched with the buttons on the left.
struct TimerTabView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var stopwatch: Stopwatch

    init(model: IslandModel) {
        self.model = model
        stopwatch = model.stopwatch
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                ForEach(TimerMode.allCases) { mode in
                    Button { withAnimation(islandSpring) { model.timerMode = mode } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.symbol)
                            Text(mode.title)
                            Spacer(minLength: 0)
                            if mode == .stopwatch && stopwatch.isRunning && model.timerMode != .stopwatch {
                                Circle().fill(Color.orange).frame(width: 5, height: 5)
                            }
                            if mode == .timer && model.timer.isRunning && model.timerMode != .timer {
                                Circle().fill(Color.orange).frame(width: 5, height: 5)
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(model.timerMode == mode ? 0.15 : 0)))
                        .foregroundStyle(model.timerMode == mode ? Color.white : Color.white.opacity(0.55))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 100)

            ZStack {
                switch model.timerMode {
                case .timer:
                    CountdownView(timer: model.timer, prefs: model.prefs)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                case .stopwatch:
                    StopwatchView(stopwatch: stopwatch)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }
}

/// Quick countdowns and Focus (Pomodoro) sessions.
struct CountdownView: View {
    @ObservedObject var timer: QuickTimer
    @ObservedObject var prefs: Preferences

    private var tint: Color { timer.kind.isBreak ? .green : .orange }

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                RingGauge(value: timer.isRunning ? timer.fractionRemaining : 0, color: tint, lineWidth: 8)
                VStack(spacing: 2) {
                    Text(timer.isRunning ? timer.formatted : "0:00")
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(timer.isRunning ? tint : Color.white.opacity(0.4))
                        .contentTransition(.numericText(countsDown: true))
                    Text(statusText)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: 108, height: 108)

            if timer.isRunning {
                runningControls
            } else {
                startOptions
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(islandSpring, value: timer.isRunning)
    }

    private var statusText: String {
        if !timer.isRunning { return "READY" }
        if timer.isPaused { return "PAUSED" }
        switch timer.kind {
        case .simple: return "TIMER"
        case .focus(let round): return "FOCUS \(round)/\(timer.roundsTotal)"
        case .shortBreak: return "BREAK"
        case .longBreak: return "LONG BREAK"
        }
    }

    // MARK: Idle

    private var startOptions: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Quick Timer", systemImage: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                HStack(spacing: 6) {
                    ForEach(Array(prefs.timerPresets.enumerated()), id: \.offset) { _, minutes in
                        Button("\(minutes) min") { timer.start(minutes: Double(minutes)) }
                    }
                }
                .buttonStyle(PillButtonStyle(tint: .orange))
                Text("Change presets in Settings → Timer & Calendar.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .islandCard()

            VStack(alignment: .leading, spacing: 8) {
                Label("Focus Session", systemImage: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("\(prefs.pomodoroFocus) min focus · \(prefs.pomodoroShortBreak) min break · \(prefs.pomodoroRounds) rounds")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                Button {
                    timer.startPomodoro(.init(
                        focus: Double(prefs.pomodoroFocus), shortBreak: Double(prefs.pomodoroShortBreak),
                        longBreak: Double(prefs.pomodoroLongBreak), rounds: prefs.pomodoroRounds
                    ))
                } label: {
                    Label("Start Focus", systemImage: "play.fill")
                }
                .buttonStyle(PillButtonStyle(tint: .orange, prominent: true))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .islandCard()
        }
    }

    // MARK: Running

    private var runningControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(timer.kind.isPomodoro ? (timer.kind.isBreak ? "Take a breather" : "Stay focused") : "Timer running")
                .font(.system(size: 16, weight: .bold))
            if timer.kind.isPomodoro {
                HStack(spacing: 6) {
                    ForEach(1...max(timer.roundsTotal, 1), id: \.self) { round in
                        Capsule()
                            .fill(round <= currentRound ? tint : Color.white.opacity(0.15))
                            .frame(width: 22, height: 5)
                    }
                }
            }
            HStack(spacing: 8) {
                Button { timer.isPaused ? timer.resume() : timer.pause() } label: {
                    Label(timer.isPaused ? "Resume" : "Pause", systemImage: timer.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(PillButtonStyle(tint: tint, prominent: true))
                if timer.kind.isPomodoro {
                    Button { timer.skipPhase() } label: { Label("Skip", systemImage: "forward.end.fill") }
                } else {
                    Button { timer.add(minutes: 1) } label: { Label("+1 min", systemImage: "plus") }
                    Button { timer.add(minutes: 5) } label: { Label("+5 min", systemImage: "plus") }
                }
                Button { timer.cancel() } label: { Label("Stop", systemImage: "xmark") }
            }
            .buttonStyle(PillButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentRound: Int {
        switch timer.kind {
        case .focus(let round), .shortBreak(let round): return round
        case .longBreak: return timer.roundsTotal
        case .simple: return 0
        }
    }
}

/// Stopwatch with laps. Hundredths are drawn only while this view is on screen.
struct StopwatchView: View {
    @ObservedObject var stopwatch: Stopwatch

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                TimelineView(.periodic(from: .now, by: stopwatch.isRunning ? 0.05 : 3600)) { context in
                    Text(formatStopwatch(stopwatch.elapsed(at: context.date), hundredths: true))
                        .font(.system(size: 34, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(stopwatch.isRunning ? Color.orange : Color.white)
                }
                HStack(spacing: 8) {
                    Button { stopwatch.toggle() } label: {
                        Label(stopwatch.isRunning ? "Pause" : (stopwatch.hasTime ? "Resume" : "Start"),
                              systemImage: stopwatch.isRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(PillButtonStyle(tint: .orange, prominent: true))
                    if stopwatch.isRunning {
                        Button { withAnimation(islandSpring) { stopwatch.lap() } } label: {
                            Label("Lap", systemImage: "flag.fill")
                        }
                        .buttonStyle(PillButtonStyle())
                    } else if stopwatch.hasTime {
                        Button { withAnimation(islandSpring) { stopwatch.reset() } } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(PillButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Label("Laps", systemImage: "flag.checkered")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                if stopwatch.laps.isEmpty {
                    Text("Press Lap while it runs.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 3) {
                            ForEach(Array(stopwatch.laps.enumerated()), id: \.offset) { index, total in
                                let number = stopwatch.laps.count - index
                                let previous = index + 1 < stopwatch.laps.count ? stopwatch.laps[index + 1] : 0
                                HStack {
                                    Text("Lap \(number)").foregroundStyle(.white.opacity(0.6))
                                    Spacer()
                                    Text(formatStopwatch(total - previous, hundredths: true))
                                    Text(formatStopwatch(total, hundredths: false))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .frame(width: 40, alignment: .trailing)
                                }
                                .font(.system(size: 11, weight: .medium))
                                .monospacedDigit()
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(width: 210)
            .frame(maxHeight: .infinity)
            .islandCard()
        }
    }
}
