//
//  SoundifyApp.swift
//  Soundify
//
//  Created for Soundify online music streaming and AVPlayer engine.
//

import SwiftUI

@main
public struct SoundifyApp: App {
    @StateObject private var audioManager = AudioManager()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(audioManager)
                .preferredColorScheme(.dark)
        }
    }
}
