import AppKit
import SwiftUI

struct ShelfView: View {
    @ObservedObject var shelf: ShelfStore
    let accent: Color
    let isTargeted: Bool

    var body: some View {
        HStack(spacing: 12) {
            if shelf.items.isEmpty {
                dropZone
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(shelf.items, id: \.self) { url in
                            ShelfItemView(url: url) { shelf.remove(url) }
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 4)
                    .animation(islandSpring, value: shelf.items)
                }
                .frame(maxWidth: .infinity)
                .islandCard()
                .overlay {
                    if isTargeted {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(accent, lineWidth: 1.5)
                    }
                }

                VStack(spacing: 8) {
                    Button { shelf.airDropAll() } label: {
                        Label("AirDrop", systemImage: "dot.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                    }
                    Button { shelf.clear() } label: {
                        Label("Clear", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PillButtonStyle())
                .frame(width: 92)
            }
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            .foregroundStyle(isTargeted ? accent : .white.opacity(0.25))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isTargeted ? accent.opacity(0.12) : .white.opacity(0.03))
            )
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isTargeted ? accent : .white.opacity(0.6))
                        .symbolEffect(.bounce, value: isTargeted)
                    Text("Drop files here to keep them handy")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .animation(.easeOut(duration: 0.2), value: isTargeted)
    }
}

struct ShelfItemView: View {
    let url: URL
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 46, height: 46)
            Text(url.lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(hovering ? 0.1 : 0))
        )
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .gray)
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: -2)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
            Divider()
            Button("Remove from Shelf", action: onRemove)
        }
        .help(url.path)
    }
}
