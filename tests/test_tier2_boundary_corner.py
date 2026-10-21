"""
test_tier2_boundary_corner.py - Tier 2: Boundary & Corner Cases Test Suite.
Validates empty playlists, single-track playlists, seek boundary clamping,
malformed/invalid URLs, HTTP error codes, and fallback resilience.
"""

import os
import json
import socket
import threading
import http.server
from pathlib import Path
import pytest
from conftest import (
    SOUNDIFY_DIR,
    MODELS_DIR,
    SERVICES_DIR,
    AudioEngineOracle,
    run_swift_code,
)


@pytest.mark.tier2
class TestTier2BoundaryAndCornerCases:

    # ---------------------------------------------------------
    # 1. Empty Playlist Handling
    # ---------------------------------------------------------

    def test_empty_playlist_initialization(self):
        """Authoritative Source: PROJECT.md § M2 Interface Contract"""
        oracle = AudioEngineOracle()
        oracle.load_playlist([])

        assert oracle.playlist == []
        assert oracle.current_song is None
        assert oracle.is_playing is False
        assert oracle.current_time == 0.0
        assert oracle.duration == 0.0
        assert oracle.playback_progress == 0.0

    def test_empty_playlist_next_and_previous_safety(self):
        """Authoritative Source: PROJECT.md § M2 Playback Controls API"""
        oracle = AudioEngineOracle()
        oracle.load_playlist([])

        # Calling next on empty playlist must not raise IndexError
        oracle.next()
        assert oracle.current_song is None
        assert oracle.is_playing is False

        # Calling previous on empty playlist must not raise IndexError
        oracle.previous()
        assert oracle.current_song is None
        assert oracle.is_playing is False

    def test_empty_playlist_play_pause_and_seek_safety(self):
        """Authoritative Source: PROJECT.md § M2 Playback Controls API"""
        oracle = AudioEngineOracle()
        oracle.load_playlist([])

        # Play/pause when empty must not start playing phantom track
        oracle.play_pause()
        assert oracle.is_playing is False
        assert oracle.current_song is None

        # Seeking when empty must remain at 0.0 and not crash
        oracle.seek(15.0)
        assert oracle.current_time == 0.0
        oracle.seek_progress(0.5)
        assert oracle.current_time == 0.0

    # ---------------------------------------------------------
    # 2. Single-Track Playlist Handling
    # ---------------------------------------------------------

    def test_single_track_playlist_next_looping(self, sample_songs):
        """Authoritative Source: PROJECT.md § M2 Playback Controls API"""
        single_song = [sample_songs[0]]
        oracle = AudioEngineOracle(single_song)
        oracle.play()

        assert oracle.current_song == single_song[0]
        assert oracle.is_playing is True

        # Advance playback partway
        oracle.seek(50.0)
        assert oracle.current_time == 50.0

        # Trigger next: with 1 track, (0 + 1) % 1 == 0, wraps back to same track and resets time to 0.0
        oracle.next()
        assert oracle.current_song == single_song[0]
        assert oracle.current_time == 0.0
        assert oracle.is_playing is True

        # Spamming next 10 times must stay stable on index 0
        for _ in range(10):
            oracle.next()
            assert oracle.current_song == single_song[0]
            assert oracle.current_time == 0.0

    def test_single_track_playlist_previous_rewind(self, sample_songs):
        """Authoritative Source: PROJECT.md § M2 Playback Controls API"""
        single_song = [sample_songs[0]]
        oracle = AudioEngineOracle(single_song)
        oracle.play()

        # When current_time > 3.0s, previous rewinds to 0.0
        oracle.seek(40.0)
        oracle.previous()
        assert oracle.current_song == single_song[0]
        assert oracle.current_time == 0.0

        # When current_time <= 3.0s, previous wraps back to song 0 at 0.0
        oracle.previous()
        assert oracle.current_song == single_song[0]
        assert oracle.current_time == 0.0

    # ---------------------------------------------------------
    # 3. Seek Boundaries & Precision Clamping
    # ---------------------------------------------------------

    def test_seek_clamping_negative_and_zero(self, sample_songs):
        """Authoritative Source: PROJECT.md § M2 Playback Controls API"""
        oracle = AudioEngineOracle(sample_songs)
        oracle.play(sample_songs[0])
        assert oracle.duration == 372.0

        # Negative seek must clamp to 0.0
        oracle.seek(-15.0)
        assert oracle.current_time == 0.0
        assert oracle.playback_progress == 0.0

        # Seek to exact 0.0
        oracle.seek(0.0)
        assert oracle.current_time == 0.0
        assert oracle.playback_progress == 0.0

    def test_seek_clamping_duration_and_past_duration(self, sample_songs):
        """Authoritative Source: PROJECT.md § M2 Playback Controls API"""
        oracle = AudioEngineOracle(sample_songs)
        oracle.play(sample_songs[0])
        dur = oracle.duration  # 372.0

        # Seek to exact duration
        oracle.seek(dur)
        assert oracle.current_time == dur
        assert oracle.playback_progress == 1.0

        # Seek past duration must clamp to duration
        oracle.seek(dur + 100.0)
        assert oracle.current_time == dur
        assert oracle.playback_progress == 1.0

        # Extreme values (e.g. 1,000,000 seconds)
        oracle.seek(1_000_000.0)
        assert oracle.current_time == dur
        assert oracle.playback_progress == 1.0

    def test_seek_progress_fractional_boundaries(self, sample_songs):
        """Authoritative Source: PROJECT.md § M2 Contract (seek progress)"""
        oracle = AudioEngineOracle(sample_songs)
        oracle.play(sample_songs[0])
        dur = oracle.duration  # 372.0

        oracle.seek_progress(0.25)
        assert oracle.current_time == pytest.approx(dur * 0.25, rel=1e-4)
        assert oracle.playback_progress == pytest.approx(0.25, rel=1e-4)

        oracle.seek_progress(0.5)
        assert oracle.current_time == pytest.approx(dur * 0.5, rel=1e-4)
        assert oracle.playback_progress == pytest.approx(0.5, rel=1e-4)

        # Clamping < 0.0
        oracle.seek_progress(-0.5)
        assert oracle.current_time == 0.0
        assert oracle.playback_progress == 0.0

        # Clamping > 1.0
        oracle.seek_progress(1.8)
        assert oracle.current_time == dur
        assert oracle.playback_progress == 1.0

    def test_format_time_boundary_values(self):
        """Authoritative Source: PROJECT.md § M2 Contract (formatTime)"""
        assert AudioEngineOracle.format_time(0.0) == "00:00"
        assert AudioEngineOracle.format_time(5.0) == "00:05"
        assert AudioEngineOracle.format_time(59.0) == "00:59"
        assert AudioEngineOracle.format_time(60.0) == "01:00"
        assert AudioEngineOracle.format_time(372.0) == "06:12"
        assert AudioEngineOracle.format_time(-10.0) == "00:00"

    # ---------------------------------------------------------
    # 4. Invalid URLs & Encoding Integrity
    # ---------------------------------------------------------

    def test_song_model_invalid_url_safety(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R1.1, PROJECT.md § F1"""
        song_file = MODELS_DIR / "Song.swift"
        assert song_file.exists(), "Song.swift not found"

        with open(song_file, "r") as f:
            code = f.read()

        swift_test = f"""
{code}

// Test URL with empty string
let emptySong = Song(
    id: "empty-1",
    title: "Empty URL Track",
    artist: "Tester",
    streamURL: "",
    artworkURL: "",
    duration: 100.0
)

assert(emptySong.url == nil, "Empty streamURL must return nil")
assert(emptySong.artwork == nil, "Empty artworkURL must return nil")

// Test URL with spaces (auto-encoded safely by modern Swift without crash)
let spaceSong = Song(
    id: "space-1",
    title: "Space Track",
    artist: "Tester",
    streamURL: "https://example.com/path with spaces.mp3",
    artworkURL: "https://example.com/art with spaces.jpg",
    duration: 100.0
)
assert(spaceSong.url != nil, "URL with spaces should safely parse into a percent-encoded URL")
assert(spaceSong.url?.absoluteString.contains("%20") == true)

// Test URL with special query parameters & unicode escaping
let validEscaped = Song(
    id: "esc-1",
    title: "Escaped Track 🎵",
    artist: "DJ & Producer",
    streamURL: "https://example.com/stream?token=abc%26123&track=blue+sky",
    artworkURL: "https://example.com/cover?w=500&q=80",
    duration: 210.0
)

assert(validEscaped.url != nil)
assert(validEscaped.artwork != nil)
assert(validEscaped.title == "Escaped Track 🎵")

print("URL_SAFETY_PASSED")
"""
        res = run_swift_code(swift_test)
        assert res.returncode == 0, f"URL safety test failed:\n{res.stderr}"
        assert "URL_SAFETY_PASSED" in res.stdout

    # ---------------------------------------------------------
    # 5. HTTP Error Codes & Fallback Resilience
    # ---------------------------------------------------------

    def test_network_manager_http_error_codes(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R1.2, PROJECT.md § F2"""
        song_file = MODELS_DIR / "Song.swift"
        api_file = SERVICES_DIR / "MusicAPI.swift"
        with open(song_file, "r") as f:
            song_code = f.read()
        with open(api_file, "r") as f:
            api_code = f.read()

        # Start a local HTTP server that returns 404 and 500 error codes
        class MockServerHandler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/404":
                    self.send_response(404)
                    self.end_headers()
                    self.wfile.write(b"Not Found")
                elif self.path == "/500":
                    self.send_response(500)
                    self.end_headers()
                    self.wfile.write(b"Internal Server Error")
                elif self.path == "/bad_json":
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(b"{ invalid json }")
                elif self.path == "/valid_json":
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    valid_songs = [
                        {
                            "id": "mock-1",
                            "title": "Mock Song",
                            "artist": "Mock Artist",
                            "streamURL": "https://example.com/mock.mp3",
                            "artworkURL": "https://example.com/mock.jpg",
                            "duration": 180.0,
                        }
                    ]
                    self.wfile.write(json.dumps(valid_songs).encode("utf-8"))
                else:
                    self.send_response(200)
                    self.end_headers()

            def log_message(self, format, *args):
                pass  # Suppress server logs

        server = http.server.HTTPServer(("127.0.0.1", 0), MockServerHandler)
        port = server.server_address[1]
        server_thread = threading.Thread(target=server.serve_forever, daemon=True)
        server_thread.start()

        swift_test = f"""
{song_code}
{api_code}

Task {{
    let manager = NetworkManager()
    
    // 1. Test 404 response throws URLError
    let url404 = URL(string: "http://127.0.0.1:{port}/404")!
    do {{
        let _: [Song] = try await manager.fetch(from: url404)
        print("FAILED: 404 did not throw")
        exit(1)
    }} catch {{
        // Expected URLError
    }}

    // 2. Test 500 response throws URLError
    let url500 = URL(string: "http://127.0.0.1:{port}/500")!
    do {{
        let _: [Song] = try await manager.fetch(from: url500)
        print("FAILED: 500 did not throw")
        exit(2)
    }} catch {{
        // Expected URLError
    }}

    // 3. Test fallback mechanism in fetchTrendingSongs with failing endpoint
    let fallbackManager = NetworkManager(endpointURL: url500)
    let fallbackSongs = try await fallbackManager.fetchTrendingSongs()
    assert(fallbackSongs.count == 6, "Expected fallback to 6 sample tracks on HTTP failure")
    assert(fallbackSongs.first?.id == "song-1")

    // 4. Test valid custom endpoint returns remote payload
    let validURL = URL(string: "http://127.0.0.1:{port}/valid_json")!
    let customManager = NetworkManager(endpointURL: validURL)
    let customSongs = try await customManager.fetchTrendingSongs()
    assert(customSongs.count == 1)
    assert(customSongs.first?.title == "Mock Song")

    print("HTTP_ERROR_AND_FALLBACK_TESTS_PASSED")
    exit(0)
}}

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
exit(3)
"""
        try:
            res = run_swift_code(swift_test, timeout=10)
            assert res.returncode == 0, f"HTTP error resilience failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
            assert "HTTP_ERROR_AND_FALLBACK_TESTS_PASSED" in res.stdout
        finally:
            server.shutdown()
            server.server_close()
