"""
conftest.py - Shared fixtures, helpers, and behavioral reference models for Soundify test suite.
"""

import os
import subprocess
import json
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, Any, List, Optional
import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SOUNDIFY_DIR = PROJECT_ROOT / "Soundify"
MODELS_DIR = SOUNDIFY_DIR / "Models"
SERVICES_DIR = SOUNDIFY_DIR / "Services"
MANAGERS_DIR = SOUNDIFY_DIR / "Managers"
VIEWS_DIR = SOUNDIFY_DIR / "Views"
XCODEPROJ_PATH = PROJECT_ROOT / "Soundify.xcodeproj" / "project.pbxproj"


@pytest.fixture(scope="session")
def project_root() -> Path:
    return PROJECT_ROOT


@pytest.fixture(scope="session")
def soundify_dir() -> Path:
    return SOUNDIFY_DIR


@pytest.fixture(scope="session")
def sample_songs() -> List[Dict[str, Any]]:
    """Authoritative sample songs specified in PROJECT.md and MusicAPI.swift."""
    return [
        {
            "id": "song-1",
            "title": "Midnight Echoes",
            "artist": "Kavinsky & Daft Sound",
            "streamURL": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
            "artworkURL": "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
            "duration": 372.0,
        },
        {
            "id": "song-2",
            "title": "Cyber Sunset",
            "artist": "Neon Pulse",
            "streamURL": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
            "artworkURL": "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60",
            "duration": 425.0,
        },
        {
            "id": "song-3",
            "title": "Deep Resonance",
            "artist": "SubBass Collective",
            "streamURL": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
            "artworkURL": "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60",
            "duration": 344.0,
        },
        {
            "id": "song-4",
            "title": "Starlight Drift",
            "artist": "Aura Void",
            "streamURL": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
            "artworkURL": "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=60",
            "duration": 302.0,
        },
        {
            "id": "song-5",
            "title": "Solar Flare",
            "artist": "Astral Vibes",
            "streamURL": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3",
            "artworkURL": "https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=60",
            "duration": 325.0,
        },
        {
            "id": "song-6",
            "title": "Neon Horizon",
            "artist": "Hyperion Synth",
            "streamURL": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3",
            "artworkURL": "https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=500&auto=format&fit=crop&q=60",
            "duration": 389.0,
        },
    ]


def run_swift_code(snippet: str, timeout: int = 15) -> subprocess.CompletedProcess:
    """Execute arbitrary Swift code on Linux using the installed Swift toolchain."""
    return subprocess.run(
        ["swift", "-"],
        input=snippet,
        text=True,
        capture_output=True,
        timeout=timeout,
    )


def run_swiftc_parse(file_path: Path, timeout: int = 10) -> subprocess.CompletedProcess:
    """Validate Swift source syntax and AST using swiftc -parse."""
    return subprocess.run(
        ["swiftc", "-parse", str(file_path)],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def run_plutil_lint(file_path: Path, timeout: int = 10) -> subprocess.CompletedProcess:
    """Lint Xcode plist / project.pbxproj using plutil -lint."""
    return subprocess.run(
        ["plutil", "-lint", str(file_path)],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


class AudioEngineOracle:
    """
    Authoritative behavioral reference model for Soundify's AudioManager.
    Derived directly from PROJECT.md § M2 Audio Engine Contract and ORIGINAL_REQUEST.md § R2.
    """

    def __init__(self, initial_playlist: Optional[List[Dict[str, Any]]] = None):
        self.playlist: List[Dict[str, Any]] = []
        self.current_song: Optional[Dict[str, Any]] = None
        self.is_playing: bool = False
        self.current_time: float = 0.0
        self.duration: float = 0.0
        self.is_player_presented: bool = False
        if initial_playlist:
            self.load_playlist(initial_playlist)

    @property
    def playback_progress(self) -> float:
        if self.duration <= 0.0:
            return 0.0
        return min(max(self.current_time / self.duration, 0.0), 1.0)

    def load_playlist(self, songs: List[Dict[str, Any]]) -> None:
        self.playlist = list(songs)
        if self.playlist and self.current_song is None:
            self.current_song = self.playlist[0]
            self.duration = float(self.playlist[0].get("duration", 0.0))
            self.current_time = 0.0

    def play(self, song: Optional[Dict[str, Any]] = None) -> None:
        if song is not None:
            # If switching to a new song, reset playback time
            if self.current_song != song:
                self.current_song = song
                self.current_time = 0.0
                self.duration = float(song.get("duration", 0.0))
        elif self.current_song is None and self.playlist:
            self.current_song = self.playlist[0]
            self.duration = float(self.playlist[0].get("duration", 0.0))
            self.current_time = 0.0

        if self.current_song is not None:
            self.is_playing = True

    def pause(self) -> None:
        self.is_playing = False

    def play_pause(self) -> None:
        if self.is_playing:
            self.pause()
        else:
            self.play()

    def toggle_play_pause(self) -> None:
        self.play_pause()

    def next(self) -> None:
        if not self.playlist:
            self.current_song = None
            self.is_playing = False
            self.current_time = 0.0
            self.duration = 0.0
            return

        if self.current_song is None:
            self.play(self.playlist[0])
            return

        try:
            curr_idx = self.playlist.index(self.current_song)
            next_idx = (curr_idx + 1) % len(self.playlist)
        except ValueError:
            next_idx = 0

        next_song = self.playlist[next_idx]
        self.current_song = next_song
        self.current_time = 0.0
        self.duration = float(next_song.get("duration", 0.0))
        self.is_playing = True

    def previous(self) -> None:
        if not self.playlist:
            self.current_song = None
            self.is_playing = False
            self.current_time = 0.0
            self.duration = 0.0
            return

        # If current_time > 3.0s, rewind to start of current song
        if self.current_time > 3.0:
            self.current_time = 0.0
            return

        if self.current_song is None:
            self.play(self.playlist[0])
            return

        try:
            curr_idx = self.playlist.index(self.current_song)
            prev_idx = (curr_idx - 1 + len(self.playlist)) % len(self.playlist)
        except ValueError:
            prev_idx = 0

        prev_song = self.playlist[prev_idx]
        self.current_song = prev_song
        self.current_time = 0.0
        self.duration = float(prev_song.get("duration", 0.0))
        self.is_playing = True

    def seek(self, to_seconds: float) -> None:
        if self.duration <= 0.0:
            self.current_time = 0.0
            return
        # Clamp to [0.0, duration]
        self.current_time = min(max(float(to_seconds), 0.0), self.duration)

    def seek_progress(self, progress: float) -> None:
        clamped_progress = min(max(float(progress), 0.0), 1.0)
        self.seek(clamped_progress * self.duration)

    def advance_time(self, delta_seconds: float) -> bool:
        """Simulate time advancement by periodic time observer. Returns True if track finished."""
        if not self.is_playing or self.current_song is None:
            return False

        self.current_time += delta_seconds
        if self.current_time >= self.duration:
            # Track ended: auto advance to next
            self.next()
            return True
        return False

    @staticmethod
    def format_time(time_seconds: float) -> str:
        clamped = max(0.0, float(time_seconds))
        minutes = int(clamped) // 60
        seconds = int(clamped) % 60
        return f"{minutes:02d}:{seconds:02d}"


@pytest.fixture
def audio_oracle(sample_songs) -> AudioEngineOracle:
    return AudioEngineOracle(sample_songs)
