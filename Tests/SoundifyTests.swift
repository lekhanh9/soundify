//
//  SoundifyTests.swift
//  SoundifyTests
//
//  Created for Soundify online music streaming and AVPlayer engine.
//

import Foundation
import XCTest

public class SoundifyTests: XCTestCase {

    // MARK: - Song Model Tests

    func testSongInitialization() {
        let song = Song(
            id: "custom-id-123",
            title: "Midnight City",
            artist: "M83",
            streamURL: "https://example.com/song.mp3",
            artworkURL: "https://example.com/artwork.jpg",
            duration: 243.5
        )

        XCTAssertEqual(song.id, "custom-id-123")
        XCTAssertEqual(song.title, "Midnight City")
        XCTAssertEqual(song.artist, "M83")
        XCTAssertEqual(song.streamURL, "https://example.com/song.mp3")
        XCTAssertEqual(song.artworkURL, "https://example.com/artwork.jpg")
        XCTAssertEqual(song.duration, 243.5)
    }

    func testSongDefaultIDGeneration() {
        let song1 = Song(
            title: "Track A",
            artist: "Artist A",
            streamURL: "https://example.com/a.mp3",
            artworkURL: "https://example.com/a.jpg",
            duration: 180.0
        )
        let song2 = Song(
            title: "Track B",
            artist: "Artist B",
            streamURL: "https://example.com/b.mp3",
            artworkURL: "https://example.com/b.jpg",
            duration: 200.0
        )

        XCTAssertFalse(song1.id.isEmpty)
        XCTAssertFalse(song2.id.isEmpty)
        XCTAssertNotEqual(song1.id, song2.id)
        XCTAssertNotNil(UUID(uuidString: song1.id))
    }

    func testSongURLConvenienceProperties() {
        let validSong = Song(
            id: "valid-url-song",
            title: "Hyperdrive",
            artist: "Stellar",
            streamURL: "https://example.com/audio/track.mp3",
            artworkURL: "https://example.com/images/cover.jpg",
            duration: 310.0
        )

        XCTAssertNotNil(validSong.url)
        XCTAssertEqual(validSong.url?.scheme, "https")
        XCTAssertEqual(validSong.url?.host, "example.com")
        XCTAssertEqual(validSong.url?.path, "/audio/track.mp3")

        XCTAssertNotNil(validSong.artwork)
        XCTAssertEqual(validSong.artwork?.scheme, "https")
        XCTAssertEqual(validSong.artwork?.host, "example.com")
        XCTAssertEqual(validSong.artwork?.path, "/images/cover.jpg")
    }

    func testSongIdentifiableContract() {
        let song = Song(
            id: "identifiable-1",
            title: "Resonance",
            artist: "HOME",
            streamURL: "https://example.com/resonance.mp3",
            artworkURL: "https://example.com/resonance.jpg",
            duration: 212.0
        )

        let identifier: String = song.id
        XCTAssertEqual(identifier, "identifiable-1")
    }

    func testSongHashableContract() {
        let songA1 = Song(
            id: "same-id",
            title: "Song 1",
            artist: "Artist 1",
            streamURL: "https://example.com/1.mp3",
            artworkURL: "https://example.com/1.jpg",
            duration: 150.0
        )
        let songA2 = Song(
            id: "same-id",
            title: "Song 1",
            artist: "Artist 1",
            streamURL: "https://example.com/1.mp3",
            artworkURL: "https://example.com/1.jpg",
            duration: 150.0
        )
        let songB = Song(
            id: "different-id",
            title: "Song 2",
            artist: "Artist 2",
            streamURL: "https://example.com/2.mp3",
            artworkURL: "https://example.com/2.jpg",
            duration: 180.0
        )

        XCTAssertEqual(songA1, songA2)
        XCTAssertNotEqual(songA1, songB)

        let set: Set<Song> = [songA1, songA2, songB]
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(songA1))
        XCTAssertTrue(set.contains(songB))
    }

    // MARK: - Codable & JSON Decoding Tests

    func testSongCodableRoundtrip() throws {
        let original = Song(
            id: "codable-roundtrip-test",
            title: "Starlight Drift",
            artist: "Aura Void",
            streamURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
            artworkURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f",
            duration: 302.0
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let encodedData = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Song.self, from: encodedData)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.artist, original.artist)
        XCTAssertEqual(decoded.streamURL, original.streamURL)
        XCTAssertEqual(decoded.artworkURL, original.artworkURL)
        XCTAssertEqual(decoded.duration, original.duration)
    }

    func testSongJSONDecodingFromMockPayload() throws {
        let mockJSON = """
        {
            "id": "mock-song-42",
            "title": "Quantum Waves",
            "artist": "Cosmic Drift",
            "streamURL": "https://example.com/stream/track42.mp3",
            "artworkURL": "https://example.com/art/track42.jpg",
            "duration": 245.5
        }
        """

        guard let data = mockJSON.data(using: .utf8) else {
            XCTFail("Failed to convert mock JSON to Data")
            return
        }

        let decoder = JSONDecoder()
        let song = try decoder.decode(Song.self, from: data)

        XCTAssertEqual(song.id, "mock-song-42")
        XCTAssertEqual(song.title, "Quantum Waves")
        XCTAssertEqual(song.artist, "Cosmic Drift")
        XCTAssertEqual(song.streamURL, "https://example.com/stream/track42.mp3")
        XCTAssertEqual(song.artworkURL, "https://example.com/art/track42.jpg")
        XCTAssertEqual(song.duration, 245.5)
    }

    func testSongJSONDecodingArray() throws {
        let mockArrayJSON = """
        [
            {
                "id": "track-1",
                "title": "Neon Horizon",
                "artist": "Hyperion Synth",
                "streamURL": "https://example.com/1.mp3",
                "artworkURL": "https://example.com/1.jpg",
                "duration": 389.0
            },
            {
                "id": "track-2",
                "title": "Solar Flare",
                "artist": "Astral Vibes",
                "streamURL": "https://example.com/2.mp3",
                "artworkURL": "https://example.com/2.jpg",
                "duration": 325.0
            }
        ]
        """

        guard let data = mockArrayJSON.data(using: .utf8) else {
            XCTFail("Failed to convert mock array JSON to Data")
            return
        }

        let decoder = JSONDecoder()
        let songs = try decoder.decode([Song].self, from: data)

        XCTAssertEqual(songs.count, 2)
        XCTAssertEqual(songs[0].id, "track-1")
        XCTAssertEqual(songs[0].title, "Neon Horizon")
        XCTAssertEqual(songs[1].id, "track-2")
        XCTAssertEqual(songs[1].title, "Solar Flare")
    }

    func testSongJSONDecodingInvalidPayloadThrows() {
        let invalidJSON = """
        {
            "id": "broken-song",
            "title": "Missing Fields"
        }
        """

        let data = invalidJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(Song.self, from: data)) { error in
            guard case DecodingError.keyNotFound = error else {
                XCTFail("Expected DecodingError.keyNotFound but got \(error)")
                return
            }
        }
    }

    func testSongJSONDecodingTypeMismatchThrows() {
        let mismatchedJSON = """
        {
            "id": "mismatched-song",
            "title": "Invalid Duration Type",
            "artist": "Error Artist",
            "streamURL": "https://example.com/stream.mp3",
            "artworkURL": "https://example.com/art.jpg",
            "duration": "not_a_double"
        }
        """

        let data = mismatchedJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(Song.self, from: data)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected DecodingError.typeMismatch but got \(error)")
                return
            }
        }
    }

    // MARK: - MusicAPI & NetworkManager Tests

    func testMusicAPISharedInstanceAndAlias() {
        let apiShared = MusicAPI.shared
        let netShared = NetworkManager.shared
        XCTAssertTrue(apiShared === netShared, "MusicAPI must be typealias of NetworkManager and shared instances must be identical")

        let customManager = NetworkManager(session: .shared, endpointURL: nil)
        XCTAssertNotNil(customManager.session)
        XCTAssertNil(customManager.endpointURL)
    }

    func testMusicAPISampleTrendingSongsContract() {
        let samples = MusicAPI.sampleTrendingSongs
        XCTAssertGreaterThanOrEqual(samples.count, 6, "Expected at least 6 curated trending songs")

        for (index, song) in samples.enumerated() {
            XCTAssertFalse(song.id.isEmpty, "Sample song at index \(index) id must not be empty")
            XCTAssertFalse(song.title.isEmpty, "Sample song at index \(index) title must not be empty")
            XCTAssertFalse(song.artist.isEmpty, "Sample song at index \(index) artist must not be empty")
            XCTAssertTrue(song.streamURL.hasPrefix("https://"), "Sample song at index \(index) streamURL must start with https://")
            XCTAssertTrue(song.artworkURL.hasPrefix("https://"), "Sample song at index \(index) artworkURL must start with https://")
            XCTAssertGreaterThan(song.duration, 0.0, "Sample song at index \(index) duration must be positive")
            XCTAssertNotNil(song.url, "Sample song at index \(index) url must parse as valid URL")
            XCTAssertNotNil(song.artwork, "Sample song at index \(index) artwork must parse as valid URL")
        }
    }

    func testMusicAPIFetchTrendingSongsAsync() {
        let expectation = self.expectation(description: "Fetch trending songs via MusicAPI")
        Task {
            do {
                let songs = try await MusicAPI.fetchTrendingSongs()
                XCTAssertGreaterThanOrEqual(songs.count, 6)
                XCTAssertEqual(songs[0].id, "song-1")
                XCTAssertEqual(songs[0].title, "Midnight Echoes")
                expectation.fulfill()
            } catch {
                XCTFail("fetchTrendingSongs() threw unexpected error: \(error)")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5.0)
    }

    func testMusicAPISharedInstanceFetchTrendingSongsAsync() {
        let expectation = self.expectation(description: "Fetch trending songs via MusicAPI.shared")
        Task {
            do {
                let songs = try await MusicAPI.shared.fetchTrendingSongs()
                XCTAssertFalse(songs.isEmpty)
                XCTAssertEqual(songs.count, MusicAPI.sampleTrendingSongs.count)
                expectation.fulfill()
            } catch {
                XCTFail("MusicAPI.shared.fetchTrendingSongs() threw unexpected error: \(error)")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5.0)
    }

    func testMusicAPIFallbackOnInvalidEndpoint() {
        let expectation = self.expectation(description: "Fallback on invalid endpoint")
        let brokenURL = URL(string: "http://127.0.0.1:54321/nonexistent/songs.json")!
        let manager = NetworkManager(session: .shared, endpointURL: brokenURL)

        Task {
            do {
                let songs = try await manager.fetchTrendingSongs()
                XCTAssertFalse(songs.isEmpty, "Manager should fall back to sampleTrendingSongs on error")
                XCTAssertEqual(songs.count, NetworkManager.sampleTrendingSongs.count)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Linux Test Discovery & Runner

extension SoundifyTests {
    public static var allTests = [
        ("testSongInitialization", testSongInitialization),
        ("testSongDefaultIDGeneration", testSongDefaultIDGeneration),
        ("testSongURLConvenienceProperties", testSongURLConvenienceProperties),
        ("testSongIdentifiableContract", testSongIdentifiableContract),
        ("testSongHashableContract", testSongHashableContract),
        ("testSongCodableRoundtrip", testSongCodableRoundtrip),
        ("testSongJSONDecodingFromMockPayload", testSongJSONDecodingFromMockPayload),
        ("testSongJSONDecodingArray", testSongJSONDecodingArray),
        ("testSongJSONDecodingInvalidPayloadThrows", testSongJSONDecodingInvalidPayloadThrows),
        ("testSongJSONDecodingTypeMismatchThrows", testSongJSONDecodingTypeMismatchThrows),
        ("testMusicAPISharedInstanceAndAlias", testMusicAPISharedInstanceAndAlias),
        ("testMusicAPISampleTrendingSongsContract", testMusicAPISampleTrendingSongsContract),
        ("testMusicAPIFetchTrendingSongsAsync", testMusicAPIFetchTrendingSongsAsync),
        ("testMusicAPISharedInstanceFetchTrendingSongsAsync", testMusicAPISharedInstanceFetchTrendingSongsAsync),
        ("testMusicAPIFallbackOnInvalidEndpoint", testMusicAPIFallbackOnInvalidEndpoint),
    ]
}

#if os(Linux)
@main
public struct SoundifyTestRunner {
    public static func main() {
        XCTMain([testCase(SoundifyTests.allTests)])
    }
}
#endif
