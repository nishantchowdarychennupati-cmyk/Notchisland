import SwiftUI

struct ClipboardView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var prefs: Preferences
    let accent: Color
    @State private var showSnippets = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 6) {
                modeButton("History", symbol: "clock.arrow.circlepath", selected: !showSnippets) { showSnippets = false }
                modeButton("Snippets", symbol: "text.quote", selected: showSnippets) { showSnippets = true }
                Spacer(minLength: 0)
                if !showSnippets && !store.items.isEmpty {
                    Button { withAnimation(islandSpring) { store.clear() } } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(PillButtonStyle())
                }
            }
            .frame(width: 88)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if showSnippets {
                        if prefs.snippets.isEmpty {
                            emptyState("Add snippets in Settings → Clipboard.")
                        }
                        ForEach(Array(prefs.snippets.enumerated()), id: \.offset) { _, snippet in
                            ClipCard(item: ClipItem(text: snippet, kind: .text), accent: accent, copied: false,
                                     onCopy: { store.copyText(snippet) }, onPin: nil, onDelete: nil)
                        }
                    } else {
                        if store.items.isEmpty {
                            emptyState("Copy something and it will show up here.")
                        }
                        ForEach(store.items) { item in
                            ClipCard(item: item, accent: accent, copied: store.justCopied == item.id,
                                     onCopy: { store.copy(item) },
                                     onPin: { withAnimation(islandSpring) { store.togglePin(item) } },
                                     onDelete: { withAnimation(islandSpring) { store.remove(item) } })
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func modeButton(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(islandSpring, action) }) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(selected ? 0.15 : 0)))
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.55))
            .frame(width: 260, height: 100)
            .islandCard()
    }
}

struct ClipCard: View {
    let item: ClipItem
    let accent: Color
    let copied: Bool
    let onCopy: () -> Void
    let onPin: (() -> Void)?
    let onDelete: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        Button(action: onCopy) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    if item.kind == .color, let color = Color(hex: item.text) {
                        Circle().fill(color).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: item.symbol).font(.system(size: 10))
                    }
                    Text(item.sourceApp ?? item.kind.rawValue.capitalized)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if item.pinned { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(accent) }
                }
                .foregroundStyle(.white.opacity(0.55))

                Text(item.kind == .file ? (item.text as NSString).lastPathComponent : item.text)
                    .font(.system(size: 11, design: item.kind == .text ? .default : .monospaced))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(width: 148, height: 108)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(hovering ? 0.12 : 0.07))
            )
            .overlay {
                if copied {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(0.6))
                        .overlay(Label("Copied", systemImage: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(accent))
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if hovering && (onPin != nil || onDelete != nil) {
                    HStack(spacing: 0) {
                        if let onPin {
                            Button(action: onPin) { Image(systemName: item.pinned ? "pin.slash" : "pin") }
                        }
                        if let onDelete {
                            Button(action: onDelete) { Image(systemName: "trash") }
                        }
                    }
                    .buttonStyle(IconButtonStyle(size: 20))
                    .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: copied)
        .help("Click to copy")
    }
}
