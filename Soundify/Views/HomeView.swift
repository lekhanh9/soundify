import SwiftUI

public struct HomeView: View {
    @EnvironmentObject public var musicManager: MusicManager
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main dark background with ambient gradients
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header with app branding
                headerView

                // Scrollable Feed
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        // Quick filter chips
                        categoryChipsView
                            .padding(.horizontal, 16)

                        // "Recent" Playlists section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Recently Played")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(Playlist.sampleRecent) { playlist in
                                        PlaylistCardView(playlist: playlist) {
                                            if let firstTrack = playlist.tracks.first {
                                                musicManager.play(track: firstTrack)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // "Made For You" Playlists section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Made For You")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(Playlist.sampleMadeForYou) { playlist in
                                        PlaylistCardView(playlist: playlist) {
                                            if let firstTrack = playlist.tracks.first {
                                                musicManager.play(track: firstTrack)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // SoundCloud-style Trending Tracks with Waveforms
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Trending Waveforms")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)

                                Spacer()

                                Text("Show all")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 1.0, green: 0.33, blue: 0.0)) // SoundCloud Orange
                            }
                            .padding(.horizontal, 16)

                            VStack(spacing: 4) {
                                ForEach(musicManager.queue) { track in
                                    TrackRowView(
                                        track: track,
                                        isCurrent: musicManager.currentTrack?.id == track.id,
                                        isPlaying: musicManager.isPlaying
                                    ) {
                                        musicManager.play(track: track)
                                    }
                                }
                            }
                        }

                        // Bottom padding for mini-player
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.top, 12)
                }
            }

            // Persistent Floating Mini-Player
            if let track = musicManager.currentTrack {
                miniPlayerView(for: track)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $musicManager.isPlayerPresented) {
            PlayerView()
                .environmentObject(musicManager)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                // App Logo Icon
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.35, blue: 0.0), Color(red: 0.11, green: 0.84, blue: 0.38)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Soundify")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
            }

            Spacer()

            HStack(spacing: 18) {
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.system(size: 19))
                        .foregroundColor(.white)
                }

                Button(action: {}) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 19))
                        .foregroundColor(.white)
                }

                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 19))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var categoryChipsView: some View {
        HStack(spacing: 8) {
            chipButton(title: "All", isSelected: selectedTab == 0) { selectedTab = 0 }
            chipButton(title: "Music", isSelected: selectedTab == 1) { selectedTab = 1 }
            chipButton(title: "Podcasts", isSelected: selectedTab == 2) { selectedTab = 2 }
            chipButton(title: "SoundCloud Sets", isSelected: selectedTab == 3) { selectedTab = 3 }
            Spacer()
        }
    }

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color(red: 0.11, green: 0.84, blue: 0.38) : Color.white.opacity(0.1))
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(20)
        }
    }

    private func miniPlayerView(for track: Track) -> some View {
        Button(action: {
            musicManager.isPlayerPresented = true
        }) {
            HStack(spacing: 12) {
                // Mini Artwork
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: track.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: track.coverIconName)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Play / Pause Button
                Button(action: {
                    musicManager.togglePlayPause()
                }) {
                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }

                // Next Button
                Button(action: {
                    musicManager.next()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack(alignment: .bottom) {
                    // Blurred frosted glass background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.95))

                    // Progress bar at bottom of mini-player
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color(red: 1.0, green: 0.33, blue: 0.0)) // SoundCloud Orange progress line
                            .frame(width: geo.size.width * CGFloat(musicManager.playbackProgress), height: 2.5)
                    }
                    .frame(height: 2.5)
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
