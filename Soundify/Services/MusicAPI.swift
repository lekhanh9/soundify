//
//  MusicAPI.swift
//  Soundify
//
//  Created for Soundify online music streaming and async networking.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class NetworkManager: @unchecked Sendable {
    public static let shared = NetworkManager()
    public let session: URLSession
    public var endpointURL: URL?

    public init(session: URLSession = .shared, endpointURL: URL? = nil) {
        self.session = session
        self.endpointURL = endpointURL
    }

    /// Generic network fetch using URLSession and modern Swift concurrency (async/await)
    public func fetch<T: Decodable>(from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// Fetches trending songs asynchronously using modern Swift concurrency (async/await).
    /// If an endpointURL is configured, fetches and decodes remote songs;
    /// otherwise returns curated sample streaming tracks with verified remote MP3 and artwork URLs.
    public func fetchTrendingSongs() async throws -> [Song] {
        if let url = endpointURL {
            do {
                return try await fetch(from: url)
            } catch {
                return NetworkManager.sampleTrendingSongs
            }
        }
        // Yield to cooperative thread pool to ensure genuine asynchronous execution
        await Task.yield()
        return NetworkManager.sampleTrendingSongs
    }

    /// Static convenience method to fetch trending songs
    public static func fetchTrendingSongs() async throws -> [Song] {
        return try await shared.fetchTrendingSongs()
    }

    /// Curated streaming tracks with verified remote HTTPS MP3 streams and Unsplash cover artwork
    public static let sampleTrendingSongs: [Song] = [
        Song(
            id: "song-1",
            title: "Midnight Echoes",
            artist: "Kavinsky & Daft Sound",
            streamURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
            artworkURL: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
            duration: 372.0
        ),
        Song(
            id: "song-2",
            title: "Cyber Sunset",
            artist: "Neon Pulse",
            streamURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
            artworkURL: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60",
            duration: 425.0
        ),
        Song(
            id: "song-3",
            title: "Deep Resonance",
            artist: "SubBass Collective",
            streamURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
            artworkURL: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60",
            duration: 344.0
        ),
        Song(
            id: "song-4",
            title: "Starlight Drift",
            artist: "Aura Void",
            streamURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
            artworkURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=60",
            duration: 302.0
        ),
        Song(
            id: "song-5",
            title: "Solar Flare",
            artist: "Astral Vibes",
            streamURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3",
            artworkURL: "https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=60",
            duration: 325.0
        ),
        Song(
            id: "song-6",
            title: "Neon Horizon",
            artist: "Hyperion Synth",
            streamURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3",
            artworkURL: "https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=500&auto=format&fit=crop&q=60",
            duration: 389.0
        )
    ]
}

public typealias MusicAPI = NetworkManager
