//
//  PlayerView.swift
//  Soundify
//
//  Created for Soundify online music streaming and AVPlayer engine.
//

import SwiftUI

public struct PlayerView: View {
    @EnvironmentObject public var audioManager: AudioManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isLiked: Bool = false
    @State private var isShuffle: Bool = false
    @State private var isRepeat: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var sliderValue: Double = 0.0

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
            // MARK: - Layer 1: Ambient Blurred Background
            AsyncImage(url: currentSong.artwork) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .opacity(0.4)
            .blur(radius: 60)
            .ignoresSafeArea()

            // Dark tint overlay for readable contrast
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // MARK: - Layer 2: Main Player Content
            VStack(spacing: 24) {
                // Top Navigation Bar
                topBarView(for: currentSong)

                Spacer(minLength: 10)

                // Large Centered Album Art
                albumArtworkView(for: currentSong)

                Spacer(minLength: 10)

                // Track Info & Heart Button
                trackInfoView(for: currentSong)

                // Custom Slider & Time Labels
                sliderSectionView

                // Playback Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
                playbackControlsView

                // Bottom Tools (Device Connect, Share, Queue)
                bottomToolsView
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            sliderValue = audioManager.currentTime
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
                Text("PLAYING FROM STREAM")
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
        .padding(.top, 10)
    }

    private func albumArtworkView(for song: Song) -> some View {
        ZStack {
            // Front Album Card with AsyncImage
            AsyncImage(url: song.artwork) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Color.gray.opacity(0.3)
                        .overlay(
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 70))
                                .foregroundColor(.white.opacity(0.8))
                        )
                case .empty:
                    ProgressView()
                @unknown default:
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 18, x: 0, y: 10)
        }
    }

    private func trackInfoView(for song: Song) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                isLiked.toggle()
            }) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundColor(isLiked ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white)
            }
        }
    }

    private var sliderSectionView: some View {
        VStack(spacing: 4) {
            // Custom Seek Bar Slider bound to audioManager.currentTime and triggering audioManager.seek(to:)
            Slider(
                value: Binding(
                    get: { isDraggingSlider ? sliderValue : audioManager.currentTime },
                    set: { newValue in
                        sliderValue = newValue
                        audioManager.seek(to: newValue)
                    }
                ),
                in: 0...max(audioManager.duration, 1.0),
                onEditingChanged: { editing in
                    isDraggingSlider = editing
                    if !editing {
                        audioManager.seek(to: sliderValue)
                    }
                }
            )
            .accentColor(Color(red: 1.0, green: 0.33, blue: 0.0)) // SoundCloud Orange

            // Time Labels
            HStack {
                Text(audioManager.formatTime(audioManager.currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))

                Spacer()

                Text("-" + audioManager.formatTime(max(0, audioManager.duration - audioManager.currentTime)))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))
            }
        }
    }

    private var playbackControlsView: some View {
        HStack {
            // Shuffle
            Button(action: { isShuffle.toggle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 20))
                    .foregroundColor(isShuffle ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.6))
            }

            Spacer()

            // Previous Button
            Button(action: {
                audioManager.previous()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            Spacer()

            // Big Play / Pause Button
            Button(action: {
                audioManager.playPause()
            }) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: audioManager.isPlaying ? 0 : 2)
                    )
                    .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 2)
            }

            Spacer()

            // Next Button
            Button(action: {
                audioManager.next()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            Spacer()

            // Repeat
            Button(action: { isRepeat.toggle() }) {
                Image(systemName: "repeat")
                    .font(.system(size: 20))
                    .foregroundColor(isRepeat ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.6))
            }
        }
        .padding(.horizontal, 4)
    }

    private var bottomToolsView: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.top, 8)
    }
}
