# Soundify Testing Infrastructure & Methodology

## 1. Overview & Architecture

Soundify is an iOS streaming music player built in SwiftUI and AVFoundation. Because developer and CI environments often run on Linux (where proprietary Darwin frameworks like `SwiftUI` and `AVFoundation` are unavailable), this testing infrastructure provides a comprehensive, automated, 4-tier opaque-box test harness that runs natively and headless on Linux while thoroughly verifying Swift language compliance, model integrity, networking, audio engine state machines, UI contracts, and real-world online streaming capabilities.

```
+-------------------------------------------------------------------------------+
|                           Soundify Test Suite Harness                         |
+-------------------------------------------------------------------------------+
|  Tier 1: Feature Coverage      | Model properties, Codable, async fetch,      |
|                                | contracts, swiftc -parse syntax validation   |
|  Tier 2: Boundary & Corner     | Empty/single-track queues, seek boundary     |
|                                | clamping, invalid URLs, HTTP error codes     |
|  Tier 3: Cross-Feature Flow    | MusicAPI -> AudioManager -> playback state   |
|                                | -> time updates -> seek -> track transition  |
|  Tier 4: Real-World Scenarios  | Track auto-advance on finish, pause/resume,  |
|                                | rapid switching stress, live CDN range reqs  |
+-------------------------------------------------------------------------------+
```

---

## 2. Environment Prerequisites

- **Operating System**: Linux x86_64 / Ubuntu 24.04+ (or macOS)
- **Swift Toolchain**: Swift 6.4.1+ (`swift`, `swiftc`)
- **Python**: Python 3.12+ (3.14 installed)
- **Test Framework**: `pytest` 8.0+ (9.1 installed)
- **PBX Validator**: `plutil` (provided by swiftly toolchain)
- **Network**: Outbound HTTPS access to remote CDNs:
  - Audio: `https://www.soundhelix.com/` (MP3 range requests)
  - Artwork: `https://images.unsplash.com/` (JPEG cover art)

---

## 3. 4-Tier Test Architecture

### Tier 1: Feature Coverage & Interface Contracts (`tests/test_tier1_feature_coverage.py`)
- **F1: `Song` Data Model**: Validates `Soundify/Models/Song.swift` existence, Swift syntax (`swiftc -parse`), property structure (`id`, `title`, `artist`, `streamURL`, `artworkURL`, `duration`), protocols (`Identifiable`, `Codable`, `Hashable`), URL getters, and bidirectional JSON encoding/decoding roundtrips.
- **F2: `NetworkManager` & `MusicAPI`**: Validates `Soundify/Services/MusicAPI.swift`, modern Swift concurrency (`async/await`), `fetchTrendingSongs()`, typealias `MusicAPI = NetworkManager`, shared singleton instance, and sample track catalog.
- **F3-F7: `AudioManager` Audio Engine Contracts**: Validates `Soundify/Managers/AudioManager.swift` (Milestone 2), `@Published` reactive properties, `AVPlayer` / `AVPlayerItem` management, `AVAudioSession` category configuration (`.playback`), periodic time observer (`addPeriodicTimeObserver`), and track end notification listener (`.AVPlayerItemDidPlayToEndTime`).
- **F8-F10: SwiftUI Views Streaming Integration**: Validates `HomeView.swift` async playlist loading in `.task`, `AsyncImage` remote artwork rendering, `PlayerView.swift` reactive bindings to `audioManager.currentSong`, scrubbing slider, and play/pause controls (Milestone 3).
- **F11: Xcode PBX Synchronization**: Validates `Soundify.xcodeproj/project.pbxproj` with `plutil -lint` and verifies PBX registration of all new source files (Milestone 3).
- **F12: Global Swift Syntax Verification**: Executes `swiftc -parse` across every Swift source file in `Soundify/` ensuring 0 compilation/syntax errors.

### Tier 2: Boundary, Corner Cases & Adversarial Verification (`tests/test_tier2_boundary_corner.py`)
- **Empty Playlist**: Ingesting empty arrays, calling `next()`, `previous()`, `playPause()`, and seeking without crash, memory corruption, or index out of range.
- **Single-Track Playlist**: Next and previous navigation looping cleanly on track 0 without boundary violations.
- **Seek Boundaries & Clamping**: Clamping negative seeks (`-10.0s`) to `0.0s`, clamping past-duration seeks (`duration + 100s`) to exact `duration`, fractional progress seeking (`seek_progress(0.25)`), and zero-duration safety.
- **Invalid URLs & Malformed Inputs**: Empty string URLs returning `nil`, special characters, unicode emojis, and auto-percent-encoding safety.
- **HTTP Error Codes & Fallback Resilience**: Testing HTTP 404 Not Found, HTTP 500 Internal Server Error, and verifying `MusicAPI` fallback to `sampleTrendingSongs`.

### Tier 3: Cross-Feature Interactions (`tests/test_tier3_cross_feature.py`)
- **End-to-End Pipeline**: Full execution chain: `MusicAPI.fetchTrendingSongs()` -> `AudioManager.loadPlaylist()` -> initial playback state -> time advancement -> interactive seeking -> track transition.
- **State Machine Transitions**: Validates transitions between `Idle`, `Playing`, `Paused`, `Seeking`, and `Next` states.
- **Dynamic Playback Progress**: Continuous calculation of `playbackProgress` (`currentTime / duration`).
- **Direct Track Selection**: Tapping any song in the playlist instantly switches track, resets `currentTime` to 0.0, and updates `duration`.
- **Time Formatting**: Formats timestamps into `mm:ss` strings across boundaries.

### Tier 4: Real-World Scenarios (`tests/test_tier4_real_world.py`)
- **Track Auto-Advance**: Simulates track playback reaching completion; triggers automatic transition to the next track in queue with time reset.
- **Pause/Resume Continuity**: Pausing freezes playback time; idle time while paused does not advance playback; resuming continues from exact paused position.
- **Rapid Track Switching Stress**: Spams `next()` and `previous()` 60+ times in rapid succession to ensure no race conditions, index overflow, or deadlocks.
- **Continuous Scrubber Dragging**: Simulates dragging the PlayerView slider across multiple checkpoints, ensuring continuous monotonically consistent updates.
- **Live CDN Range Request Verification**: Sends real HTTP byte-range requests (`bytes=0-1023`) to remote SoundHelix MP3 streams, verifying HTTP 206 Partial Content and `audio/mpeg` MIME headers; verifies Unsplash album artwork connectivity.

---

## 4. Progressive Testability Model

During multi-milestone iterative refactoring, downstream features may not yet be implemented when upstream tests run. The test suite handles this using **Progressive Testability**:

1. **Independent Behavioral Oracles**: Core business logic and state machine contracts (`AudioEngineOracle`) are independently testable without waiting for Darwin-only UI components.
2. **Conditional Milestone Execution**: Tests that inspect source code files of pending milestones (`AudioManager.swift` in M2, `HomeView.swift` in M3) automatically skip with informative messages when those files are not yet created, ensuring test suite exit code 0 during intermediate milestones.
3. **Automatic Unskipping**: As soon as a worker generates a milestone's files, the corresponding tests immediately activate and run without requiring manual test modifications.

---

## 5. Test Runner & CLI Usage

Soundify includes a dedicated automated test runner script at `./run_e2e_tests.sh`.

### Quick Start
```bash
# Run complete test suite (syntax check, PBX lint, all 4 test tiers)
./run_e2e_tests.sh

# Run specific tier
./run_e2e_tests.sh --tier 1
./run_e2e_tests.sh --tier 2
./run_e2e_tests.sh --tier 3
./run_e2e_tests.sh --tier 4

# Run specific milestone tests
./run_e2e_tests.sh --milestone 1

# Run Swift syntax and PBX lint only
./run_e2e_tests.sh --syntax

# Verbose output
./run_e2e_tests.sh -v
```

### Direct Pytest Usage
```bash
# Run all tests
pytest -v

# Run with marker selection
pytest -m "tier1 or tier2"
pytest -m m1
```

---

## 6. Directory Structure

```
Soundify/
├── Soundify/
│   ├── Models/
│   │   ├── Song.swift               # Codable streaming model (M1)
│   │   └── Track.swift              # Existing local track model
│   ├── Services/
│   │   └── MusicAPI.swift           # Asynchronous networking layer (M1)
│   ├── Managers/
│   │   └── AudioManager.swift       # AVPlayer streaming engine (M2)
│   ├── Views/
│   │   ├── HomeView.swift           # Async loading & streaming UI (M3)
│   │   └── PlayerView.swift         # Player controls & scrub slider (M3)
│   └── SoundifyApp.swift            # Environment injection (M3)
├── Soundify.xcodeproj/
│   └── project.pbxproj              # PBX project configuration
├── tests/
│   ├── conftest.py                  # Shared fixtures, Swift runner & AudioEngineOracle
│   ├── test_tier1_feature_coverage.py   # Tier 1: Feature coverage & contracts
│   ├── test_tier2_boundary_corner.py    # Tier 2: Boundary & corner cases
│   ├── test_tier3_cross_feature.py      # Tier 3: Cross-feature interactions
│   └── test_tier4_real_world.py         # Tier 4: Real-world streaming lifecycle
├── pytest.ini                       # Pytest configuration & markers
├── run_e2e_tests.sh                 # Unified Linux automated test runner
├── TEST_INFRA.md                    # Infrastructure & architecture documentation
└── TEST_READY.md                    # Test readiness & validation report
```
