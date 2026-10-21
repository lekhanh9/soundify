//
//  PlayerView.swift
//  Soundify
//
//  Created for Soundify - Spotify Full-Screen Now Playing & Synced Lyrics.
//

import SwiftUI

public struct PlayerView: View {
    @EnvironmentObject public var audioManager: AudioManager
    @Environment(\.presentationMode) var presentationMode

    @State private var isDraggingSlider: Bool = false
    @State private var sliderValue: Double = 0.0
    @State private var showLyricsCard: Bool = false
    @State private var showQueueSheet: Bool = false
    @State private var lyrics: [LyricLine] = []

    public init() {}

    public var body: some View {
        let currentSong = audioManager.currentSong ?? Song(
            id: "default",
            title: "Midnight Echoes",
            artist: "Kavinsky & Daft Sound",
            streamURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
            artworkURL: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
            duration: 372.0
        )

        ZStack {
            // Ambient Blurred Artwork Background
            AsyncImage(url: currentSong.artwork) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .opacity(0.4)
            .blur(radius: 50)
            .ignoresSafeArea()

            Color.black.opacity(0.65)
                .ignoresSafeArea()

            // Main Content
            VStack(spacing: 20) {
                // Top Navigation Bar
                topBarView(for: currentSong)

                Spacer(minLength: 6)

                if showLyricsCard {
                    // Synced Lyrics Full View
                    lyricsContainerView
                } else {
                    // Centered Album Artwork
                    albumArtworkView(for: currentSong)

                    Spacer(minLength: 6)

                    // Track Title, Artist & Like Heart
                    trackInfoView(for: currentSong)

                    // Scrub Slider & Timestamps
                    sliderSectionView

                    // Spotify Playback Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
                    playbackControlsView
                }

                // Bottom Tools (Device Connect, Lyrics Toggle, Queue Sheet)
                bottomToolsView
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            sliderValue = audioManager.currentTime
            lyrics = LyricsService.shared.fetchLyrics(for: currentSong)
        }
        .onChange(of: audioManager.currentSong?.id) { _ in
            lyrics = LyricsService.shared.fetchLyrics(for: currentSong)
        }
        .sheet(isPresented: $showQueueSheet) {
            queueSheetView
        }
    }

    // MARK: - Subviews

    private func topBarView(for song: Song) -> some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("PLAYING FROM PLAYLIST")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.7))
                    .kerning(1.2)

                Text(song.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        }
        .padding(.top, 8)
    }

    private func albumArtworkView(for song: Song) -> some View {
        AsyncImage(url: song.artwork) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            default:
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.8))
                )
            }
        }
        .frame(width: 310, height: 310)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
    }

    private func trackInfoView(for song: Song) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.spotifySubtext)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                audioManager.toggleLike(song: song)
            }) {
                Image(systemName: audioManager.isLiked(song: song) ? "heart.fill" : "heart")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(audioManager.isLiked(song: song) ? Color.spotifyGreen : .white)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var sliderSectionView: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let currentProgress = audioManager.duration > 0 ? (isDraggingSlider ? sliderValue / audioManager.duration : audioManager.currentTime / audioManager.duration) : 0.0
                let clampedProgress = max(0.0, min(currentProgress, 1.0))

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)

                    // Played progress (Spotify Green)
                    Capsule()
                        .fill(Color.spotifyGreen)
                        .frame(width: totalWidth * CGFloat(clampedProgress), height: 4)

                    // Scrubber thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .offset(x: max(0, min(totalWidth * CGFloat(clampedProgress) - 6, totalWidth - 12)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingSlider = true
                            let progress = max(0.0, min(Double(value.location.x / totalWidth), 1.0))
                            sliderValue = progress * audioManager.duration
                        }
                        .onEnded { value in
                            let progress = max(0.0, min(Double(value.location.x / totalWidth), 1.0))
                            let targetSeconds = progress * audioManager.duration
                            audioManager.seek(to: targetSeconds)
                            isDraggingSlider = false
                        }
                )
            }
            .frame(height: 14)

            // Timestamps
            HStack {
                Text(audioManager.formatTime(isDraggingSlider ? sliderValue : audioManager.currentTime))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.spotifySubtext)

                Spacer()

                Text(audioManager.formatRemainingTime())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.spotifySubtext)
            }
        }
    }

    private var playbackControlsView: some View {
        HStack {
            // Shuffle
            Button(action: {
                audioManager.toggleShuffle()
            }) {
                VStack(spacing: 3) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 20))
                        .foregroundColor(audioManager.isShuffle ? Color.spotifyGreen : Color.spotifySubtext)

                    Circle()
                        .fill(audioManager.isShuffle ? Color.spotifyGreen : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }

            Spacer()

            // Previous
            Button(action: {
                audioManager.previous()
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }

            Spacer()

            // Big Circular Play/Pause (Spotify Signature)
            SpotifyPlayButton(size: 64, isPlaying: audioManager.isPlaying) {
                audioManager.playPause()
            }

            Spacer()

            // Next
            Button(action: {
                audioManager.next()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }

            Spacer()

            // Repeat (Off / All / One)
            Button(action: {
                audioManager.toggleRepeat()
            }) {
                VStack(spacing: 3) {
                    ZStack {
                        Image(systemName: audioManager.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.system(size: 20))
                            .foregroundColor(audioManager.repeatMode != .off ? Color.spotifyGreen : Color.spotifySubtext)
                    }

                    Circle()
                        .fill(audioManager.repeatMode != .off ? Color.spotifyGreen : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Synced Lyrics View (Spotify Swipe-Up Style)

    private var lyricsContainerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lyrics")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    withAnimation {
                        showLyricsCard = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.spotifySubtext)
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(lyrics.indices, id: \.self) { idx in
                            let line = lyrics[idx]
                            let activeIdx = LyricsService.shared.currentLineIndex(at: audioManager.currentTime, in: lyrics)
                            let isActive = (activeIdx == idx)

                            Button(action: {
                                audioManager.seek(to: line.time)
                            }) {
                                Text(line.text)
                                    .font(.system(size: isActive ? 22 : 18, weight: isActive ? .heavy : .semibold))
                                    .foregroundColor(isActive ? .white : Color.spotifySubtext.opacity(0.6))
                                    .scaleEffect(isActive ? 1.04 : 1.0, anchor: .leading)
                                    .multilineTextAlignment(.leading)
                                    .animation(.easeInOut(duration: 0.2), value: isActive)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .id(idx)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .onChange(of: audioManager.currentTime) { newTime in
                    if let activeIdx = LyricsService.shared.currentLineIndex(at: newTime, in: lyrics) {
                        withAnimation {
                            proxy.scrollTo(activeIdx, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.85))
        )
        .frame(maxHeight: 380)
    }

    private var bottomToolsView: some View {
        HStack {
            // Devices
            Button(action: {}) {
                Image(systemName: "hifispeaker.2")
                    .font(.system(size: 18))
                    .foregroundColor(Color.spotifySubtext)
            }

            Spacer()

            // Lyrics Card Toggle Button
            Button(action: {
                withAnimation {
                    showLyricsCard.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 15))
                    Text("Lyrics")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(showLyricsCard ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(showLyricsCard ? Color.spotifyGreen : Color.white.opacity(0.12))
                .cornerRadius(16)
            }

            Spacer()

            // Queue Sheet Button
            Button(action: {
                showQueueSheet = true
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
                    .foregroundColor(Color.spotifySubtext)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: - Queue Sheet

    private var queueSheetView: some View {
        ZStack {
            Color.spotifyBlack
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Play Queue")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        showQueueSheet = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Now Playing Section
                        if let current = audioManager.currentSong {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Now Playing")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.spotifySubtext)
                                    .padding(.horizontal, 16)

                                HStack(spacing: 12) {
                                    AsyncImage(url: current.artwork) { phase in
                                        if let img = phase.image {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color.spotifyDarkGray
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(6)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(current.title)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color.spotifyGreen)
                                            .lineLimit(1)

                                        Text(current.artist)
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.spotifySubtext)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(Color.spotifyGreen)
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Next in Queue Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Next In Queue")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.spotifySubtext)
                                .padding(.horizontal, 16)

                            if audioManager.playlist.isEmpty && audioManager.queue.isEmpty {
                                Text("Queue is empty")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.spotifySubtext)
                                    .padding(.horizontal, 16)
                            } else {
                                ForEach(audioManager.playlist.filter { $0.id != audioManager.currentSong?.id }) { song in
                                    Button(action: {
                                        audioManager.play(song: song)
                                        showQueueSheet = false
                                    }) {
                                        HStack(spacing: 12) {
                                            AsyncImage(url: song.artwork) { phase in
                                                if let img = phase.image {
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                } else {
                                                    Color.spotifyDarkGray
                                                }
                                            }
                                            .frame(width: 44, height: 44)
                                            .cornerRadius(6)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(song.title)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)

                                                Text(song.artist)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Color.spotifySubtext)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            Image(systemName: "line.3.horizontal")
                                                .foregroundColor(Color.spotifySubtext)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
