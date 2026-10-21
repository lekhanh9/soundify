"""
test_tier3_cross_feature.py - Tier 3: Cross-Feature Interactions Test Suite.
Validates the end-to-end chain:
MusicAPI fetch -> AudioManager loadPlaylist -> playback state changes ->
periodic time progress updates -> interactive seeking & scrub synchronizations.
"""

import os
import json
from pathlib import Path
import pytest
from conftest import (
    SOUNDIFY_DIR,
    MODELS_DIR,
    SERVICES_DIR,
    AudioEngineOracle,
    run_swift_code,
)


@pytest.mark.tier3
class TestTier3CrossFeatureInteractions:

    def test_end_to_end_fetch_load_and_playback_pipeline(self, sample_songs):
        """Authoritative Source: ORIGINAL_REQUEST.md § R1, R2, PROJECT.md § M1 ↔ M2 Contract"""
        # 1. Fetch songs via MusicAPI representation
        assert len(sample_songs) == 6
        first_song = sample_songs[0]
        second_song = sample_songs[1]

        # 2. Ingest into AudioEngine
        oracle = AudioEngineOracle()
        assert oracle.playlist == []
        assert oracle.current_song is None

        oracle.load_playlist(sample_songs)
        assert len(oracle.playlist) == 6
        assert oracle.current_song == first_song
        assert oracle.duration == first_song["duration"]
        assert oracle.current_time == 0.0
        assert oracle.is_playing is False

        # 3. Trigger Playback
        oracle.play()
        assert oracle.is_playing is True
        assert oracle.current_song == first_song

        # 4. Periodic time advancement simulation (e.g. 10.5 seconds of streaming)
        oracle.advance_time(10.5)
        assert oracle.current_time == 10.5
        assert oracle.playback_progress == pytest.approx(10.5 / first_song["duration"], rel=1e-4)

        # 5. Interactive Scrubbing / Seek
        oracle.seek(186.0)
        assert oracle.current_time == 186.0
        assert oracle.playback_progress == pytest.approx(186.0 / first_song["duration"], rel=1e-4)
        assert oracle.is_playing is True

        # 6. Track Advance (next)
        oracle.next()
        assert oracle.current_song == second_song
        assert oracle.duration == second_song["duration"]
        assert oracle.current_time == 0.0
        assert oracle.playback_progress == 0.0
        assert oracle.is_playing is True

        # 7. Previous Track Navigation
        oracle.previous()
        assert oracle.current_song == first_song
        assert oracle.current_time == 0.0
        assert oracle.duration == first_song["duration"]
        assert oracle.is_playing is True

    def test_playback_state_machine_transitions(self, sample_songs):
        """Authoritative Source: PROJECT.md § M2 Playback Controls API"""
        oracle = AudioEngineOracle(sample_songs)

        # Initial state: Idle / Loaded
        assert oracle.is_playing is False
        assert oracle.current_song == sample_songs[0]

        # State: Playing
        oracle.play()
        assert oracle.is_playing is True

        # State: Paused
        oracle.pause()
        assert oracle.is_playing is False
        preserved_time = oracle.current_time

        # Idle time should not advance playback while paused
        ended = oracle.advance_time(5.0)
        assert ended is False
        assert oracle.current_time == preserved_time
        assert oracle.is_playing is False

        # State: Resumed via play_pause()
        oracle.play_pause()
        assert oracle.is_playing is True

        # State: Paused via play_pause()
        oracle.play_pause()
        assert oracle.is_playing is False

    def test_direct_track_selection(self, sample_songs):
        """Authoritative Source: ORIGINAL_REQUEST.md § R2.1 (play(song:))"""
        oracle = AudioEngineOracle(sample_songs)

        # Jump directly to track 4
        target_song = sample_songs[4]
        oracle.play(song=target_song)

        assert oracle.current_song == target_song
        assert oracle.is_playing is True
        assert oracle.duration == target_song["duration"]
        assert oracle.current_time == 0.0

        # Advance partway
        oracle.seek(120.0)
        assert oracle.current_time == 120.0

        # Jump to track 2
        another_song = sample_songs[2]
        oracle.play(song=another_song)
        assert oracle.current_song == another_song
        assert oracle.duration == another_song["duration"]
        assert oracle.current_time == 0.0

    def test_time_formatting_during_playback_lifecycle(self, sample_songs):
        """Authoritative Source: PROJECT.md § M2 Contract (formatTime)"""
        oracle = AudioEngineOracle(sample_songs)
        track = sample_songs[0]  # duration 372.0s -> "06:12"
        oracle.play(track)

        assert oracle.format_time(oracle.current_time) == "00:00"
        assert oracle.format_time(oracle.duration) == "06:12"

        oracle.seek(65.0)
        assert oracle.format_time(oracle.current_time) == "01:05"

        oracle.seek(372.0)
        assert oracle.format_time(oracle.current_time) == "06:12"

    def test_swift_musicapi_to_audio_simulation_bridge(self):
        """
        Cross-validates that Swift's MusicAPI async output matches the schema
        and field constraints required by the playback audio engine.
        Authoritative Source: PROJECT.md § M1 ↔ M2 Contract
        """
        song_file = MODELS_DIR / "Song.swift"
        api_file = SERVICES_DIR / "MusicAPI.swift"
        with open(song_file, "r") as f:
            song_code = f.read()
        with open(api_file, "r") as f:
            api_code = f.read()

        swift_test = f"""
{song_code}
{api_code}

Task {{
    let songs = try await MusicAPI.fetchTrendingSongs()
    
    // Simulate audio engine playlist loading
    var playlist: [Song] = songs
    var currentSong: Song? = playlist.first
    var isPlaying = false
    var currentTime: Double = 0.0
    var duration: Double = currentSong?.duration ?? 0.0

    assert(playlist.count == 6)
    assert(currentSong != nil)
    assert(duration > 0.0)

    // Simulate play()
    isPlaying = true

    // Simulate periodic observer tick
    currentTime += 1.0
    let progress = currentTime / duration
    assert(progress > 0.0 && progress < 1.0)

    // Simulate next()
    currentSong = playlist[1]
    currentTime = 0.0
    duration = currentSong!.duration
    assert(currentSong?.id == "song-2")

    print("SWIFT_CROSS_FEATURE_BRIDGE_OK")
    exit(0)
}}

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
exit(1)
"""
        res = run_swift_code(swift_test, timeout=10)
        assert res.returncode == 0, f"Swift cross-feature bridge failed:\nstdout: {res.stdout}\nstderr: {res.stderr}"
        assert "SWIFT_CROSS_FEATURE_BRIDGE_OK" in res.stdout
