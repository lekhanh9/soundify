//
//  LyricsService.swift
//  Soundify
//
//  Created for Soundify - Spotify Synced LRC Lyrics Engine.
//

import Foundation

public struct LyricLine: Identifiable, Hashable, Codable {
    public let id: UUID
    public let time: Double
    public let text: String

    public init(id: UUID = UUID(), time: Double, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

public final class LyricsService {
    public static let shared = LyricsService()

    public init() {}

    /// Parses a standard .lrc file format: [mm:ss.xx] Lyric string
    public func parseLRC(_ content: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = content.components(separatedBy: .newlines)

        // Regex matches [mm:ss.xx] or [mm:ss]
        let pattern = "\\[(\\d{2}):(\\d{2})(?:\\.(\\d{1,3}))?\\](.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        for rawLine in rawLines {
            let nsString = rawLine as NSString
            let matches = regex.matches(in: rawLine, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }

                let minutesStr = nsString.substring(with: match.range(at: 1))
                let secondsStr = nsString.substring(with: match.range(at: 2))
                var fraction = 0.0

                if match.range(at: 3).location != NSNotFound {
                    let fracStr = nsString.substring(with: match.range(at: 3))
                    let divisor = pow(10.0, Double(fracStr.count))
                    fraction = (Double(fracStr) ?? 0.0) / divisor
                }

                let minutes = Double(minutesStr) ?? 0.0
                let seconds = Double(secondsStr) ?? 0.0
                let totalSeconds = (minutes * 60.0) + seconds + fraction

                var lyricText = ""
                if match.range(at: 4).location != NSNotFound {
                    lyricText = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                }

                if !lyricText.isEmpty {
                    lines.append(LyricLine(time: totalSeconds, text: lyricText))
                }
            }
        }

        return lines.sorted { $0.time < $1.time }
    }

    /// Finds the index of the currently active lyric line for the given playback time
    public func currentLineIndex(at time: Double, in lyrics: [LyricLine]) -> Int? {
        guard !lyrics.isEmpty else { return nil }
        var activeIndex: Int? = nil

        for (index, line) in lyrics.enumerated() {
            if line.time <= time {
                activeIndex = index
            } else {
                break
            }
        }
        return activeIndex
    }

    /// Provides synced lyrics for a song (returns sample synced LRC lyrics if remote not present)
    public func fetchLyrics(for song: Song) -> [LyricLine] {
        let titleLower = song.title.lowercased()

        if titleLower.contains("midnight") || titleLower.contains("kavinsky") {
            let sampleLRC = """
            [00:04.00] In the dead of night, the city glows
            [00:10.50] Neon lights reflection on the road
            [00:18.00] Electric heartbeat in the open air
            [00:25.50] Speeding through the boulevard of neon stare
            [00:32.00] Midnight echoes calling through the sound
            [00:39.50] Where the lost and dreamers can be found
            [00:48.00] Bassline rumbling under velvet skies
            [00:55.20] Watching midnight shadows in disguise
            [01:04.00] Turn the volume higher, let it fade
            [01:12.50] Into the synthwave symphony we made
            [01:25.00] Forever running till the morning light
            [01:38.00] Soundify will guide us through the night
            """
            return parseLRC(sampleLRC)
        } else if titleLower.contains("cyber") || titleLower.contains("sunset") {
            let sampleLRC = """
            [00:05.00] Golden rays upon the digital horizon
            [00:12.00] Synthetic dreams and endless rising sun
            [00:20.50] Through Shibuya crosswalks moving slow
            [00:28.00] Bathed in ultraviolet afterglow
            [00:36.50] Echoes of the future in our ears
            [00:44.00] Open-source melodies that conquer fears
            [00:53.00] Sunset fades into the cyber sea
            [01:02.00] Pure vibrations setting spirits free
            """
            return parseLRC(sampleLRC)
        } else {
            let genericLRC = """
            [00:02.00] ♪ Instrumental intro playing ♪
            [00:08.50] Rhythms rising in the streaming flow
            [00:16.00] Feel the melody begin to grow
            [00:24.50] Bass and treble moving in control
            [00:32.00] Soundify streaming deep inside your soul
            [00:40.50] Harmonies that carry through the night
            [00:49.00] Every frequency shining bright
            [01:00.00] Seamless audio, crystal clear and wide
            [01:15.00] Open-source player by your side
            [01:30.00] ♪ Instrumental melody outro ♪
            """
            return parseLRC(genericLRC)
        }
    }
}
