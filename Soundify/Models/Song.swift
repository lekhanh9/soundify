//
//  Song.swift
//  Soundify
//
//  Created for Soundify streaming audio engine.
//

import Foundation

public struct Song: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let streamURL: String
    public let artworkURL: String
    public let duration: Double

    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        streamURL: String,
        artworkURL: String,
        duration: Double
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.streamURL = streamURL
        self.artworkURL = artworkURL
        self.duration = duration
    }

    /// Convenience property to access streamURL as a Foundation URL
    public var url: URL? {
        URL(string: streamURL)
    }

    /// Convenience property to access artworkURL as a Foundation URL
    public var artwork: URL? {
        URL(string: artworkURL)
    }
}
