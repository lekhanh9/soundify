import SwiftUI

public struct PlayerView: View {
    @EnvironmentObject public var musicManager: MusicManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isLiked: Bool = false
    @State private var isShuffle: Bool = false
    @State private var isRepeat: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var sliderValue: Double = 0.0

    public init() {}

    public var body: some View {
        let track = musicManager.currentTrack ?? Track.sampleTracks[0]

        ZStack {
            // MARK: - Layer 1: Ambient Blurred Background
            LinearGradient(
                colors: track.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.65)
            .blur(radius: 60)
            .ignoresSafeArea()

            // Dark tint overlay for readable contrast
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // MARK: - Layer 2: Main Player Content
            VStack(spacing: 24) {
                // Top Navigation Bar
                topBarView(for: track)

                Spacer(minLength: 10)

                // Large Centered Album Art
                albumArtworkView(for: track)

                Spacer(minLength: 10)

                // Track Info & Heart Button
                trackInfoView(for: track)

                // SoundCloud Waveform Visualizer
                waveformSectionView(for: track)

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
            sliderValue = musicManager.playbackProgress
        }
    }

    // MARK: - Subviews

    private func topBarView(for track: Track) -> some View {
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

                Text(track.album)
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

    private func albumArtworkView(for track: Track) -> some View {
        ZStack {
            // Soft colored glow shadow
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: track.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 290, height: 290)
                .blur(radius: 28)
                .opacity(0.55)

            // Front Album Card
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: track.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 300, height: 300)
                .overlay(
                    Image(systemName: track.coverIconName)
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(.white.opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 8)
        }
    }

    private func trackInfoView(for track: Track) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.artist)
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

    private func waveformSectionView(for track: Track) -> some View {
        VStack(spacing: 6) {
            WaveformView(
                samples: track.waveformSamples,
                progress: isDraggingSlider ? sliderValue : musicManager.playbackProgress
            ) { newProgress in
                musicManager.seek(progress: newProgress)
            }
            .frame(height: 44)
        }
    }

    private var sliderSectionView: some View {
        VStack(spacing: 4) {
            // Custom Seek Bar Slider
            Slider(
                value: Binding(
                    get: { isDraggingSlider ? sliderValue : musicManager.playbackProgress },
                    set: { newValue in
                        sliderValue = newValue
                        musicManager.seek(progress: newValue)
                    }
                ),
                in: 0...1.0,
                onEditingChanged: { editing in
                    isDraggingSlider = editing
                }
            )
            .accentColor(Color(red: 1.0, green: 0.33, blue: 0.0)) // SoundCloud Orange

            // Time Labels
            HStack {
                Text(musicManager.formatTime(musicManager.currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))

                Spacer()

                Text("-" + musicManager.formatTime(max(0, musicManager.duration - musicManager.currentTime)))
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
                musicManager.previous()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            Spacer()

            // Big Play / Pause Button
            Button(action: {
                musicManager.togglePlayPause()
            }) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: musicManager.isPlaying ? 0 : 2)
                    )
                    .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 2)
            }

            Spacer()

            // Next Button
            Button(action: {
                musicManager.next()
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
