//
//  MiniPlayerBar.swift
//  Soundify
//
//  Created for Soundify - Spotify Floating Mini-Player Bar.
//

import SwiftUI

public struct MiniPlayerBar: View {
    @EnvironmentObject public var audioManager: AudioManager

    public init() {}

    public var body: some View {
        if let song = audioManager.currentSong {
            Button(action: {
                audioManager.isPlayerPresented = true
            }) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Artwork
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
                                    Image(systemName: "music.note")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                )
                            }
                        }
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)

                        // Title & Artist
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(song.artist)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.spotifySubtext)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Like Heart Button
                        Button(action: {
                            audioManager.toggleLike(song: song)
                        }) {
                            Image(systemName: audioManager.isLiked(song: song) ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .foregroundColor(audioManager.isLiked(song: song) ? Color.spotifyGreen : Color.spotifySubtext)
                                .padding(6)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Play/Pause Button
                        Button(action: {
                            audioManager.playPause()
                        }) {
                            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                    // Bottom Edge Mini Progress Bar (Spotify signature)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 2.5)

                            Rectangle()
                                .fill(Color.spotifyGreen)
                                .frame(width: geo.size.width * CGFloat(audioManager.playbackProgress), height: 2.5)
                        }
                    }
                    .frame(height: 2.5)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.14, green: 0.14, blue: 0.15))
                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
