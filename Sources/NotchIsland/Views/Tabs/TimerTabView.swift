import SwiftUI

/// The Timer tab: quick countdowns and Focus (Pomodoro) sessions.
struct TimerTabView: View {
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
