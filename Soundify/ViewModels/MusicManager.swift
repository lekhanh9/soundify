import Foundation
import SwiftUI
import Combine

public final class MusicManager: ObservableObject {
    @Published public var currentTrack: Track?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0.0
    @Published public var duration: TimeInterval = 214.0
    @Published public var isPlayerPresented: Bool = false
    @Published public var queue: [Track] = Track.sampleTracks

    private var timer: Timer?

    public init(currentTrack: Track? = Track.sampleTracks.first) {
        self.currentTrack = currentTrack
        if let track = currentTrack {
            self.duration = track.duration
        }
    }

    public var playbackProgress: Double {
        get {
            guard duration > 0 else { return 0 }
            return currentTime / duration
        }
        set {
            seek(to: newValue * duration)
        }
    }

    public func play(track: Track? = nil) {
        if let track = track {
            self.currentTrack = track
            self.duration = track.duration
            self.currentTime = 0.0
        }
        self.isPlaying = true
        startMockPlaybackTimer()
    }

    public func pause() {
        self.isPlaying = false
        stopMockPlaybackTimer()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func next() {
        guard !queue.isEmpty else { return }
        if let current = currentTrack,
           let index = queue.firstIndex(of: current) {
            let nextIndex = (index + 1) % queue.count
            play(track: queue[nextIndex])
        } else {
            play(track: queue.first)
        }
    }

    public func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3.0 {
            seek(to: 0.0)
            return
        }
        if let current = currentTrack,
           let index = queue.firstIndex(of: current) {
            let prevIndex = (index - 1 + queue.count) % queue.count
            play(track: queue[prevIndex])
        } else {
            play(track: queue.first)
        }
    }

    public func seek(to time: TimeInterval) {
        self.currentTime = max(0, min(time, duration))
    }

    public func seek(progress: Double) {
        self.seek(to: progress * duration)
    }

    public func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startMockPlaybackTimer() {
        stopMockPlaybackTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            if self.currentTime < self.duration {
                self.currentTime += 0.5
            } else {
                self.next()
            }
        }
    }

    private func stopMockPlaybackTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopMockPlaybackTimer()
    }
}
