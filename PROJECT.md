# Project: Soundify Online Streaming & AVPlayer Engine

## Architecture
Soundify is an iOS streaming music player built in SwiftUI and AVFoundation.
- **Models**: `Soundify/Models/Song.swift` defines `Song` conforming to `Codable`, `Identifiable`, and `Hashable`.
- **Services**: `Soundify/Services/MusicAPI.swift` implements `NetworkManager` (aliased as `MusicAPI`) utilizing `URLSession` and Swift concurrency `async/await` to fetch trending songs with verified HTTPS MP3 streaming URLs and remote artwork.
- **Managers**: `Soundify/Managers/AudioManager.swift` conforms to `ObservableObject`, wraps an internal `AVPlayer` and `AVPlayerItem`, configures `AVAudioSession` to `.playback`, uses `addPeriodicTimeObserver` for non-blocking dynamic time and duration updates, and exposes playback controls.
- **Views**:
  - `Soundify/SoundifyApp.swift` injects `AudioManager` as an `@StateObject` and `.environmentObject(audioManager)`.
  - `Soundify/Views/HomeView.swift` loads the playlist asynchronously via `.task { await audioManager.loadPlaylist() }`, renders streaming tracks using `AsyncImage`, and binds track selection to `audioManager.play(song:)`.
  - `Soundify/Views/PlayerView.swift` reactively binds album artwork (`AsyncImage`), track info, play/pause controls, and the scrub slider to `audioManager.currentTime` and `audioManager.seek(to:)`.
- **Project Configuration**: `Soundify.xcodeproj/project.pbxproj` references all newly added files (`Song.swift`, `MusicAPI.swift`, `AudioManager.swift`) in PBXBuildFile, PBXFileReference, PBXGroup, and PBXSourcesBuildPhase.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | `Song` Data Model | Properties: `id` (String), `title` (String), `artist` (String), `streamURL` (String), `artworkURL` (String), `duration` (Double); conforms to `Codable`, `Identifiable`, `Hashable` | M1 | ORIGINAL_REQUEST §R1.1 |
| F2 | `NetworkManager` & `MusicAPI` | `NetworkManager` using `URLSession` and `async/await`; `fetchTrendingSongs() async throws -> [Song]` returning remote MP3s with range request support & cover artwork | M1 | ORIGINAL_REQUEST §R1.2 |
| F3 | `AudioManager` Audio Engine | Conforms to `ObservableObject`, manages `AVPlayer` & `AVPlayerItem`; published properties: `currentSong`, `isPlaying`, `currentTime`, `duration`, `playlist` | M2 | ORIGINAL_REQUEST §R2.1 |
| F4 | Audio Session Configuration | Configures `AVAudioSession` category to `.playback` and activates session for background playback | M2 | ORIGINAL_REQUEST §R2.1 |
| F5 | Periodic Time Observation | Implements `AVPlayer.addPeriodicTimeObserver` on `.main` for responsive, non-blocking time/duration updates; cleans up in `deinit` | M2 | ORIGINAL_REQUEST §R2.1 |
| F6 | Playback Controls API | Implements `loadPlaylist() async`, `play(song: Song)`, `playPause()`, `next()`, `previous()`, `seek(to seconds: Double)` | M2 | ORIGINAL_REQUEST §R2.1 |
| F7 | Track Auto-Advance | Listens to `.AVPlayerItemDidPlayToEndTime` notification to automatically advance playback to `next()` | M2 | ORIGINAL_REQUEST §R2.1 |
| F8 | App Environment Injection | `SoundifyApp.swift` instantiates `AudioManager` and injects via `.environmentObject(audioManager)` with root view `ContentView` | M3 | ORIGINAL_REQUEST §R4.3 |
| F9 | `HomeView` Async Loading & Streaming UI | Triggers `audioManager.loadPlaylist()` in `.task`, renders songs with `AsyncImage`, binds selection to `audioManager.play(song:)`, mini-player controls | M3 | ORIGINAL_REQUEST §R4.1 |
| F10 | `PlayerView` Reactive Controls & Scrubbing | Binds display to `audioManager.currentSong`, toggle play/pause via `audioManager.playPause()`, binds scrub slider to `audioManager.currentTime` and triggers `audioManager.seek(to:)` | M3 | ORIGINAL_REQUEST §R4.2 |
| F11 | `ContentView` Root TabView Navigation | Implements root `TabView` navigation hosting `HomeView`, search, and library tabs | M3 | ORIGINAL_REQUEST §R4.3 |
| F12 | Unit Tests (`Tests/SoundifyTests.swift`) | Implement and verify unit tests in `Tests/SoundifyTests.swift` testing `MusicAPI` JSON decoding and `Song` contracts | M4 | ORIGINAL_REQUEST §R5.1 |
| F13 | Full Syntax & Structure Validation | Verifies all Swift source files pass syntax and AST parsing (`swiftc -parse`) with 0 errors | M4 | ORIGINAL_REQUEST §R5.2 |
| F14 | Retain Cycle Memory Audit | Audits `AudioManager` for retain cycles ensuring weak references in closures and observers | M4 | ORIGINAL_REQUEST §R5.3 |
| F15 | Xcode PBX Project Synchronization | Updates `Soundify.xcodeproj/project.pbxproj` to include all source files (`Song.swift`, `MusicAPI.swift`, `AudioManager.swift`, `ContentView.swift`) and verifies with `plutil -lint` | M4 | ORIGINAL_REQUEST §R5.4 |
| F16 | Git Commit & Deployment | Commits with message `feat: build Soundify app with mega swarm architecture` and pushes to `origin main` | M4 | ORIGINAL_REQUEST §R5.5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Models & Networking Layer | `Soundify/Models/Song.swift`, `Soundify/Services/MusicAPI.swift` | none | DONE |
| M2 | AVPlayer Audio Engine | `Soundify/Managers/AudioManager.swift` | M1 | DONE |
| M3 | SwiftUI Views & Navigation | `Soundify/Views/HomeView.swift`, `Soundify/Views/PlayerView.swift`, `Soundify/ContentView.swift`, `Soundify/SoundifyApp.swift` | M1, M2 | DONE |
| M4 | Integrated QA, Audit & Deployment | `Tests/SoundifyTests.swift`, PBX sync, retain audit, `swiftc -parse`, git commit `feat: build Soundify app with mega swarm architecture` & push | M1, M2, M3 | DONE |

## Interface Contracts

### M1 ↔ M2 Contract
- `Song` struct:
  ```swift
  public struct Song: Identifiable, Codable, Hashable {
      public let id: String
      public let title: String
      public let artist: String
      public let streamURL: String
      public let artworkURL: String
      public let duration: Double
  }
  ```
- `MusicAPI` / `NetworkManager`:
  ```swift
  public final class NetworkManager {
      public static let shared: NetworkManager
      public func fetchTrendingSongs() async throws -> [Song]
      public static func fetchTrendingSongs() async throws -> [Song]
  }
  public typealias MusicAPI = NetworkManager
  ```

### M2 ↔ M3 Contract
- `AudioManager`:
  ```swift
  public final class AudioManager: ObservableObject {
      @Published public var currentSong: Song?
      @Published public var isPlaying: Bool
      @Published public var currentTime: Double
      @Published public var duration: Double
      @Published public var playlist: [Song]
      @Published public var isPlayerPresented: Bool

      public init()
      public func loadPlaylist() async
      public func play(song: Song)
      public func play()
      public func pause()
      public func playPause()
      public func togglePlayPause()
      public func next()
      public func previous()
      public func seek(to seconds: Double)
      public func seek(progress: Double)
      public var playbackProgress: Double
      public func formatTime(_ time: Double) -> String
  }
  ```

## Code Layout
- Exclusive File Ownership & Delegation Boundaries:
  - Agent 3 (M1 Worker) exclusively owns:
    - `Soundify/Models/Song.swift`
    - `Soundify/Services/MusicAPI.swift`
  - Agent 4 (M2 Worker) exclusively owns:
    - `Soundify/Managers/AudioManager.swift`
  - Agent 5 (Home UI) exclusively owns:
    - `Soundify/Views/HomeView.swift`
    - *Constraint*: Agent 5 MUST NEVER edit `AudioManager.swift`. If changes are needed, it must request them from Agent 4.
  - Agent 6 (Player UI) exclusively owns:
    - `Soundify/Views/PlayerView.swift`
  - Agent 7 (Glue & App) exclusively owns:
    - `Soundify/ContentView.swift`
    - `Soundify/SoundifyApp.swift`
    - `Soundify.xcodeproj/project.pbxproj`
  - Agents 8 & 9 (M4 QA & Audit) exclusively own:
    - `Tests/SoundifyTests.swift`
    - Verification test scripts and git operations
  - M4 Worker exclusively owns:
    - `Tests/SoundifyTests.swift`
    - `Soundify.xcodeproj/project.pbxproj`
    - Verification test scripts and git operations
