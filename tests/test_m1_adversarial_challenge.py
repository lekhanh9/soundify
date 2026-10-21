"""
test_m1_adversarial_challenge.py - Empirical Adversarial Challenge Suite for Milestone 1.

Targets:
- Soundify/Models/Song.swift
- Soundify/Services/MusicAPI.swift

Validates:
1. Concurrency: High burst tasks, mutable endpointURL thread-safety, cancellation semantics, actor isolation.
2. Schema Variations: Field omission rejection, type mismatch detection, null handling, extra keys resilience, extreme values, unicode/emoji integrity.
3. Network Failure Injection: HTTP status codes (401, 403, 404, 500, 503), 204 No Content, 302 Redirects, truncated JSON, dead ports.
4. Scale & Live Assets: 10,000 song memory/throughput stress, live remote streaming MP3 byte-range validation, remote artwork validation.
"""

import json
import http.server
import threading
import urllib.request
import ssl
from pathlib import Path
import pytest
from conftest import (
    MODELS_DIR,
    SERVICES_DIR,
    run_swift_code,
)


@pytest.mark.m1
class TestM1AdversarialChallenge:

    @pytest.fixture(autouse=True)
    def setup_sources(self):
        song_file = MODELS_DIR / "Song.swift"
        api_file = SERVICES_DIR / "MusicAPI.swift"
        assert song_file.exists(), f"Missing {song_file}"
        assert api_file.exists(), f"Missing {api_file}"
        with open(song_file, "r") as f:
            self.song_code = f.read()
        with open(api_file, "r") as f:
            self.api_code = f.read()

    # =========================================================================
    # 1. Concurrency Challenges
    # =========================================================================

    def test_concurrency_burst_100_tasks(self):
        """Stress-test 100 concurrent tasks calling MusicAPI.fetchTrendingSongs()."""
        swift_test = f"""
{self.song_code}
{self.api_code}

Task {{
    await withTaskGroup(of: [Song]?.self) {{ group in
        for i in 0..<100 {{
            group.addTask {{
                do {{
                    return try await MusicAPI.fetchTrendingSongs()
                }} catch {{
                    return nil
                }}
            }}
        }}

        var successCount = 0
        for await result in group {{
            if let songs = result, songs.count == 6 {{
                successCount += 1
            }}
        }}

        assert(successCount == 100, "Expected 100 successful tasks, got \\(successCount)")
        print("CONCURRENCY_BURST_PASSED")
        exit(0)
    }}
}}

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
exit(1)
"""
        res = run_swift_code(swift_test, timeout=20)
        assert res.returncode == 0, f"Concurrency burst failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "CONCURRENCY_BURST_PASSED" in res.stdout

    def test_concurrency_endpoint_mutation_under_load(self):
        """Stress-test concurrent reads and writes to NetworkManager.endpointURL."""
        swift_test = f"""
{self.song_code}
{self.api_code}

let manager = NetworkManager()
let dummyURL = URL(string: "https://example.com/api/songs")!

Task {{
    await withTaskGroup(of: Void.self) {{ group in
        // Writer task mutating endpointURL rapidly
        group.addTask {{
            for i in 0..<500 {{
                manager.endpointURL = (i % 2 == 0) ? dummyURL : nil
            }}
        }}

        // Multiple reader / fetcher tasks running concurrently
        for _ in 0..<20 {{
            group.addTask {{
                for _ in 0..<25 {{
                    _ = try? await manager.fetchTrendingSongs()
                }}
            }}
        }}
    }}
    print("CONCURRENT_MUTATION_SAFE")
    exit(0)
}}

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
exit(1)
"""
        res = run_swift_code(swift_test, timeout=10)
        assert res.returncode == 0, f"Concurrent mutation test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "CONCURRENT_MUTATION_SAFE" in res.stdout

    def test_cancellation_semantics(self):
        """Verify Task cancellation behavior on fetch(from:) and fetchTrendingSongs()."""
        swift_test = f"""
{self.song_code}
{self.api_code}

Task {{
    let manager = NetworkManager()
    let slowURL = URL(string: "https://httpbin.org/delay/5")!

    // 1. Direct fetch on cancelled task must fail with URLError.cancelled
    let child = Task {{ () -> [Song] in
        return try await manager.fetch(from: slowURL)
    }}
    child.cancel()

    let result = await child.result
    switch result {{
    case .success:
        print("ERROR: Cancelled direct fetch unexpectedly succeeded")
        exit(1)
    case .failure(let err as URLError):
        assert(err.code == .cancelled, "Expected URLError.cancelled, got \\(err.code)")
    case .failure:
        // Acceptable cancellation error
        break
    }}

    // 2. fetchTrendingSongs on cancelled task provides non-crashing fallback
    let fallbackMgr = NetworkManager(endpointURL: slowURL)
    let fallbackChild = Task {{ () -> [Song] in
        return try await fallbackMgr.fetchTrendingSongs()
    }}
    fallbackChild.cancel()

    let fallbackRes = await fallbackChild.result
    switch fallbackRes {{
    case .success(let songs):
        assert(songs.count == 6, "Expected 6 fallback songs on cancelled fetch")
    case .failure:
        // Acceptable if error was propagated
        break
    }}

    print("CANCELLATION_SEMANTICS_PASSED")
    exit(0)
}}

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
exit(2)
"""
        res = run_swift_code(swift_test, timeout=10)
        assert res.returncode == 0, f"Cancellation test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "CANCELLATION_SEMANTICS_PASSED" in res.stdout

    def test_actor_isolation_and_sendable_conformance(self):
        """Verify Song can cross Actor boundaries and be stored safely."""
        swift_test = f"""
{self.song_code}
{self.api_code}

actor SongStore {{
    private var songs: [Song] = []

    func add(song: Song) {{
        songs.append(song)
    }}

    func getAll() -> [Song] {{
        return songs
    }}

    func totalDuration() -> Double {{
        return songs.reduce(0.0) {{ $0 + $1.duration }}
    }}
}}

Task {{
    let store = SongStore()
    let songs = try await MusicAPI.fetchTrendingSongs()
    for s in songs {{
        await store.add(song: s)
    }}

    let storedCount = await store.getAll().count
    assert(storedCount == 6)
    let dur = await store.totalDuration()
    assert(dur > 0.0)

    print("ACTOR_ISOLATION_PASSED")
    exit(0)
}}

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
exit(1)
"""
        res = run_swift_code(swift_test, timeout=10)
        assert res.returncode == 0, f"Actor isolation test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "ACTOR_ISOLATION_PASSED" in res.stdout

    # =========================================================================
    # 2. Schema Variations & Decoding Challenges
    # =========================================================================

    def test_schema_missing_fields_rejection(self):
        """Verify omission of any required Song field raises DecodingError.keyNotFound."""
        swift_test = f"""
{self.song_code}

let decoder = JSONDecoder()

let requiredKeys = ["id", "title", "artist", "streamURL", "artworkURL", "duration"]

for omittedKey in requiredKeys {{
    var dict: [String: Any] = [
        "id": "s-1",
        "title": "Title",
        "artist": "Artist",
        "streamURL": "https://example.com/stream.mp3",
        "artworkURL": "https://example.com/art.jpg",
        "duration": 200.0
    ]
    dict.removeValue(forKey: omittedKey)
    let data = try JSONSerialization.data(withJSONObject: dict)

    do {{
        _ = try decoder.decode(Song.self, from: data)
        print("ERROR: Omission of \\(omittedKey) did not throw keyNotFound")
        exit(1)
    }} catch DecodingError.keyNotFound(let key, _) {{
        assert(key.stringValue == omittedKey)
    }} catch {{
        print("ERROR: Unexpected error for \\(omittedKey): \\(error)")
        exit(2)
    }}
}}

print("MISSING_FIELDS_REJECTION_PASSED")
"""
        res = run_swift_code(swift_test)
        assert res.returncode == 0, f"Missing fields test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "MISSING_FIELDS_REJECTION_PASSED" in res.stdout

    def test_schema_type_mismatches_and_nulls(self):
        """Verify invalid property types and null values raise appropriate DecodingErrors."""
        swift_test = f"""
{self.song_code}

let decoder = JSONDecoder()

// 1. Duration as string must fail typeMismatch
let strDurData = \"\"\"
{{"id":"1","title":"T","artist":"A","streamURL":"S","artworkURL":"Art","duration":"300.0"}}
\"\"\".data(using: .utf8)!
do {{
    _ = try decoder.decode(Song.self, from: strDurData)
    print("ERROR: String duration did not throw")
    exit(1)
}} catch DecodingError.typeMismatch {{
    // Expected
}}

// 2. Title as integer must fail typeMismatch
let intTitleData = \"\"\"
{{"id":"1","title":12345,"artist":"A","streamURL":"S","artworkURL":"Art","duration":300.0}}
\"\"\".data(using: .utf8)!
do {{
    _ = try decoder.decode(Song.self, from: intTitleData)
    print("ERROR: Integer title did not throw")
    exit(2)
}} catch DecodingError.typeMismatch {{
    // Expected
}}

// 3. Null field must fail valueNotFound
let nullArtData = \"\"\"
{{"id":"1","title":"T","artist":"A","streamURL":"S","artworkURL":null,"duration":300.0}}
\"\"\".data(using: .utf8)!
do {{
    _ = try decoder.decode(Song.self, from: nullArtData)
    print("ERROR: Null artworkURL did not throw")
    exit(3)
}} catch DecodingError.valueNotFound {{
    // Expected
}}

print("TYPE_MISMATCH_AND_NULLS_PASSED")
"""
        res = run_swift_code(swift_test)
        assert res.returncode == 0, f"Type mismatch test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "TYPE_MISMATCH_AND_NULLS_PASSED" in res.stdout

    def test_schema_resilience_extra_fields_and_integer_coercion(self):
        """Verify extra unexpected fields are ignored and integer duration coerces to Double."""
        swift_test = f"""
{self.song_code}

let decoder = JSONDecoder()

let payload = \"\"\"
{{
    "id": "custom-1",
    "title": "Coerced Song",
    "artist": "Producer",
    "streamURL": "https://example.com/s.mp3",
    "artworkURL": "https://example.com/a.jpg",
    "duration": 360,
    "album": "Extra Field",
    "bitrate": 320,
    "featured_artists": ["A", "B"]
}}
\"\"\".data(using: .utf8)!

let song = try decoder.decode(Song.self, from: payload)
assert(song.id == "custom-1")
assert(song.duration == 360.0)
assert(song.title == "Coerced Song")

print("EXTRA_FIELDS_AND_COERCION_PASSED")
"""
        res = run_swift_code(swift_test)
        assert res.returncode == 0, f"Extra fields test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "EXTRA_FIELDS_AND_COERCION_PASSED" in res.stdout

    def test_schema_extreme_values_and_unicode(self):
        """Verify handling of extreme durations, 10,000-char strings, emojis, and special chars."""
        swift_test = f"""
{self.song_code}

let encoder = JSONEncoder()
let decoder = JSONDecoder()

// 1. Unicode, emojis, RTL, and HTML entities
let complexSong = Song(
    id: "uuid-🌟-01",
    title: "夜明けのメロディー 🎶 & <script>alert('xss')</script>",
    artist: "موسيقى هادئة / 歌手",
    streamURL: "https://example.com/stream?query=hello%20world&id=1#fragment",
    artworkURL: "https://example.com/artwork?w=1000&fmt=webp",
    duration: 315.75
)

let data = try encoder.encode(complexSong)
let roundtrip = try decoder.decode(Song.self, from: data)
assert(roundtrip == complexSong)
assert(roundtrip.title == complexSong.title)
assert(roundtrip.artist == complexSong.artist)

// 2. Zero and negative durations
let zeroSong = Song(id: "z", title: "Z", artist: "A", streamURL: "U", artworkURL: "Art", duration: 0.0)
let negSong = Song(id: "n", title: "N", artist: "A", streamURL: "U", artworkURL: "Art", duration: -45.0)
let zeroDec = try decoder.decode(Song.self, from: try encoder.encode(zeroSong))
let negDec = try decoder.decode(Song.self, from: try encoder.encode(negSong))
assert(zeroDec.duration == 0.0)
assert(negDec.duration == -45.0)

// 3. Huge strings (10,000 chars)
let hugeTitle = String(repeating: "A", count: 10_000)
let hugeSong = Song(id: "h", title: hugeTitle, artist: "Huge", streamURL: "U", artworkURL: "Art", duration: 100.0)
let hugeDec = try decoder.decode(Song.self, from: try encoder.encode(hugeSong))
assert(hugeDec.title.count == 10_000)

print("EXTREME_VALUES_AND_UNICODE_PASSED")
"""
        res = run_swift_code(swift_test)
        assert res.returncode == 0, f"Extreme values test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "EXTREME_VALUES_AND_UNICODE_PASSED" in res.stdout

    def test_hashable_and_equatable_strict_invariants(self):
        """Verify strict reflexivity, symmetry, transitivity, and hash collision resistance."""
        swift_test = f"""
{self.song_code}

let s1 = Song(id: "1", title: "Song A", artist: "Artist", streamURL: "url", artworkURL: "art", duration: 100.0)
let s2 = Song(id: "1", title: "Song A", artist: "Artist", streamURL: "url", artworkURL: "art", duration: 100.0)
let s3 = Song(id: "1", title: "Song A", artist: "Artist", streamURL: "url", artworkURL: "art", duration: 100.0)

// Reflexivity
assert(s1 == s1)

// Symmetry
assert((s1 == s2) == (s2 == s1))

// Transitivity
assert(s1 == s2 && s2 == s3 && s1 == s3)

// Hash equality
assert(s1.hashValue == s2.hashValue)

// Inequality on any single property
let diffTitle = Song(id: "1", title: "Song B", artist: "Artist", streamURL: "url", artworkURL: "art", duration: 100.0)
let diffArtist = Song(id: "1", title: "Song A", artist: "Other", streamURL: "url", artworkURL: "art", duration: 100.0)
let diffDuration = Song(id: "1", title: "Song A", artist: "Artist", streamURL: "url", artworkURL: "art", duration: 100.000001)

assert(s1 != diffTitle)
assert(s1 != diffArtist)
assert(s1 != diffDuration)

var set: Set<Song> = [s1, s2, s3, diffTitle, diffArtist, diffDuration]
assert(set.count == 4, "Expected 4 distinct elements in Set, got \\(set.count)")

print("HASHABLE_EQUATABLE_STRICT_PASSED")
"""
        res = run_swift_code(swift_test)
        assert res.returncode == 0, f"Hashable invariants test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "HASHABLE_EQUATABLE_STRICT_PASSED" in res.stdout

    # =========================================================================
    # 3. Network Failure Injection & HTTP Status Variations
    # =========================================================================

    def test_network_http_status_codes_and_redirection(self):
        """Comprehensive HTTP failure injection: 200, 204, 302, 401, 403, 404, 500, 503, truncated, dead port."""
        class MockHandler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/200_valid":
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    data = [
                        {"id": f"s-{i}", "title": f"Song {i}", "artist": "Art", "streamURL": "https://example.com/s.mp3", "artworkURL": "https://example.com/a.jpg", "duration": 150.0}
                        for i in range(5)
                    ]
                    self.wfile.write(json.dumps(data).encode())
                elif self.path == "/200_empty_array":
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(b"[]")
                elif self.path == "/200_single_object":
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps({"id": "s-1", "title": "Single", "artist": "Art", "streamURL": "https://example.com/s.mp3", "artworkURL": "https://example.com/a.jpg", "duration": 150.0}).encode())
                elif self.path == "/200_truncated":
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(b'[{"id": "s-1", "title": "Cut off...')
                elif self.path == "/204_no_content":
                    self.send_response(204)
                    self.end_headers()
                elif self.path == "/302_redirect":
                    self.send_response(302)
                    self.send_header("Location", "/200_valid")
                    self.end_headers()
                elif self.path == "/401_unauthorized":
                    self.send_response(401)
                    self.end_headers()
                elif self.path == "/403_forbidden":
                    self.send_response(403)
                    self.end_headers()
                elif self.path == "/404_not_found":
                    self.send_response(404)
                    self.end_headers()
                elif self.path == "/500_server_error":
                    self.send_response(500)
                    self.end_headers()
                elif self.path == "/503_unavailable":
                    self.send_response(503)
                    self.end_headers()
                else:
                    self.send_response(404)
                    self.end_headers()

            def log_message(self, format, *args):
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), MockHandler)
        port = server.server_address[1]
        t = threading.Thread(target=server.serve_forever, daemon=True)
        t.start()

        swift_test = f"""
{self.song_code}
{self.api_code}

Task {{
    let manager = NetworkManager()
    let base = "http://127.0.0.1:{port}"

    // 1. 200 valid returns decoded array of 5 songs
    let validURL = URL(string: "\\(base)/200_valid")!
    let songs: [Song] = try await manager.fetch(from: validURL)
    assert(songs.count == 5)

    // 2. 200 empty array returns empty array
    let emptyURL = URL(string: "\\(base)/200_empty_array")!
    let emptySongs: [Song] = try await manager.fetch(from: emptyURL)
    assert(emptySongs.isEmpty)

    // 3. 200 single object schema mismatch falls back to 6 sample tracks in fetchTrendingSongs
    let singleMgr = NetworkManager(endpointURL: URL(string: "\\(base)/200_single_object")!)
    let fallbackSingle = try await singleMgr.fetchTrendingSongs()
    assert(fallbackSingle.count == 6)

    // 4. 200 truncated JSON falls back to 6 sample tracks
    let truncMgr = NetworkManager(endpointURL: URL(string: "\\(base)/200_truncated")!)
    let fallbackTrunc = try await truncMgr.fetchTrendingSongs()
    assert(fallbackTrunc.count == 6)

    // 5. 204 No Content falls back to 6 sample tracks
    let noContentMgr = NetworkManager(endpointURL: URL(string: "\\(base)/204_no_content")!)
    let fallbackNoContent = try await noContentMgr.fetchTrendingSongs()
    assert(fallbackNoContent.count == 6)

    // 6. 302 Redirect successfully followed to 200_valid
    let redirURL = URL(string: "\\(base)/302_redirect")!
    let redirSongs: [Song] = try await manager.fetch(from: redirURL)
    assert(redirSongs.count == 5)

    // 7. Error status codes (401, 403, 404, 500, 503) all throw URLError(.badServerResponse)
    let errorPaths = ["/401_unauthorized", "/403_forbidden", "/404_not_found", "/500_server_error", "/503_unavailable"]
    for path in errorPaths {{
        let errURL = URL(string: "\\(base)\\(path)")!
        do {{
            let _: [Song] = try await manager.fetch(from: errURL)
            print("ERROR on \\(path): Did not throw")
            exit(1)
        }} catch let urlError as URLError {{
            assert(urlError.code == .badServerResponse)
        }} catch {{
            print("ERROR on \\(path): Threw unexpected: \\(error)")
            exit(2)
        }}
    }}

    // 8. Dead port connection failure falls back safely to 6 sample tracks
    let deadMgr = NetworkManager(endpointURL: URL(string: "http://127.0.0.1:59998/dead")!)
    let fallbackDead = try await deadMgr.fetchTrendingSongs()
    assert(fallbackDead.count == 6)

    print("NETWORK_HTTP_STATUS_TESTS_PASSED")
    exit(0)
}}

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
exit(3)
"""
        try:
            res = run_swift_code(swift_test, timeout=10)
            assert res.returncode == 0, f"Network status tests failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
            assert "NETWORK_HTTP_STATUS_TESTS_PASSED" in res.stdout
        finally:
            server.shutdown()
            server.server_close()

    # =========================================================================
    # 4. Large-Scale Stress & Live Remote Assets
    # =========================================================================

    def test_large_scale_catalog_stress(self):
        """Encode and decode 10,000 Song objects, asserting performance and data integrity."""
        swift_test = f"""
{self.song_code}

var catalog: [Song] = []
catalog.reserveCapacity(10000)

for i in 0..<10000 {{
    catalog.append(
        Song(
            id: "stress-\\(i)",
            title: "Track Title Number \\(i)",
            artist: "Artist \\(i % 50)",
            streamURL: "https://stream.example.com/audio/\\(i).mp3",
            artworkURL: "https://art.example.com/cover/\\(i).jpg",
            duration: Double(120 + (i % 300))
        )
    )
}}

let encoder = JSONEncoder()
let data = try encoder.encode(catalog)

let decoder = JSONDecoder()
let decoded = try decoder.decode([Song].self, from: data)

assert(decoded.count == 10000)
assert(decoded[5000].id == "stress-5000")
assert(decoded[5000].title == "Track Title Number 5000")

print("LARGE_SCALE_CATALOG_STRESS_PASSED")
"""
        res = run_swift_code(swift_test, timeout=15)
        assert res.returncode == 0, f"Scale stress test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "LARGE_SCALE_CATALOG_STRESS_PASSED" in res.stdout

    def test_live_remote_audio_and_artwork_assets(self):
        """Empirically query live SoundHelix MP3s and Unsplash artwork from sampleTrendingSongs."""
        ctx = ssl.create_default_context()
        headers = {"User-Agent": "Soundify-Challenge/1.0"}

        songs = [
            ("song-1", "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3", "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60"),
            ("song-2", "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3", "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60"),
            ("song-3", "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3", "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60"),
            ("song-4", "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3", "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=60"),
            ("song-5", "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3", "https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=60"),
            ("song-6", "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3", "https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=500&auto=format&fit=crop&q=60"),
        ]

        for sid, stream_url, art_url in songs:
            # Check byte range support on remote MP3
            req = urllib.request.Request(stream_url, headers={**headers, "Range": "bytes=0-1024"})
            with urllib.request.urlopen(req, timeout=10, context=ctx) as resp:
                assert resp.getcode() in (200, 206), f"[{sid}] Expected 200/206 for stream URL, got {resp.getcode()}"
                ctype = resp.headers.get("Content-Type", "")
                assert "audio" in ctype or "mpeg" in ctype or "octet-stream" in ctype, f"[{sid}] Invalid audio content type: {ctype}"
                data = resp.read()
                assert len(data) > 0, f"[{sid}] Stream returned 0 bytes"

            # Check image response on remote artwork
            req_art = urllib.request.Request(art_url, headers=headers)
            with urllib.request.urlopen(req_art, timeout=10, context=ctx) as resp:
                assert resp.getcode() == 200, f"[{sid}] Expected 200 for artwork URL, got {resp.getcode()}"
                ctype = resp.headers.get("Content-Type", "")
                assert "image" in ctype, f"[{sid}] Expected image content type, got {ctype}"
