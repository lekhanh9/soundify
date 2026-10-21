//
//  LibraryView.swift
//  Soundify
//
//  Created for Soundify - Spotify "Your Library" & Liked Songs.
//

import SwiftUI

public struct LibraryView: View {
    @EnvironmentObject public var audioManager: AudioManager
    @State private var selectedFilter: String = "Playlists"

    private let filterOptions = ["Playlists", "Artists", "Downloaded"]

    public init() {}

    private var likedSongs: [Song] {
        audioManager.playlist.filter { audioManager.likedSongIDs.contains($0.id) }
    }

    public var body: some View {
        ZStack {
            Color.spotifyBlack
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color.spotifySubtext)

                    Text("Your Library")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }

                        Button(action: {}) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Filter Pills
                HStack(spacing: 8) {
                    ForEach(filterOptions, id: \.self) { option in
                        Button(action: {
                            selectedFilter = option
                        }) {
                            Text(option)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedFilter == option ? .black : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedFilter == option ? Color.white : Color.spotifyDarkGray)
                                .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)

                // Library Items List
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // 1. Pinned "Liked Songs" Tile (Spotify Signature)
                        Button(action: {
                            if let first = likedSongs.first {
                                audioManager.play(song: first)
                            } else if let first = audioManager.playlist.first {
                                audioManager.play(song: first)
                            }
                        }) {
                            HStack(spacing: 14) {
                                // Purple-Blue Gradient Square with White Heart
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.27, green: 0.04, blue: 0.96), Color(red: 0.55, green: 0.55, blue: 0.90)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 26))
                                            .foregroundColor(.white)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Liked Songs")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)

                                    HStack(spacing: 4) {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.spotifyGreen)

                                        Text("Playlist • \(likedSongs.count) songs")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.spotifySubtext)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // 2. Playlists
                        ForEach(Playlist.sampleRecent) { playlist in
                            Button(action: {
                                if let first = audioManager.playlist.first {
                                    audioManager.play(song: first)
                                }
                            }) {
                                HStack(spacing: 14) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: playlist.gradientColors,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            Image(systemName: playlist.iconName)
                                                .font(.system(size: 26))
                                                .foregroundColor(.white)
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Text("Playlist • \(playlist.subtitle)")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.spotifySubtext)
                                            .lineLimit(1)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        // Bottom Spacer for Mini Player
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}
