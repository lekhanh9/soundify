//
//  HomeView.swift
//  Soundify
//
//  Created for Soundify online music streaming and AVPlayer engine.
//

import SwiftUI

public struct HomeView: View {
    @EnvironmentObject public var audioManager: AudioManager
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

                        // Online Streaming Section: Trending Songs
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Trending Online")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)

                                Spacer()

                                Text("\(audioManager.playlist.count) tracks")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 1.0, green: 0.33, blue: 0.0))
                            }
                            .padding(.horizontal, 16)

                            VStack(spacing: 6) {
                                ForEach(audioManager.playlist) { song in
                                    songRow(for: song)
                                }
                            }
                        }

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
                                            if let first = audioManager.playlist.first {
                                                audioManager.play(song: first)
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
                                            if let first = audioManager.playlist.first {
                                                audioManager.play(song: first)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
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
            if let song = audioManager.currentSong {
                miniPlayerView(for: song)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await audioManager.loadPlaylist()
        }
        .sheet(isPresented: $audioManager.isPlayerPresented) {
            PlayerView()
                .environmentObject(audioManager)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
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
            chipButton(title: "Trending", isSelected: selectedTab == 3) { selectedTab = 3 }
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

    private func songRow(for song: Song) -> some View {
        let isCurrent = (audioManager.currentSong?.id == song.id)
        return Button(action: {
            audioManager.play(song: song)
        }) {
            HStack(spacing: 14) {
                // Remote Artwork with AsyncImage
                AsyncImage(url: song.artwork) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.gray.opacity(0.3)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.white)
                            )
                    case .empty:
                        ProgressView()
                    @unknown default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isCurrent ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.system(size: 13))
                        .foregroundColor(Color.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Playing indicator or duration
                if isCurrent && audioManager.isPlaying {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                        .font(.system(size: 16))
                } else {
                    Text(audioManager.formatTime(song.duration))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.gray)
                }

                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(Color.gray)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(isCurrent ? Color.white.opacity(0.05) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func miniPlayerView(for song: Song) -> some View {
        Button(action: {
            audioManager.isPlayerPresented = true
        }) {
            HStack(spacing: 12) {
                // Mini Remote Artwork
                AsyncImage(url: song.artwork) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Play / Pause Button
                Button(action: {
                    audioManager.togglePlayPause()
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }

                // Next Button
                Button(action: {
                    audioManager.next()
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.95))

                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color(red: 1.0, green: 0.33, blue: 0.0))
                            .frame(width: geo.size.width * CGFloat(audioManager.playbackProgress), height: 2.5)
                    }
                    .frame(height: 2.5)
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
