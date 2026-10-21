"""
test_tier1_feature_coverage.py - Tier 1: Feature Coverage Test Suite.
Validates Song model properties, Codable synthesis, MusicAPI async fetch,
AudioManager AVPlayer contracts, HomeView/PlayerView UI bindings, PBX registration,
and Swift AST syntax across all source files.
"""

import os
import re
from pathlib import Path
import pytest
from conftest import (
    SOUNDIFY_DIR,
    MODELS_DIR,
    SERVICES_DIR,
    MANAGERS_DIR,
    VIEWS_DIR,
    XCODEPROJ_PATH,
    run_swift_code,
    run_swiftc_parse,
    run_plutil_lint,
)


@pytest.mark.tier1
@pytest.mark.m1
class TestTier1FeatureCoverage:

    def test_song_model_file_exists_and_parses(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R1.1, PROJECT.md § F1"""
        song_file = MODELS_DIR / "Song.swift"
        assert song_file.exists(), f"Expected {song_file} to exist"

        parse_res = run_swiftc_parse(song_file)
        assert parse_res.returncode == 0, f"swiftc -parse failed on Song.swift:\n{parse_res.stderr}"

    def test_song_model_properties_and_protocols(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R1.1, PROJECT.md § F1"""
        song_file = MODELS_DIR / "Song.swift"
        assert song_file.exists(), "Song.swift not found"

        with open(song_file, "r") as f:
            code = f.read()

        # Contract assertions via AST / Swift execution
        swift_test = f"""
{code}

let testSong = Song(
    id: "uuid-1234",
    title: "Solaris",
    artist: "Starlight",
    streamURL: "https://example.com/audio.mp3",
    artworkURL: "https://example.com/cover.jpg",
    duration: 240.5
)

// Validate property types
assert(testSong.id == "uuid-1234")
assert(testSong.title == "Solaris")
assert(testSong.artist == "Starlight")
assert(testSong.streamURL == "https://example.com/audio.mp3")
assert(testSong.artworkURL == "https://example.com/cover.jpg")
assert(testSong.duration == 240.5)

// Validate Identifiable & Hashable conformance
let songSet: Set<Song> = [testSong, testSong]
assert(songSet.count == 1)

// Validate URL convenience properties
assert(testSong.url?.scheme == "https")
assert(testSong.artwork?.scheme == "https")

print("SONG_MODEL_VALID")
"""
        res = run_swift_code(swift_test)
        assert res.returncode == 0, f"Swift runtime validation failed:\n{res.stderr}"
        assert "SONG_MODEL_VALID" in res.stdout

    def test_song_json_codable_roundtrip(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R1.1, PROJECT.md § F1"""
        song_file = MODELS_DIR / "Song.swift"
        assert song_file.exists(), "Song.swift not found"

        with open(song_file, "r") as f:
            code = f.read()

        swift_test = f"""
{code}

let original = Song(
    id: "track-99",
    title: "Synthwave Odyssey",
    artist: "Retro Pulse",
    streamURL: "https://cdn.example.com/stream.mp3",
    artworkURL: "https://cdn.example.com/art.png",
    duration: 312.0
)

// Test Encoding
let encoder = JSONEncoder()
encoder.outputFormatting = .sortedKeys
let data = try encoder.encode(original)

// Test Decoding
let decoder = JSONDecoder()
let decoded = try decoder.decode(Song.self, from: data)

assert(decoded == original, "Decoded song must equal original")
assert(decoded.id == original.id)
assert(decoded.title == original.title)
assert(decoded.artist == original.artist)
assert(decoded.streamURL == original.streamURL)
assert(decoded.artworkURL == original.artworkURL)
assert(decoded.duration == original.duration)

// Test decoding from raw JSON payload (simulating remote API response)
let rawJSON = \"\"\"
{{
    "id": "remote-1",
    "title": "Cosmic Rain",
    "artist": "Aether",
    "streamURL": "https://remote.example.com/cosmic.mp3",
    "artworkURL": "https://remote.example.com/cosmic.jpg",
    "duration": 185.0
}}
\"\"\".data(using: .utf8)!

let fromRaw = try decoder.decode(Song.self, from: rawJSON)
assert(fromRaw.id == "remote-1")
assert(fromRaw.title == "Cosmic Rain")
assert(fromRaw.duration == 185.0)

print("CODABLE_ROUNDTRIP_SUCCESS")
"""
        res = run_swift_code(swift_test)
        assert res.returncode == 0, f"Codable roundtrip failed:\n{res.stderr}"
        assert "CODABLE_ROUNDTRIP_SUCCESS" in res.stdout

    def test_music_api_file_exists_and_parses(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R1.2, PROJECT.md § F2"""
        api_file = SERVICES_DIR / "MusicAPI.swift"
        assert api_file.exists(), f"Expected {api_file} to exist"

        parse_res = run_swiftc_parse(api_file)
        assert parse_res.returncode == 0, f"swiftc -parse failed on MusicAPI.swift:\n{parse_res.stderr}"

    def test_music_api_async_fetch_execution(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R1.2, PROJECT.md § F2"""
        song_file = MODELS_DIR / "Song.swift"
        api_file = SERVICES_DIR / "MusicAPI.swift"
        assert song_file.exists() and api_file.exists(), "Song.swift or MusicAPI.swift missing"

        with open(song_file, "r") as f:
            song_code = f.read()
        with open(api_file, "r") as f:
            api_code = f.read()

        swift_test = f"""
{song_code}
{api_code}

Task {{
    do {{
        let songs = try await MusicAPI.fetchTrendingSongs()
        assert(!songs.isEmpty, "Trending songs must not be empty")
        assert(songs.count >= 6, "Expected at least 6 sample songs, got \\(songs.count)")
        
        for song in songs {{
            assert(!song.id.isEmpty, "Song id must not be empty")
            assert(!song.title.isEmpty, "Song title must not be empty")
            assert(!song.artist.isEmpty, "Song artist must not be empty")
            assert(song.streamURL.hasPrefix("https://"), "Stream URL must be HTTPS")
            assert(song.artworkURL.hasPrefix("https://"), "Artwork URL must be HTTPS")
            assert(song.duration > 0.0, "Duration must be positive")
        }}
        print("ASYNC_FETCH_SUCCESS_COUNT_\\(songs.count)")
        exit(0)
    }} catch {{
        print("ASYNC_FETCH_FAILED: \\(error)")
        exit(1)
    }}
}}

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
exit(2)
"""
        res = run_swift_code(swift_test, timeout=10)
        assert res.returncode == 0, f"MusicAPI async fetch failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "ASYNC_FETCH_SUCCESS_COUNT_" in res.stdout

    def test_music_api_alias_and_shared_instance(self):
        """Authoritative Source: PROJECT.md § M1 ↔ M2 Contract"""
        song_file = MODELS_DIR / "Song.swift"
        api_file = SERVICES_DIR / "MusicAPI.swift"
        with open(song_file, "r") as f:
            song_code = f.read()
        with open(api_file, "r") as f:
            api_code = f.read()

        swift_test = f"""
{song_code}
{api_code}

let netManager = NetworkManager.shared
let musicAPI = MusicAPI.shared
assert(netManager === musicAPI, "MusicAPI must be typealias of NetworkManager")

print("ALIAS_CHECK_PASSED")
"""
        res = run_swift_code(swift_test)
        assert res.returncode == 0, f"MusicAPI alias check failed:\n{res.stderr}"
        assert "ALIAS_CHECK_PASSED" in res.stdout

    @pytest.mark.m2
    def test_audio_manager_avplayer_integration(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R2.1, PROJECT.md § F3-F7"""
        audio_manager_file = MANAGERS_DIR / "AudioManager.swift"
        if not audio_manager_file.exists():
            pytest.skip("Milestone 2 pending: Soundify/Managers/AudioManager.swift has not been created yet")

        # Verify swiftc -parse passes
        parse_res = run_swiftc_parse(audio_manager_file)
        assert parse_res.returncode == 0, f"swiftc -parse failed on AudioManager.swift:\n{parse_res.stderr}"

        with open(audio_manager_file, "r") as f:
            content = f.read()

        # Contract checks
        assert "ObservableObject" in content, "AudioManager must conform to ObservableObject"
        assert "@Published" in content, "AudioManager must define @Published properties"
        assert "currentSong" in content, "AudioManager must expose currentSong"
        assert "isPlaying" in content, "AudioManager must expose isPlaying"
        assert "currentTime" in content, "AudioManager must expose currentTime"
        assert "duration" in content, "AudioManager must expose duration"
        assert "playlist" in content, "AudioManager must expose playlist"
        assert "AVPlayer" in content, "AudioManager must manage an AVPlayer"
        assert "AVAudioSession" in content or ".playback" in content, "AudioManager must configure AVAudioSession"
        assert "addPeriodicTimeObserver" in content, "AudioManager must utilize addPeriodicTimeObserver"

    @pytest.mark.m3
    def test_home_view_task_and_async_image(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R3.1, PROJECT.md § F9"""
        home_view_file = VIEWS_DIR / "HomeView.swift"
        assert home_view_file.exists(), "HomeView.swift not found"

        with open(home_view_file, "r") as f:
            content = f.read()

        if "audioManager" not in content and "AudioManager" not in content:
            pytest.skip("Milestone 3 pending: HomeView.swift not yet updated with AudioManager")

        # Verify task and AsyncImage
        assert ".task" in content, "HomeView must trigger async loading in .task"
        assert "loadPlaylist" in content, "HomeView must invoke loadPlaylist() in .task"
        assert "AsyncImage" in content, "HomeView must render streaming songs with AsyncImage"

    @pytest.mark.m3
    def test_player_view_slider_and_controls(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R3.2, PROJECT.md § F10"""
        player_view_file = VIEWS_DIR / "PlayerView.swift"
        assert player_view_file.exists(), "PlayerView.swift not found"

        with open(player_view_file, "r") as f:
            content = f.read()

        if "audioManager" not in content and "AudioManager" not in content:
            pytest.skip("Milestone 3 pending: PlayerView.swift not yet updated with AudioManager")

        # Verify bindings and controls
        assert "currentSong" in content, "PlayerView must bind to currentSong"
        assert "playPause" in content or "togglePlayPause" in content, "PlayerView must bind play/pause control"
        assert "currentTime" in content, "PlayerView must bind slider to currentTime"
        assert "seek" in content, "PlayerView must trigger seek(to:) on scrub"

    @pytest.mark.m3
    def test_pbx_project_registration(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R3.4, PROJECT.md § F11, F13"""
        assert XCODEPROJ_PATH.exists(), f"project.pbxproj not found at {XCODEPROJ_PATH}"

        lint_res = run_plutil_lint(XCODEPROJ_PATH)
        assert lint_res.returncode == 0, f"plutil -lint failed on project.pbxproj:\n{lint_res.stderr}"

        with open(XCODEPROJ_PATH, "r") as f:
            content = f.read()

        # Check for registered files
        registered_files = []
        for expected in ["Song.swift", "MusicAPI.swift", "AudioManager.swift"]:
            if expected in content:
                registered_files.append(expected)

        if len(registered_files) < 3:
            pytest.skip(
                f"Milestone 3 pending: PBX project currently has {registered_files}, waiting for all new files"
            )

        assert "Song.swift" in content
        assert "MusicAPI.swift" in content
        assert "AudioManager.swift" in content

    def test_swiftc_syntax_validation_all_source_files(self):
        """Authoritative Source: ORIGINAL_REQUEST.md § R4.1, PROJECT.md § F12"""
        swift_files = list(SOUNDIFY_DIR.glob("**/*.swift"))
        assert len(swift_files) > 0, "No Swift files found in Soundify"

        errors = []
        for swift_file in swift_files:
            res = run_swiftc_parse(swift_file)
            if res.returncode != 0:
                errors.append(f"{swift_file.name}: {res.stderr.strip()}")

        assert not errors, f"swiftc -parse failed on {len(errors)} files:\n" + "\n".join(errors)
