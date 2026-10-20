import Foundation
import SwiftUI

public struct Track: Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    public let coverIconName: String
    public let gradientColors: [Color]
    public let waveformSamples: [CGFloat]

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        coverIconName: String = "music.note",
        gradientColors: [Color] = [.purple, .blue],
        waveformSamples: [CGFloat] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.coverIconName = coverIconName
        self.gradientColors = gradientColors
        self.waveformSamples = waveformSamples.isEmpty ? Track.generateDummyWaveform() : waveformSamples
    }

    public static func generateDummyWaveform(count: Int = 40) -> [CGFloat] {
        return (0..<count).map { index in
            let normalized = CGFloat(index) / CGFloat(count)
            let base = sin(normalized * .pi * 3) * 0.4 + 0.5
            let randomVariation = CGFloat((index * 17) % 10) / 30.0
            return max(0.15, min(1.0, base + randomVariation))
        }
    }

    public static let sampleTracks: [Track] = [
        Track(
            title: "Midnight Echoes",
            artist: "Kavinsky & Daft Sound",
            album: "Synthwave Horizons",
            duration: 214,
            coverIconName: "waveform.path.ecg",
            gradientColors: [Color(red: 0.95, green: 0.35, blue: 0.15), Color(red: 0.65, green: 0.1, blue: 0.45)]
        ),
        Track(
            title: "Cyber Sunset",
            artist: "Neon Pulse",
            album: "Future Tokyo",
            duration: 188,
            coverIconName: "sun.max.fill",
            gradientColors: [Color(red: 0.15, green: 0.8, blue: 0.6), Color(red: 0.1, green: 0.3, blue: 0.8)]
        ),
        Track(
            title: "Deep Resonance",
            artist: "SubBass Collective",
            album: "Low End Theory",
            duration: 245,
            coverIconName: "speaker.wave.3.fill",
            gradientColors: [Color(red: 0.4, green: 0.1, blue: 0.9), Color(red: 0.1, green: 0.05, blue: 0.3)]
        ),
        Track(
            title: "Starlight Drift",
            artist: "Aura Void",
            album: "Ambient Galaxies",
            duration: 270,
            coverIconName: "sparkles",
            gradientColors: [Color(red: 0.2, green: 0.5, blue: 0.95), Color(red: 0.05, green: 0.1, blue: 0.4)]
        )
    ]
}

public struct Playlist: Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let gradientColors: [Color]
    public let tracks: [Track]

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        iconName: String = "music.note.list",
        gradientColors: [Color] = [.orange, .red],
        tracks: [Track] = Track.sampleTracks
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.gradientColors = gradientColors
        self.tracks = tracks
    }

    public static let sampleRecent: [Playlist] = [
        Playlist(
            title: "Bass Drops & 808s",
            subtitle: "Updated Daily",
            iconName: "waveform.badge.magnifyingglass",
            gradientColors: [Color(red: 1.0, green: 0.35, blue: 0.0), Color(red: 0.8, green: 0.1, blue: 0.2)]
        ),
        Playlist(
            title: "Night Drive Lo-Fi",
            subtitle: "Chill Vibes",
            iconName: "moon.stars.fill",
            gradientColors: [Color(red: 0.3, green: 0.1, blue: 0.6), Color(red: 0.1, green: 0.2, blue: 0.5)]
        ),
        Playlist(
            title: "Techno Underground",
            subtitle: "Berlin Sound",
            iconName: "bolt.horizontal.fill",
            gradientColors: [Color(red: 0.1, green: 0.7, blue: 0.3), Color(red: 0.05, green: 0.3, blue: 0.2)]
        )
    ]

    public static let sampleMadeForYou: [Playlist] = [
        Playlist(
            title: "Daily Mix 1",
            subtitle: "Kavinsky, Neon Pulse and more",
            iconName: "heart.fill",
            gradientColors: [Color(red: 0.85, green: 0.2, blue: 0.5), Color(red: 0.35, green: 0.1, blue: 0.6)]
        ),
        Playlist(
            title: "Discover Weekly",
            subtitle: "Your weekly mixtape of fresh music",
            iconName: "sparkle",
            gradientColors: [Color(red: 0.1, green: 0.6, blue: 0.8), Color(red: 0.05, green: 0.2, blue: 0.4)]
        ),
        Playlist(
            title: "Release Radar",
            subtitle: "Catch all the latest music from artists you follow",
            iconName: "antenna.radiowaves.left.and.right",
            gradientColors: [Color(red: 0.9, green: 0.5, blue: 0.1), Color(red: 0.6, green: 0.2, blue: 0.05)]
        )
    ]
}
