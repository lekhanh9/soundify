import SwiftUI

@main
public struct SoundifyApp: App {
    @StateObject private var musicManager = MusicManager()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(musicManager)
                .preferredColorScheme(.dark)
        }
    }
}
