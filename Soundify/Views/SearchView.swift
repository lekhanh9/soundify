//
//  SearchView.swift
//  Soundify
//
//  Created for Soundify - Spotify Browse & Live Search Experience.
//

import SwiftUI

public struct GenreCategory: Identifiable {
    public let id = UUID()
    public let title: String
    public let iconName: String
    public let colors: [Color]

    public static let sampleCategories: [GenreCategory] = [
        GenreCategory(title: "Pop Hits", iconName: "star.fill", colors: [Color(red: 0.85, green: 0.15, blue: 0.45), Color(red: 0.55, green: 0.05, blue: 0.35)]),
        GenreCategory(title: "Hip-Hop", iconName: "flame.fill", colors: [Color(red: 0.95, green: 0.45, blue: 0.10), Color(red: 0.75, green: 0.20, blue: 0.05)]),
        GenreCategory(title: "Rock & Metal", iconName: "guitars.fill", colors: [Color(red: 0.80, green: 0.10, blue: 0.15), Color(red: 0.40, green: 0.05, blue: 0.10)]),
        GenreCategory(title: "Indie & Alt", iconName: "sparkles", colors: [Color(red: 0.45, green: 0.20, blue: 0.75), Color(red: 0.25, green: 0.08, blue: 0.50)]),
        GenreCategory(title: "Chill & Lofi", iconName: "cup.and.saucer.fill", colors: [Color(red: 0.10, green: 0.60, blue: 0.80), Color(red: 0.05, green: 0.30, blue: 0.55)]),
        GenreCategory(title: "Electronic / EDM", iconName: "bolt.fill", colors: [Color(red: 0.10, green: 0.75, blue: 0.45), Color(red: 0.05, green: 0.45, blue: 0.25)]),
        GenreCategory(title: "Acoustic", iconName: "leaf.fill", colors: [Color(red: 0.85, green: 0.65, blue: 0.15), Color(red: 0.60, green: 0.40, blue: 0.08)]),
        GenreCategory(title: "Podcasts", iconName: "mic.fill", colors: [Color(red: 0.15, green: 0.65, blue: 0.65), Color(red: 0.08, green: 0.35, blue: 0.40)])
    ]
}

public struct SearchView: View {
    @EnvironmentObject public var audioManager: AudioManager
    @State private var searchQuery: String = ""

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    public init() {}

    private var filteredSongs: [Song] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return []
        }
        let q = searchQuery.lowercased()
        return audioManager.playlist.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    public var body: some View {
        ZStack {
            Color.spotifyBlack
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Search")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // Search Box
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(Color.black.opacity(0.6))

                    TextField("What do you want to listen to?", text: $searchQuery)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.black.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(8)
                .padding(.horizontal, 16)

                // Content
                ScrollView(.vertical, showsIndicators: false) {
                    if !searchQuery.isEmpty {
                        searchResultsSection
                    } else {
                        browseAllSection
                    }

                    Spacer()
                        .frame(height: 100)
                }
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Results")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            if filteredSongs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(Color.spotifySubtext)
                        .padding(.top, 40)

                    Text("No results found for \"\(searchQuery)\"")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Please check the spelling or search for another artist or song.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.spotifySubtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(filteredSongs) { song in
                        searchSongRow(song: song)
                    }
                }
            }
        }
    }

    private func searchSongRow(song: Song) -> some View {
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
                            .overlay(Image(systemName: "music.note").foregroundColor(.white))
                    }
                }
                .frame(width: 48, height: 48)
                .cornerRadius(6)

                VStack(alignment: .leading, spacing: 4) {
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
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isCurrent ? Color.white.opacity(0.06) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var browseAllSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Browse All")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(GenreCategory.sampleCategories) { category in
                    genreCard(category: category)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func genreCard(category: GenreCategory) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: category.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 100)

            HStack {
                Text(category.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)

                Spacer()

                Image(systemName: category.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.85))
                    .rotationEffect(.degrees(18))
                    .offset(x: 8, y: 18)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
