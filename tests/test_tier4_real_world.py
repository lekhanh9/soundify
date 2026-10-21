"""
test_tier4_real_world.py - Tier 4: Real-World Scenarios Test Suite.
Validates end-to-end streaming lifecycle:
Track auto-advance on playback completion, pause/resume continuity,
rapid track switching stress, scrubber dragging simulations,
and live CDN streaming range request verification.
"""

import urllib.request
import urllib.error
import pytest
from conftest import (
    AudioEngineOracle,
    sample_songs,
)


@pytest.mark.tier4
class TestTier4RealWorldScenarios:

    def test_track_auto_advance_on_playback_end(self, sample_songs):
        """Authoritative Source: ORIGINAL_REQUEST.md § R2.1 (.AVPlayerItemDidPlayToEndTime)"""
        oracle = AudioEngineOracle(sample_songs)
        oracle.play(sample_songs[0])

        assert oracle.current_song["id"] == "song-1"
        dur1 = oracle.duration  # 372.0s

        # Advance to just before completion
        finished = oracle.advance_time(dur1 - 1.0)
        assert finished is False
        assert oracle.current_song["id"] == "song-1"
        assert oracle.current_time == dur1 - 1.0

        # Advance past completion (simulating itemDidPlayToEndTime notification)
        finished = oracle.advance_time(2.0)
        assert finished is True
        # Must auto-advance to song-2
        assert oracle.current_song["id"] == "song-2"
        assert oracle.current_time == 0.0
        assert oracle.duration == 425.0
        assert oracle.is_playing is True

    def test_full_playlist_sequential_auto_advance(self, sample_songs):
        """Authoritative Source: ORIGINAL_REQUEST.md § R2.1"""
        oracle = AudioEngineOracle(sample_songs)
        oracle.play(sample_songs[0])

        # Step through every song in the playlist via completion
        for i in range(len(sample_songs)):
            expected_current = sample_songs[i]
            assert oracle.current_song["id"] == expected_current["id"]
            
            # Jump to end of current track
            oracle.advance_time(oracle.duration)

        # After finishing last track, loops back to first track
        assert oracle.current_song["id"] == sample_songs[0]["id"]
        assert oracle.current_time == 0.0

    def test_pause_resume_playback_continuity(self, sample_songs):
        """Authoritative Source: ORIGINAL_REQUEST.md § R2.1 (playPause)"""
        oracle = AudioEngineOracle(sample_songs)
        oracle.play(sample_songs[0])

        # Play for 45.0 seconds
        oracle.advance_time(45.0)
        assert oracle.current_time == 45.0
        assert oracle.is_playing is True

        # Pause playback
        oracle.pause()
        assert oracle.is_playing is False
        assert oracle.current_time == 45.0

        # Simulate 10 seconds of wall-clock idle time while paused
        finished = oracle.advance_time(10.0)
        assert finished is False
        assert oracle.current_time == 45.0  # Time must NOT advance when paused

        # Resume playback
        oracle.play()
        assert oracle.is_playing is True
        assert oracle.current_time == 45.0

        # Now time advances from 45.0
        oracle.advance_time(15.0)
        assert oracle.current_time == 60.0

    def test_rapid_track_switching_stress(self, sample_songs):
        """
        Adversarial Boundary & Stress:
        Simulate user spamming the Next / Previous buttons rapidly 60 times.
        Authoritative Source: PROJECT.md § M2 Playback Controls API
        """
        oracle = AudioEngineOracle(sample_songs)
        oracle.play()

        total_songs = len(sample_songs)

        # Rapidly spam Next 60 times
        for step in range(60):
            oracle.next()
            expected_idx = (step + 1) % total_songs
            assert oracle.current_song["id"] == sample_songs[expected_idx]["id"]
            assert oracle.current_time == 0.0
            assert oracle.is_playing is True

        # Rapidly spam Previous 60 times
        for step in range(60):
            oracle.previous()
            # Since current_time is 0.0, each previous call steps back 1
            assert oracle.current_song is not None
            assert oracle.current_time == 0.0
            assert oracle.is_playing is True

    def test_continuous_scrubber_dragging_simulation(self, sample_songs):
        """
        Simulate user dragging the scrub slider back and forth in PlayerView.
        Authoritative Source: ORIGINAL_REQUEST.md § R3.2 (PlayerView scrub slider)
        """
        oracle = AudioEngineOracle(sample_songs)
        oracle.play(sample_songs[0])
        dur = oracle.duration  # 372.0s

        scrub_checkpoints = [0.05, 0.15, 0.40, 0.75, 0.20, 0.85, 0.50]

        for progress in scrub_checkpoints:
            oracle.seek_progress(progress)
            expected_time = dur * progress
            assert oracle.current_time == pytest.approx(expected_time, rel=1e-4)
            assert oracle.playback_progress == pytest.approx(progress, rel=1e-4)
            assert oracle.is_playing is True

    def test_live_cdn_streaming_range_requests(self, sample_songs):
        """
        Verify live CDN connectivity for sample tracks:
        1. Range request returns HTTP 206 Partial Content or 200 OK.
        2. Content-Type is audio/mpeg.
        3. Album artwork returns HTTP 200 with image/* mime type.
        Authoritative Source: PROJECT.md § Architecture, ORIGINAL_REQUEST.md § R1.2
        """
        headers = {"User-Agent": "Soundify-TestRunner/1.0", "Range": "bytes=0-1023"}

        for song in sample_songs:
            stream_url = song["streamURL"]
            artwork_url = song["artworkURL"]

            # Test Audio Stream Range Request
            req = urllib.request.Request(stream_url, headers=headers)
            try:
                with urllib.request.urlopen(req, timeout=6) as response:
                    status = response.status
                    content_type = response.headers.get("Content-Type", "").lower()
                    assert status in (200, 206), f"Expected 200 or 206 for {stream_url}, got {status}"
                    assert "audio" in content_type or "mpeg" in content_type or "octet-stream" in content_type, (
                        f"Expected audio content type for {stream_url}, got {content_type}"
                    )
            except urllib.error.URLError as e:
                pytest.fail(f"Failed to connect to audio CDN stream {stream_url}: {e}")

            # Test Artwork Image Request
            art_req = urllib.request.Request(artwork_url, headers={"User-Agent": "Soundify-TestRunner/1.0"})
            try:
                with urllib.request.urlopen(art_req, timeout=6) as art_response:
                    art_status = art_response.status
                    art_content_type = art_response.headers.get("Content-Type", "").lower()
                    assert art_status == 200, f"Expected 200 for artwork {artwork_url}, got {art_status}"
                    assert "image" in art_content_type, f"Expected image content type for {artwork_url}, got {art_content_type}"
            except urllib.error.URLError as e:
                pytest.fail(f"Failed to connect to artwork CDN {artwork_url}: {e}")
