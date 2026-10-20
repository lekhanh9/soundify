import SwiftUI

public struct PlaylistCardView: View {
    public let playlist: Playlist
    public var onSelect: (() -> Void)?

    public init(playlist: Playlist, onSelect: (() -> Void)? = nil) {
        self.playlist = playlist
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: {
            onSelect?()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: playlist.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 150, height: 150)
                        .overlay(
                            Image(systemName: playlist.iconName)
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        )

                    // Mini play badge
                    Circle()
                        .fill(Color(red: 0.11, green: 0.84, blue: 0.38)) // Spotify green
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .padding(10)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(playlist.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.gray)
                        .lineLimit(2)
                }
                .frame(width: 150, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
