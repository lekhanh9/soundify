//
//  AudioManager.swift
//  Soundify
//
//  Created for Soundify - Spotify & Open-Source AVPlayer Audio Engine.
//

import Foundation
import AVFoundation
import Combine
#if canImport(MediaPlayer)
import MediaPlayer
#endif

public final class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published public var currentSong: Song?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var playlist: [Song] = []
    @Published public var isPlayerPresented: Bool = false

    // MARK: - Open-Source & Spotify Enhancements
    @Published public var isShuffle: Bool = false
    @Published public var repeatMode: RepeatMode = .off
    @Published public var queue: [Song] = []
    @Published public var likedSongIDs: Set<String> = []

    // MARK: - Internal Player & Observers
    private var player: AVPlayer = AVPlayer()
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    private var originalPlaylist: [Song] = []

    // MARK: - Initialization & Deinitialization
    public init() {
        configureAudioSession()
        setupPeriodicTimeObserver()
        setupRemoteCommands()
    }

    deinit {
        removePeriodicTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - Periodic Time Observer
    private func setupPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = time.seconds
            if seconds.isFinite && !seconds.isNaN {
                self.currentTime = seconds
            }
            if let item = self.player.currentItem {
                let itemDuration = item.duration.seconds
                if itemDuration.isFinite && !itemDuration.isNaN && itemDuration > 0 {
                    self.duration = itemDuration
                }
            }
            self.updateNowPlayingPlaybackInfo()
        }
    }

    private func removePeriodicTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    // MARK: - Playlist Loading
    public func loadPlaylist() async {
        do {
            let songs = try await MusicAPI.shared.fetchTrendingSongs()
            await MainActor.run {
                self.playlist = songs
                self.originalPlaylist = songs
                if self.currentSong == nil, let first = songs.first {
                    self.currentSong = first
                    self.duration = first.duration
                    self.currentTime = 0.0
                }
            }
        } catch {
            print("Failed to load playlist: \(error)")
        }
    }

    // MARK: - Playback Control
    private func playSong(_ song: Song, forceRestart: Bool = false) {
        let isDifferentSong = (self.currentSong?.id != song.id)
        if isDifferentSong || player.currentItem == nil || forceRestart {
            self.currentSong = song
            self.duration = song.duration
            self.currentTime = 0.0

            guard let url = URL(string: song.streamURL) else {
                print("Invalid streaming URL: \(song.streamURL)")
                return
            }

            let item = AVPlayerItem(url: url)
            self.playerItem = item

            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerItemDidReachEnd(_:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: item
            )

            player.replaceCurrentItem(with: item)
            updateNowPlayingMetadata(for: song)
        }

        player.play()
        self.isPlaying = true
        updateNowPlayingPlaybackInfo()
    }

    public func play(song: Song) {
        playSong(song, forceRestart: false)
    }

    public func play() {
        if let currentSong = currentSong {
            play(song: currentSong)
        } else if let firstSong = playlist.first {
            play(song: firstSong)
        }
    }

    public func pause() {
        player.pause()
        self.isPlaying = false
        updateNowPlayingPlaybackInfo()
    }

    public func playPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func togglePlayPause() {
        playPause()
    }

    public func next() {
        // 1. If queue has items, consume top of queue
        if !queue.isEmpty {
            let nextSong = queue.removeFirst()
            playSong(nextSong, forceRestart: true)
            return
        }

        guard !playlist.isEmpty else {
            currentSong = nil
            isPlaying = false
            currentTime = 0.0
            duration = 0.0
            return
        }

        if isShuffle && playlist.count > 1 {
            let available = playlist.filter { $0.id != currentSong?.id }
            if let randomSong = available.randomElement() {
                playSong(randomSong, forceRestart: true)
                return
            }
        }

        if let current = currentSong,
           let index = playlist.firstIndex(where: { $0.id == current.id }) {
            let isLast = (index == playlist.count - 1)
            if isLast && repeatMode == .off {
                // End of playlist and repeat is off
                pause()
                seek(to: 0.0)
                return
            }

            let nextIndex = (index + 1) % playlist.count
            let nextSong = playlist[nextIndex]
            if playlist.count == 1 {
                seek(to: 0.0)
                player.play()
                self.isPlaying = true
            } else {
                playSong(nextSong, forceRestart: true)
            }
        } else if let first = playlist.first {
            playSong(first, forceRestart: true)
        }
    }

    public func previous() {
        guard !playlist.isEmpty else {
            currentSong = nil
            isPlaying = false
            currentTime = 0.0
            duration = 0.0
            return
        }

        if currentTime > 3.0 {
            seek(to: 0.0)
            return
        }

        if let current = currentSong,
           let index = playlist.firstIndex(where: { $0.id == current.id }) {
            let prevIndex = (index - 1 + playlist.count) % playlist.count
            let prevSong = playlist[prevIndex]
            if playlist.count == 1 {
                seek(to: 0.0)
                player.play()
                self.isPlaying = true
            } else {
                playSong(prevSong, forceRestart: true)
            }
        } else if let first = playlist.first {
            playSong(first, forceRestart: true)
        }
    }

    public func seek(to seconds: Double) {
        guard duration > 0.0 else {
            currentTime = 0.0
            return
        }
        let clamped = max(0.0, min(seconds, duration))
        self.currentTime = clamped
        let targetTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingPlaybackInfo()
    }

    public func seek(progress: Double) {
        let clampedProgress = max(0.0, min(progress, 1.0))
        seek(to: clampedProgress * duration)
    }

    // MARK: - Spotify & Open-Source Queue / Shuffle / Repeat Controls

    public func toggleShuffle() {
        isShuffle.toggle()
        if isShuffle {
            var shuffled = playlist
            if let current = currentSong {
                shuffled.removeAll(where: { $0.id == current.id })
                shuffled.shuffle()
                playlist = [current] + shuffled
            } else {
                playlist.shuffle()
            }
        } else {
            playlist = originalPlaylist
        }
    }

    public func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }

    public func toggleLike(song: Song) {
        if likedSongIDs.contains(song.id) {
            likedSongIDs.remove(song.id)
        } else {
            likedSongIDs.insert(song.id)
        }
    }

    public func isLiked(song: Song) -> Bool {
        return likedSongIDs.contains(song.id)
    }

    public func addToQueue(song: Song) {
        queue.append(song)
    }

    public func playNext(song: Song) {
        queue.insert(song, at: 0)
    }

    public func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index) else { return }
        queue.remove(at: index)
    }

    public func clearQueue() {
        queue.removeAll()
    }

    // MARK: - Notifications
    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        if repeatMode == .one {
            seek(to: 0.0)
            player.play()
            self.isPlaying = true
        } else {
            next()
        }
    }

    // MARK: - Lock Screen & Control Center Integration (MPNowPlayingInfoCenter)
    private func setupRemoteCommands() {
        #if canImport(MediaPlayer)
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: positionEvent.positionTime)
            return .success
        }
        #endif
    }

    private func updateNowPlayingMetadata(for song: Song) {
        #if canImport(MediaPlayer)
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        #endif
    }

    private func updateNowPlayingPlaybackInfo() {
        #if canImport(MediaPlayer)
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        #endif
    }

    // MARK: - Compatibility Helpers & Formatter
    public var playbackProgress: Double {
        get {
            guard duration > 0.0 else { return 0.0 }
            return min(max(currentTime / duration, 0.0), 1.0)
        }
        set {
            seek(progress: newValue)
        }
    }

    public func formatTime(_ time: Double) -> String {
        guard time.isFinite && !time.isNaN else { return "00:00" }
        let totalSeconds = Int(max(0.0, time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public func formatRemainingTime() -> String {
        guard duration > 0.0 else { return "-00:00" }
        let remaining = max(0.0, duration - currentTime)
        return "-\(formatTime(remaining))"
    }
}
