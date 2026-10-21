"""
test_tier2_m1_adversarial.py - Tier 2 Adversarial Stress & Edge Case Test Suite for M1.
Covers:
1. TestTier2SongAdversarial: Boundary values, URL parsing, Unicode/special chars,
   JSON decoding corruptions, missing keys, type mismatches, and Hashable consistency.
2. TestTier2MusicAPIAdversarial: Configurable endpoints, fallback mechanics on 404/500/malformed JSON,
   direct generic fetch<T> contract verification, and high concurrency thread safety.
3. TestTier2RangeRequestValidation: Remote streaming CDN byte range tests (initial chunk, middle chunk,
   first byte, last byte, out of bounds 416), media type headers, and magic byte validations.
"""

import http.server
import json
import socketserver
import subprocess
import threading
import urllib.error
import urllib.request
from pathlib import Path
import pytest

from conftest import (
    MODELS_DIR,
    SERVICES_DIR,
    run_swift_code,
)


@pytest.mark.tier2
@pytest.mark.m1
class TestTier2SongAdversarial:
    """Stress tests and boundary condition validation for Song.swift."""

    def test_song_empty_and_boundary_strings(self):
        """Verify handling of empty strings, zero duration, and default UUID generation."""
        song_file = MODELS_DIR / "Song.swift"
        with open(song_file, "r") as f:
            code = f.read()

        swift_code = f"""
{code}

// Test default initializer UUID assignment
let songDefault = Song(title: "Default", artist: "Artist", streamURL: "https://example.com/stream.mp3", artworkURL: "https://example.com/art.jpg", duration: 120.0)
assert(!songDefault.id.isEmpty, "Default id must not be empty")
assert(UUID(uuidString: songDefault.id) != nil, "Default id should be a valid UUID string")

// Test empty fields
let emptySong = Song(id: "", title: "", artist: "", streamURL: "", artworkURL: "", duration: 0.0)
assert(emptySong.id == "")
assert(emptySong.title == "")
assert(emptySong.url == nil, "Empty streamURL string must produce nil URL")
assert(emptySong.artwork == nil, "Empty artworkURL string must produce nil artwork URL")

// Test extreme duration values
let longSong = Song(title: "Symphony", artist: "Orchestra", streamURL: "https://example.com", artworkURL: "https://example.com", duration: 86400.0 * 365.0)
assert(longSong.duration == 86400.0 * 365.0)

print("SONG_BOUNDARY_STRINGS_PASSED")
"""
        res = run_swift_code(swift_code)
        assert res.returncode == 0, f"Boundary test failed:\n{res.stderr}"
        assert "SONG_BOUNDARY_STRINGS_PASSED" in res.stdout

    def test_song_complex_url_parsing(self):
        """Verify URL property handles query parameters, fragments, and ports correctly."""
        song_file = MODELS_DIR / "Song.swift"
        with open(song_file, "r") as f:
            code = f.read()

        swift_code = f"""
{code}

let complex = Song(
    id: "s-complex",
    title: "Complex URL Track",
    artist: "Audio Lab",
    streamURL: "https://streaming.cdn.net:8443/hls/master.mp3?token=secret123&bitrate=320#segment-001",
    artworkURL: "https://images.cdn.net/art.jpg?width=600&height=600&format=webp",
    duration: 300.0
)

guard let streamURL = complex.url else {{
    fatalError("Failed to parse valid complex streamURL")
}}
assert(streamURL.scheme == "https")
assert(streamURL.port == 8443)
assert(streamURL.query == "token=secret123&bitrate=320")
assert(streamURL.fragment == "segment-001")

guard let artworkURL = complex.artwork else {{
    fatalError("Failed to parse valid complex artworkURL")
}}
assert(artworkURL.query?.contains("format=webp") == true)

print("URL_PARSING_PASSED")
"""
        res = run_swift_code(swift_code)
        assert res.returncode == 0, f"Complex URL parsing failed:\n{res.stderr}"
        assert "URL_PARSING_PASSED" in res.stdout

    def test_song_multilingual_unicode_and_emojis(self):
        """Stress-test Unicode, RTL scripts, CJK characters, and emojis in metadata."""
        song_file = MODELS_DIR / "Song.swift"
        with open(song_file, "r") as f:
            code = f.read()

        swift_code = f"""
{code}

let testCases: [(String, String)] = [
    ("夜に駆ける 🏃💨", "YOASOBI / 幾田りら"),
    ("موسيقى الاسترخاء 🌙", "فنان مجهول"),
    ("Песня о буревестнике ⚡", "Максим Горький"),
    ("Über den Wolken ✈️", "Reinhard Mey"),
    ("🎶 SpecialChars: !@#$%^&*()_+~`|:;?><,./", "Escape \\t \\n \\r \\" ' \\\\")
]

for (idx, (title, artist)) in testCases.enumerated() {{
    let song = Song(
        id: "unicode-\\(idx)",
        title: title,
        artist: artist,
        streamURL: "https://example.com/audio\\(idx).mp3",
        artworkURL: "https://example.com/art\\(idx).jpg",
        duration: Double(100 + idx)
    )

    let encoded = try JSONEncoder().encode(song)
    let decoded = try JSONDecoder().decode(Song.self, from: encoded)

    assert(decoded == song, "Decoded song must match original for case \\(idx)")
    assert(decoded.title == title, "Title mismatch in Unicode decoding")
    assert(decoded.artist == artist, "Artist mismatch in Unicode decoding")
}}

print("UNICODE_STRESS_PASSED")
"""
        res = run_swift_code(swift_code)
        assert res.returncode == 0, f"Unicode stress test failed:\n{res.stderr}"
        assert "UNICODE_STRESS_PASSED" in res.stdout

    def test_song_json_decoding_adversarial_payloads(self):
        """Adversarially probe JSONDecoder error paths: missing keys, null values, type mismatches."""
        song_file = MODELS_DIR / "Song.swift"
        with open(song_file, "r") as f:
            code = f.read()

        swift_code = f"""
{code}

let decoder = JSONDecoder()

// 1. Missing required 'id' key
let noId = "{{\\"title\\":\\"T\\",\\"artist\\":\\"A\\",\\"streamURL\\":\\"http://a\\",\\"artworkURL\\":\\"http://b\\",\\"duration\\":100}}".data(using: .utf8)!
do {{
    _ = try decoder.decode(Song.self, from: noId)
    fatalError("Should fail on missing id")
}} catch DecodingError.keyNotFound(let key, _) {{
    assert(key.stringValue == "id")
}}

// 2. Missing required 'duration' key
let noDuration = "{{\\"id\\":\\"1\\",\\"title\\":\\"T\\",\\"artist\\":\\"A\\",\\"streamURL\\":\\"http://a\\",\\"artworkURL\\":\\"http://b\\"}}".data(using: .utf8)!
do {{
    _ = try decoder.decode(Song.self, from: noDuration)
    fatalError("Should fail on missing duration")
}} catch DecodingError.keyNotFound(let key, _) {{
    assert(key.stringValue == "duration")
}}

// 3. Null value in non-optional field
let nullTitle = "{{\\"id\\":\\"1\\",\\"title\\":null,\\"artist\\":\\"A\\",\\"streamURL\\":\\"http://a\\",\\"artworkURL\\":\\"http://b\\",\\"duration\\":100}}".data(using: .utf8)!
do {{
    _ = try decoder.decode(Song.self, from: nullTitle)
    fatalError("Should fail on null title")
}} catch DecodingError.valueNotFound {{
    // Expected
}}

// 4. Type mismatch: duration is string instead of numeric
let stringDuration = "{{\\"id\\":\\"1\\",\\"title\\":\\"T\\",\\"artist\\":\\"A\\",\\"streamURL\\":\\"http://a\\",\\"artworkURL\\":\\"http://b\\",\\"duration\\":\\"300\\"}}".data(using: .utf8)!
do {{
    _ = try decoder.decode(Song.self, from: stringDuration)
    fatalError("Should fail on string duration")
}} catch DecodingError.typeMismatch {{
    // Expected
}}

// 5. Extraneous keys should be gracefully ignored
let extraKeys = \"\"\"
{{
    "id": "100",
    "title": "Extended Track",
    "artist": "Producer",
    "streamURL": "https://example.com/s.mp3",
    "artworkURL": "https://example.com/a.jpg",
    "duration": 250.0,
    "unrecognized_field_1": "discarded",
    "unrecognized_field_2": [1, 2, 3],
    "nested": {{"nested_key": true}}
}}
\"\"\".data(using: .utf8)!

let decodedExtra = try decoder.decode(Song.self, from: extraKeys)
assert(decodedExtra.id == "100")
assert(decodedExtra.duration == 250.0)

print("JSON_ADVERSARIAL_DECODING_PASSED")
"""
        res = run_swift_code(swift_code)
        assert res.returncode == 0, f"JSON adversarial decoding test failed:\n{res.stderr}"
        assert "JSON_ADVERSARIAL_DECODING_PASSED" in res.stdout

    def test_song_hashable_and_set_semantics(self):
        """Stress-test Hashable and Equatable conformance under set deduplication and dict lookups."""
        song_file = MODELS_DIR / "Song.swift"
        with open(song_file, "r") as f:
            code = f.read()

        swift_code = f"""
{code}

let base = Song(id: "base", title: "Title", artist: "Artist", streamURL: "https://u", artworkURL: "https://a", duration: 100.0)

// Equivalence properties
assert(base == base, "Reflexive")

// Differential equality: every field should contribute to equality
let diffId = Song(id: "other", title: "Title", artist: "Artist", streamURL: "https://u", artworkURL: "https://a", duration: 100.0)
assert(base != diffId, "Different id must not be equal")

let diffTitle = Song(id: "base", title: "Other", artist: "Artist", streamURL: "https://u", artworkURL: "https://a", duration: 100.0)
assert(base != diffTitle, "Different title must not be equal")

let diffDuration = Song(id: "base", title: "Title", artist: "Artist", streamURL: "https://u", artworkURL: "https://a", duration: 101.0)
assert(base != diffDuration, "Different duration must not be equal")

// Set deduplication with 1,000 instances (500 distinct pairs duplicated)
var songSet = Set<Song>()
var dict = [Song: Int]()

for i in 0..<500 {{
    let s = Song(id: "id-\\(i)", title: "Title \\(i)", artist: "Artist", streamURL: "https://stream/\\(i)", artworkURL: "https://art/\\(i)", duration: Double(i))
    songSet.insert(s)
    songSet.insert(s) // Duplicate
    dict[s] = i
}}

assert(songSet.count == 500, "Set should contain exactly 500 unique elements")
assert(dict.count == 500, "Dict should contain exactly 500 unique elements")

for i in 0..<500 {{
    let lookup = Song(id: "id-\\(i)", title: "Title \\(i)", artist: "Artist", streamURL: "https://stream/\\(i)", artworkURL: "https://art/\\(i)", duration: Double(i))
    assert(dict[lookup] == i, "Dictionary lookup failed for index \\(i)")
}}

print("HASHABLE_STRESS_PASSED")
"""
        res = run_swift_code(swift_code)
        assert res.returncode == 0, f"Hashable stress test failed:\n{res.stderr}"
        assert "HASHABLE_STRESS_PASSED" in res.stdout


@pytest.fixture(scope="module")
def mock_server():
    """Starts a local HTTP server simulating various server states."""
    class FaultHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/api/trending":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                payload = [
                    {
                        "id": "custom-mock-1",
                        "title": "Mocked Nebula",
                        "artist": "Starlight Synthesizer",
                        "streamURL": "https://example.com/nebula.mp3",
                        "artworkURL": "https://example.com/nebula.jpg",
                        "duration": 215.0
                    }
                ]
                self.wfile.write(json.dumps(payload).encode("utf-8"))
            elif self.path == "/api/500_error":
                self.send_response(500)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"Server Failure")
            elif self.path == "/api/404_not_found":
                self.send_response(404)
                self.end_headers()
            elif self.path == "/api/corrupted_json":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b"{ truncated_invalid_json: [1, 2,")
            elif self.path == "/api/empty_array":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b"[]")
            else:
                self.send_response(400)
                self.end_headers()

        def log_message(self, format, *args):
            pass

    server = socketserver.TCPServer(("127.0.0.1", 0), FaultHandler)
    port = server.server_address[1]
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    yield port
    server.shutdown()


@pytest.mark.tier2
@pytest.mark.m1
class TestTier2MusicAPIAdversarial:
    """Stress tests and network fault-injection validation for MusicAPI.swift."""

    def test_music_api_mock_server_fault_injection(self, mock_server):
        """Test NetworkManager fallback behavior under 500, 404, malformed JSON, and successful fetch."""
        port = mock_server
        song_file = MODELS_DIR / "Song.swift"
        api_file = SERVICES_DIR / "MusicAPI.swift"

        with open(song_file, "r") as f:
            song_code = f.read()
        with open(api_file, "r") as f:
            api_code = f.read()

        swift_code = f"""
{song_code}
{api_code}

Task {{
    do {{
        // Case 1: Custom endpoint success
        let validEndpoint = URL(string: "http://127.0.0.1:{port}/api/trending")!
        let manager1 = NetworkManager(endpointURL: validEndpoint)
        let songs1 = try await manager1.fetchTrendingSongs()
        assert(songs1.count == 1, "Expected 1 custom song")
        assert(songs1[0].id == "custom-mock-1")

        // Case 2: Server 500 error triggers fallback to sample songs
        let errorEndpoint = URL(string: "http://127.0.0.1:{port}/api/500_error")!
        let manager2 = NetworkManager(endpointURL: errorEndpoint)
        let fallback500 = try await manager2.fetchTrendingSongs()
        assert(fallback500.count == 6, "Expected 6 sample songs on 500 fallback")

        // Case 3: Server 404 error triggers fallback to sample songs
        let notFoundEndpoint = URL(string: "http://127.0.0.1:{port}/api/404_not_found")!
        let manager3 = NetworkManager(endpointURL: notFoundEndpoint)
        let fallback404 = try await manager3.fetchTrendingSongs()
        assert(fallback404.count == 6, "Expected 6 sample songs on 404 fallback")

        // Case 4: Malformed JSON triggers fallback to sample songs
        let corruptEndpoint = URL(string: "http://127.0.0.1:{port}/api/corrupted_json")!
        let manager4 = NetworkManager(endpointURL: corruptEndpoint)
        let fallbackCorrupt = try await manager4.fetchTrendingSongs()
        assert(fallbackCorrupt.count == 6, "Expected 6 sample songs on corrupt JSON fallback")

        // Case 5: Empty array returns valid empty list
        let emptyEndpoint = URL(string: "http://127.0.0.1:{port}/api/empty_array")!
        let manager5 = NetworkManager(endpointURL: emptyEndpoint)
        let emptySongs = try await manager5.fetchTrendingSongs()
        assert(emptySongs.isEmpty, "Expected empty song list")

        print("FAULT_INJECTION_TESTS_PASSED")
        exit(0)
    }} catch {{
        print("Fault injection test failed: \\(error)")
        exit(1)
    }}
}}

RunLoop.main.run(until: Date().addingTimeInterval(10.0))
exit(2)
"""
        res = run_swift_code(swift_code, timeout=15)
        assert res.returncode == 0, f"Fault injection test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "FAULT_INJECTION_TESTS_PASSED" in res.stdout

    def test_music_api_direct_generic_fetch_contracts(self, mock_server):
        """Verify fetch<T> throws URLError on 500/404 and DecodingError on bad JSON."""
        port = mock_server
        song_file = MODELS_DIR / "Song.swift"
        api_file = SERVICES_DIR / "MusicAPI.swift"

        with open(song_file, "r") as f:
            song_code = f.read()
        with open(api_file, "r") as f:
            api_code = f.read()

        swift_code = f"""
{song_code}
{api_code}

Task {{
    let manager = NetworkManager()

    // 1. HTTP 500 must throw URLError
    let url500 = URL(string: "http://127.0.0.1:{port}/api/500_error")!
    do {{
        let _: [Song] = try await manager.fetch(from: url500)
        fatalError("fetch<T> should throw on 500")
    }} catch let err as URLError {{
        assert(err.code == .badServerResponse)
    }}

    // 2. HTTP 404 must throw URLError
    let url404 = URL(string: "http://127.0.0.1:{port}/api/404_not_found")!
    do {{
        let _: [Song] = try await manager.fetch(from: url404)
        fatalError("fetch<T> should throw on 404")
    }} catch let err as URLError {{
        assert(err.code == .badServerResponse)
    }}

    // 3. Corrupted JSON must throw DecodingError
    let urlCorrupt = URL(string: "http://127.0.0.1:{port}/api/corrupted_json")!
    do {{
        let _: [Song] = try await manager.fetch(from: urlCorrupt)
        fatalError("fetch<T> should throw DecodingError on bad payload")
    }} catch is DecodingError {{
        // Expected
    }}

    print("DIRECT_FETCH_CONTRACTS_PASSED")
    exit(0)
}}

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
exit(1)
"""
        res = run_swift_code(swift_code, timeout=10)
        assert res.returncode == 0, f"Direct fetch contract test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "DIRECT_FETCH_CONTRACTS_PASSED" in res.stdout

    def test_music_api_concurrency_stress(self):
        """Stress test: 50 concurrent async tasks querying fetchTrendingSongs()."""
        song_file = MODELS_DIR / "Song.swift"
        api_file = SERVICES_DIR / "MusicAPI.swift"

        with open(song_file, "r") as f:
            song_code = f.read()
        with open(api_file, "r") as f:
            api_code = f.read()

        swift_code = f"""
{song_code}
{api_code}

Task {{
    await withTaskGroup(of: Void.self) {{ group in
        for i in 0..<50 {{
            group.addTask {{
                let songs: [Song]
                if i % 2 == 0 {{
                    songs = try! await MusicAPI.fetchTrendingSongs()
                }} else {{
                    songs = try! await NetworkManager.shared.fetchTrendingSongs()
                }}
                assert(songs.count == 6)
            }}
        }}
    }}
    print("CONCURRENCY_50_TASKS_PASSED")
    exit(0)
}}

RunLoop.main.run(until: Date().addingTimeInterval(10.0))
exit(1)
"""
        res = run_swift_code(swift_code, timeout=15)
        assert res.returncode == 0, f"Concurrency stress test failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "CONCURRENCY_50_TASKS_PASSED" in res.stdout


@pytest.mark.tier2
@pytest.mark.m1
class TestTier2RangeRequestValidation:
    """Empirical byte-range request and media asset validation against the SoundHelix CDN."""

    def test_sample_songs_range_request_initial_chunk(self, sample_songs):
        """Verify each audio URL supports HTTP Range 0-1023 (HTTP 206 Partial Content)."""
        assert len(sample_songs) == 6, f"Expected 6 sample songs, got {len(sample_songs)}"

        for song in sample_songs:
            url = song["streamURL"]
            req = urllib.request.Request(
                url,
                headers={"Range": "bytes=0-1023", "User-Agent": "Soundify/1.0"},
            )
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    assert resp.status == 206, f"Expected HTTP 206 on {url}, got {resp.status}"
                    data = resp.read()
                    assert len(data) == 1024, f"Expected 1024 bytes, got {len(data)}"
                    content_range = resp.headers.get("Content-Range", "")
                    assert content_range.startswith("bytes 0-1023/"), f"Unexpected Content-Range: {content_range}"
                    assert resp.headers.get("Accept-Ranges") == "bytes"
                    assert "audio" in resp.headers.get("Content-Type", "").lower()
            except Exception as e:
                pytest.fail(f"Range request failed on {song['id']} ({url}): {e}")

    def test_sample_songs_range_request_middle_chunk(self, sample_songs):
        """Verify each audio URL supports scrubbing to middle of file (bytes 1048576-1050623)."""
        for song in sample_songs:
            url = song["streamURL"]
            req = urllib.request.Request(
                url,
                headers={"Range": "bytes=1048576-1050623", "User-Agent": "Soundify/1.0"},
            )
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    assert resp.status == 206
                    data = resp.read()
                    assert len(data) == 2048, f"Expected 2048 bytes for middle chunk, got {len(data)}"
                    content_range = resp.headers.get("Content-Range", "")
                    assert content_range.startswith("bytes 1048576-1050623/")
            except Exception as e:
                pytest.fail(f"Middle range request failed on {song['id']}: {e}")

    def test_sample_songs_range_boundary_and_out_of_bounds(self, sample_songs):
        """Verify single boundary byte (0-0, last-last) returns 206, and OOB returns 416."""
        for song in sample_songs:
            url = song["streamURL"]
            # 1. Total length
            head_req = urllib.request.Request(url, method="HEAD")
            with urllib.request.urlopen(head_req, timeout=10) as head_resp:
                total_len = int(head_resp.headers.get("Content-Length", 0))
            assert total_len > 1_000_000, f"Expected file size > 1MB, got {total_len}"

            # 2. First byte (0-0)
            req_0 = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
            with urllib.request.urlopen(req_0, timeout=10) as resp_0:
                assert resp_0.status == 206
                assert len(resp_0.read()) == 1
                assert resp_0.headers.get("Content-Range") == f"bytes 0-0/{total_len}"

            # 3. Last byte
            req_last = urllib.request.Request(url, headers={"Range": f"bytes={total_len-1}-{total_len-1}"})
            with urllib.request.urlopen(req_last, timeout=10) as resp_last:
                assert resp_last.status == 206
                assert len(resp_last.read()) == 1
                assert resp_last.headers.get("Content-Range") == f"bytes {total_len-1}-{total_len-1}/{total_len}"

            # 4. Out of bounds range -> HTTP 416
            req_oob = urllib.request.Request(url, headers={"Range": f"bytes={total_len+100}-{total_len+200}"})
            try:
                urllib.request.urlopen(req_oob, timeout=10)
                pytest.fail(f"Expected HTTP 416 for OOB range on {url}")
            except urllib.error.HTTPError as err:
                assert err.code == 416, f"Expected 416 Range Not Satisfiable, got {err.code}"

    def test_sample_songs_audio_magic_bytes(self, sample_songs):
        """Verify that streaming payloads are genuine MP3 files with ID3 tag or sync frame."""
        for song in sample_songs:
            url = song["streamURL"]
            req = urllib.request.Request(url, headers={"Range": "bytes=0-9"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                magic = resp.read(10)
                is_id3 = magic[:3] == b"ID3"
                is_sync = magic[0] == 0xFF and (magic[1] & 0xE0) == 0xE0
                assert is_id3 or is_sync, f"File {url} does not have valid MP3 magic bytes: {magic[:4].hex()}"

    def test_sample_songs_artwork_urls(self, sample_songs):
        """Verify all remote cover artwork URLs return HTTP 200 with valid JPEG headers."""
        for song in sample_songs:
            url = song["artworkURL"]
            req = urllib.request.Request(url, headers={"User-Agent": "Soundify/1.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                assert resp.status == 200, f"Artwork URL {url} returned HTTP {resp.status}"
                ct = resp.headers.get("Content-Type", "")
                assert "image" in ct, f"Artwork URL {url} Content-Type is {ct}"
                magic = resp.read(4)
                assert magic[:3] == b"\xff\xd8\xff", f"Artwork {url} missing JPEG SOI marker: {magic.hex()}"
