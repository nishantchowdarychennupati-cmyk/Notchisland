import SwiftUI

/// Pinned Siri Shortcuts plus voice-to-text dictation.
struct ActionsView: View {
    @ObservedObject var shortcuts: ShortcutsService
    @ObservedObject var dictation: DictationService
    @ObservedObject var prefs: Preferences
    let accent: Color

    private var pinned: [String] {
        let pinned = prefs.pinnedShortcuts.filter { shortcuts.all.isEmpty || shortcuts.all.contains($0) }
        return pinned.isEmpty ? Array(shortcuts.all.prefix(6)) : pinned
    }

    var body: some View {
        HStack(spacing: 10) {
            shortcutsPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
                .islandCard()
            dictationPanel
                .frame(width: 230)
                .frame(maxHeight: .infinity)
                .padding(10)
                .islandCard()
        }
    }

    private var shortcutsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Shortcuts", systemImage: "square.2.layers.3d.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.pink)
                Spacer()
                Button { shortcuts.openApp() } label: { Image(systemName: "plus") }
                    .buttonStyle(IconButtonStyle(size: 18))
                    .help("Open the Shortcuts app")
            }
            if shortcuts.isLoading && shortcuts.all.isEmpty {
                ProgressView().controlSize(.small)
            } else if shortcuts.all.isEmpty {
                Text("No shortcuts yet. Make one in the Shortcuts app.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], spacing: 6) {
                    ForEach(pinned, id: \.self) { name in
                        Button { shortcuts.run(name) } label: {
                            HStack(spacing: 5) {
                                if shortcuts.running == name {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "play.fill").font(.system(size: 8))
                                }
                                Text(name).lineLimit(1)
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.pink.opacity(0.22)))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(shortcuts.running != nil)
                    }
                }
            }
        }
    }

    private var dictationPanel: some View {
        HStack(spacing: 10) {
            Button { dictation.toggle() } label: {
                ZStack {
                    Circle()
                        .fill(dictation.isRecording ? Color.red : accent)
                        .frame(width: 46, height: 46)
                    if dictation.isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 3)
                            .frame(width: 46 + CGFloat(dictation.level) * 22, height: 46 + CGFloat(dictation.level) * 22)
                            .animation(.easeOut(duration: 0.1), value: dictation.level)
                    }
                    Image(systemName: dictation.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 66, height: 66)
            }
            .buttonStyle(PressableStyle())
            .help(dictation.isRecording ? "Stop dictation" : "Start dictation")

            VStack(alignment: .leading, spacing: 4) {
                Text(dictation.isRecording ? "Listening…" : "Dictation")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(dictation.isRecording ? Color.red : Color.white.opacity(0.6))
                if let error = dictation.errorMessage {
                    Text(error).font(.system(size: 11)).foregroundStyle(.orange)
                } else if dictation.transcript.isEmpty {
                    Text(prefs.dictationAutoCopy ? "Speak, then stop. The text is copied for you." : "Speak, then stop.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(dictation.transcript)
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    if !dictation.isRecording {
                        HStack(spacing: 4) {
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(dictation.transcript, forType: .string)
                            }
                            Button("Clear") { dictation.clear() }
                        }
                        .buttonStyle(PillButtonStyle())
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
