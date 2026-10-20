import SwiftUI

public struct TrackRowView: View {
    public let track: Track
    public let isCurrent: Bool
    public let isPlaying: Bool
    public var onSelect: (() -> Void)?

    public init(
        track: Track,
        isCurrent: Bool = false,
        isPlaying: Bool = false,
        onSelect: (() -> Void)? = nil
    ) {
        self.track = track
        self.isCurrent = isCurrent
        self.isPlaying = isPlaying
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: {
            onSelect?()
        }) {
            HStack(spacing: 14) {
                // Artwork thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: track.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: isCurrent && isPlaying ? "speaker.wave.3.fill" : track.coverIconName)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isCurrent ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(Color.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Mini Waveform
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<12, id: \.self) { i in
                        let sample = track.waveformSamples[i % track.waveformSamples.count]
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isCurrent && isPlaying ? Color(red: 1.0, green: 0.35, blue: 0.0) : Color.white.opacity(0.2))
                            .frame(width: 2.5, height: max(4, sample * 24))
                    }
                }
                .frame(width: 40, height: 26)

                // More button
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(Color.gray)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(isCurrent ? Color.white.opacity(0.05) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
