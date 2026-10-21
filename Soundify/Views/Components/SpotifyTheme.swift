//
//  SpotifyTheme.swift
//  Soundify
//
//  Created for Soundify - Spotify & Open-Source Music Player Design System.
//

import SwiftUI

public extension Color {
    /// Spotify brand signature neon green (#1DB954)
    static let spotifyGreen = Color(red: 0.114, green: 0.843, blue: 0.376)
    
    /// Spotify deep pure black (#121212)
    static let spotifyBlack = Color(red: 0.071, green: 0.071, blue: 0.071)
    
    /// Spotify elevated surface cards (#181818)
    static let spotifyDarkGray = Color(red: 0.094, green: 0.094, blue: 0.094)
    
    /// Spotify hover & selected card surface (#242424)
    static let spotifyLightGray = Color(red: 0.141, green: 0.141, blue: 0.141)
    
    /// Spotify secondary text / subtitle color (#B3B3B3)
    static let spotifySubtext = Color(red: 0.702, green: 0.702, blue: 0.702)
    
    /// Spotify subtle border & separator color (#2A2A2A)
    static let spotifyBorder = Color(red: 0.165, green: 0.165, blue: 0.165)
}

public struct SpotifyPlayButton: View {
    public let size: CGFloat
    public let isPlaying: Bool
    public var action: () -> Void

    public init(size: CGFloat = 48, isPlaying: Bool = false, action: @escaping () -> Void) {
        self.size = size
        self.isPlaying = isPlaying
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.spotifyGreen)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(.black)
                    .offset(x: isPlaying ? 0 : 1.5)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

public struct SpotifyHeartButton: View {
    public let isLiked: Bool
    public var action: () -> Void

    public init(isLiked: Bool, action: @escaping () -> Void) {
        self.isLiked = isLiked
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isLiked ? Color.spotifyGreen : Color.spotifySubtext)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

public struct ScaleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
