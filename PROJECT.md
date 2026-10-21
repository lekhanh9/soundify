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
| F8 | App Environment Injection | `SoundifyApp.swift` instantiates `AudioManager` and injects via `.environmentObject(audioManager)` | M3 | ORIGINAL_REQUEST §R3.3 |
| F9 | `HomeView` Async Loading & Streaming UI | Triggers `audioManager.loadPlaylist()` in `.task`, renders songs with `AsyncImage`, binds selection to `audioManager.play(song:)`, mini-player controls | M3 | ORIGINAL_REQUEST §R3.1 |
| F10 | `PlayerView` Reactive Controls & Scrubbing | Binds display to `audioManager.currentSong`, toggle play/pause via `audioManager.playPause()`, binds scrub slider to `audioManager.currentTime` and triggers `audioManager.seek(to:)` | M3 | ORIGINAL_REQUEST §R3.2 |
| F11 | Xcode PBX Project Synchronization | Updates `Soundify.xcodeproj/project.pbxproj` to include `Song.swift`, `MusicAPI.swift`, and `AudioManager.swift` in build phases and groups | M3 | ORIGINAL_REQUEST §R3.4 |
| F12 | Full Syntax & Structure Validation | Verifies all Swift source files pass syntax and structure checks (`swiftc -parse`) with 0 errors | M4 | ORIGINAL_REQUEST §R4.1 |
| F13 | PBX Plist Lint Validation | Verifies `Soundify.xcodeproj/project.pbxproj` passes `plutil -lint` without syntax errors | M4 | ORIGINAL_REQUEST §R4.1 |
| F14 | Git Commit & Deployment | Commits with message `feat: implement online streaming API and AVPlayer core` and pushes to `origin main` | M4 | ORIGINAL_REQUEST §R4.2 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Models & Networking Layer | `Soundify/Models/Song.swift`, `Soundify/Services/MusicAPI.swift` | none | DONE |
| M2 | AVPlayer Audio Engine | `Soundify/Managers/AudioManager.swift` | M1 | PENDING |
| M3 | SwiftUI UI & Project PBX | `Soundify/Views/HomeView.swift`, `Soundify/Views/PlayerView.swift`, `Soundify/SoundifyApp.swift`, `Soundify.xcodeproj/project.pbxproj` | M1, M2 | PENDING |
| M4 | Verification & Remote Deployment | `swiftc -parse` validation, `plutil -lint`, git commit and push to `origin main` | M1, M2, M3 | PENDING |

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
- Exclusive File Ownership:
  - M1 Worker exclusively owns:
    - `Soundify/Models/Song.swift`
    - `Soundify/Services/MusicAPI.swift`
  - M2 Worker exclusively owns:
    - `Soundify/Managers/AudioManager.swift`
  - M3 Worker exclusively owns:
    - `Soundify/Views/HomeView.swift`
    - `Soundify/Views/PlayerView.swift`
    - `Soundify/SoundifyApp.swift`
    - `Soundify.xcodeproj/project.pbxproj`
  - M4 Worker exclusively owns:
    - Verification test scripts and git operations
