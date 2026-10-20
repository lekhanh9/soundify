import SwiftUI

public struct WaveformView: View {
    public let samples: [CGFloat]
    public let progress: Double
    public var onSeek: ((Double) -> Void)?

    public init(
        samples: [CGFloat] = Track.generateDummyWaveform(),
        progress: Double = 0.35,
        onSeek: ((Double) -> Void)? = nil
    ) {
        self.samples = samples
        self.progress = max(0, min(1, progress))
        self.onSeek = onSeek
    }

    public var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            let count = max(1, samples.count)
            let barSpacing: CGFloat = 3.0
            let barWidth = max(2.0, (totalWidth - CGFloat(count - 1) * barSpacing) / CGFloat(count))

            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<samples.count, id: \.self) { index in
                    let sampleHeight = max(6.0, samples[index] * totalHeight)
                    let barProgress = Double(index) / Double(count)
                    let isPlayed = barProgress <= progress

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            isPlayed
                                ? LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.33, blue: 0.0), Color(red: 1.0, green: 0.55, blue: 0.0)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color.white.opacity(0.15)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                        )
                        .frame(width: barWidth, height: sampleHeight)
                }
            }
            .frame(width: totalWidth, height: totalHeight, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let locationX = max(0, min(value.location.x, totalWidth))
                        let newProgress = Double(locationX / totalWidth)
                        onSeek?(newProgress)
                    }
            )
        }
        .frame(height: 48)
    }
}
