//
//  HomeView.swift
//  Soundify
//
//  Created for Soundify - Spotify & Open-Source Music Player Experience.
//

import SwiftUI

public struct HomeView: View {
    @EnvironmentObject public var audioManager: AudioManager
    @State private var selectedFilter: String = "All"

    private let filterOptions = ["All", "Music", "Podcasts"]

    public init() {}

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<18:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.spotifyBlack
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header (Greeting & Notification/Settings icons)
                headerView

                // Main Scrollable Spotify Feed
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Filter Pills
                        filterPillsView

                        // Spotify 2x3 Quick Access Grid
                        quickAccessGrid

                        // Online Streaming: Trending Tracks
                        trendingSection

                        // Recently Played Carousel
                        recentlyPlayedSection

                        // Made For You Carousel
                        madeForYouSection

                        // Bottom Spacer for Mini Player
                        Spacer()
                            .frame(height: 110)
                    }
                    .padding(.top, 8)
                }
            }

            // Floating Mini-Player Bar
            MiniPlayerBar()
                .padding(.bottom, 6)
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
            Text(greetingText)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

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
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var filterPillsView: some View {
        HStack(spacing: 8) {
            ForEach(filterOptions, id: \.self) { option in
                Button(action: {
                    selectedFilter = option
                }) {
                    Text(option)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedFilter == option ? .black : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(selectedFilter == option ? Color.spotifyGreen : Color.spotifyDarkGray)
                        .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }

    private var quickAccessGrid: some View {
        let items: [(title: String, icon: String, gradient: [Color])] = [
            ("Liked Songs", "heart.fill", [Color(red: 0.27, green: 0.04, blue: 0.96), Color(red: 0.55, green: 0.55, blue: 0.90)]),
            ("Top Hits 2026", "flame.fill", [Color.orange, Color.red]),
            ("Synthwave Drift", "sparkles", [Color.purple, Color.blue]),
            ("Chill Acoustic", "leaf.fill", [Color.green, Color.teal]),
            ("Cyber Sunset", "sun.max.fill", [Color.pink, Color.purple]),
            ("Deep Resonance", "speaker.wave.3.fill", [Color.blue, Color.indigo])
        ]

        let gridColumns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(0..<items.count, id: \.self) { idx in
                let item = items[idx]
                Button(action: {
                    if let song = audioManager.playlist.indices.contains(idx) ? audioManager.playlist[idx] : audioManager.playlist.first {
                        audioManager.play(song: song)
                    }
                }) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: item.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: item.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            )

                        Text(item.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Circle()
                            .fill(Color.spotifyGreen)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                                    .offset(x: 1)
                            )
                            .padding(.trailing, 8)
                    }
                    .background(Color.spotifyDarkGray)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trending Online")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(audioManager.playlist.count) tracks")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.spotifyGreen)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 4) {
                ForEach(audioManager.playlist) { song in
                    songRow(for: song)
                }
            }
        }
    }

    private func songRow(for song: Song) -> some View {
        let isCurrent = (audioManager.currentSong?.id == song.id)
        return Button(action: {
            audioManager.play(song: song)
        }) {
            HStack(spacing: 12) {
                AsyncImage(url: song.artwork) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.spotifyDarkGray
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 48, height: 48)
                .cornerRadius(6)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isCurrent ? Color.spotifyGreen : .white)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.system(size: 13))
                        .foregroundColor(Color.spotifySubtext)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    audioManager.toggleLike(song: song)
                }) {
                    Image(systemName: audioManager.isLiked(song: song) ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(audioManager.isLiked(song: song) ? Color.spotifyGreen : Color.spotifySubtext)
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(Color.spotifySubtext)
                        .padding(.trailing, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isCurrent ? Color.white.opacity(0.06) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recently Played")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
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
    }

    private var madeForYouSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Made For You")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
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
    }
}
