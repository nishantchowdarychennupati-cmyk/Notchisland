import SwiftUI

/// The Now Playing tab: music only, with room for large artwork, seeking and volume.
struct NowPlayingView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var media: MediaController
    @ObservedObject var audio: SystemAudio
    @ObservedObject var prefs: Preferences

    init(model: IslandModel, prefs: Preferences) {
        self.model = model
        media = model.media
        audio = model.audio
        self.prefs = prefs
    }

    private var accent: Color { model.accent }
    private var animate: Bool { model.animateVisualizer }

    var body: some View {
        HStack(spacing: 18) {
            artwork
            if let track = media.current {
                details(track)
            } else {
                emptyState
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Artwork

    private var artwork: some View {
        ZStack {
            if prefs.artworkGlow, let art = media.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 116, height: 116)
                    .blur(radius: 22)
                    .opacity(media.isPlaying ? 0.65 : 0.25)
            }
            ArtworkView(image: media.artwork, cornerRadius: 20, accent: accent,
                        spinning: prefs.artworkSpin && animate)
                .frame(width: 116, height: 116)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
        }
        .scaleEffect(media.isPlaying || media.current == nil ? 1 : 0.9)
        .animation(.spring(response: 0.38, dampingFraction: 0.62), value: media.isPlaying)
    }

    // MARK: Track details and controls

    private func details(_ track: NowPlaying) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    if !track.album.isEmpty {
                        Text(track.album)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .frame(width: prefs.showLyrics ? 160 : nil, alignment: .leading)
                .id(track.title + track.artist)
                .transition(.blurReplace)
                if prefs.showLyrics {
                    LyricsPanel(lyrics: model.lyrics, media: media, accent: accent,
                                style: prefs.lyricsStyle, glow: prefs.lyricsGlow)
                        .frame(maxWidth: .infinity, maxHeight: 54, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                }
                VStack(alignment: .trailing, spacing: 6) {
                    AudioVisualizer(style: prefs.visualizer, playing: track.isPlaying, animate: animate,
                                    color: accent, height: 16)
                    Text(track.source.appName)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.12)))
                        .foregroundStyle(.white.opacity(0.7))
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

            HStack(spacing: 0) {
                HStack(spacing: 22) {
                    controlButton("backward.fill", size: 18, action: media.previousTrack)
                    Button(action: media.playPause) {
                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(PressableStyle())
                    controlButton("forward.fill", size: 18, action: media.nextTrack)
                }
                Spacer(minLength: 16)
                IslandSlider(
                    value: audio.isMuted ? 0 : Double(audio.volume),
                    symbol: CompactView.volumeSymbol(audio.volume, muted: audio.isMuted),
                    color: .white
                ) { audio.setVolume(Float($0)) }
                .frame(width: 150)
            }
        }
        .animation(islandSpring, value: track.title)
        .task(id: track.title + "|" + track.artist + "|\(prefs.showLyrics)") {
            if prefs.showLyrics {
                model.lyrics.load(title: track.title, artist: track.artist, album: track.album, duration: track.duration)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Nothing Playing")
                .font(.system(size: 17, weight: .bold))
            Text("Start a song in Apple Music, Spotify or Cider and it will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 6) {
                if media.isInstalled(.music) {
                    Button { media.launch(.music) } label: { Label("Music", systemImage: "music.note") }
                }
                if media.isInstalled(.spotify) {
                    Button { media.launch(.spotify) } label: { Label("Spotify", systemImage: "music.note.list") }
                }
            }
            .buttonStyle(PillButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controlButton(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 32, height: 32)
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
                .frame(height: active ? 7 : 4)
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

// MARK: - Lyrics

/// Synced lyrics that follow the song, filling the space beside the track title.
struct LyricsPanel: View {
    @ObservedObject var lyrics: LyricsService
    let media: MediaController
    let accent: Color
    let style: LyricsStyle
    let glow: Bool

    var body: some View {
        switch lyrics.state {
        case .idle, .notFound:
            Label("No lyrics for this song", systemImage: "quote.bubble")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))
                .frame(maxHeight: .infinity)
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Finding lyrics…").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxHeight: .infinity)
        case .plain(let text):
            ScrollView(.vertical, showsIndicators: false) {
                Text(text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .synced(let lines):
            // Redraws only a few times a second, and only while this tab is on screen.
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let position = media.position(at: context.date) + 0.25
                SyncedLyricsLines(lines: lines, index: Self.index(in: lines, at: position),
                                  accent: accent, style: style, glow: glow)
            }
        }
    }

    /// Index of the line being sung at `position`, or -1 before the first line.
    static func index(in lines: [LyricLine], at position: Double) -> Int {
        var low = 0, high = lines.count - 1, result = -1
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }
}

struct SyncedLyricsLines: View {
    let lines: [LyricLine]
    let index: Int
    let accent: Color
    let style: LyricsStyle
    let glow: Bool

    private func text(_ i: Int) -> String {
        guard i >= 0, i < lines.count else { return i < 0 ? "♪" : "" }
        let t = lines[i].text
        return t.isEmpty ? "♪" : t
    }

    var body: some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 3) {
                if style == .threeLines {
                    Text(text(index - 1))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineLimit(1)
                }
                Text(text(index))
                    .font(.system(size: style == .threeLines ? 14 : 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(style == .threeLines ? 1 : 2)
                    .minimumScaleFactor(0.75)
                    .shadow(color: glow ? accent.opacity(0.7) : .clear, radius: 6)
                if style == .threeLines {
                    Text(text(index + 1))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(index)
            .transition(.asymmetric(
                insertion: .push(from: .bottom).combined(with: .opacity),
                removal: .push(from: .bottom).combined(with: .opacity)
            ))
        }
        .frame(maxHeight: .infinity)
        .clipped()
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: index)
    }
}
