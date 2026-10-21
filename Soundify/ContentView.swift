//
//  ContentView.swift
//  Soundify
//
//  Created for Soundify - Spotify Root Navigation & Tab Experience.
//

import SwiftUI

public struct ContentView: View {
    @EnvironmentObject public var audioManager: AudioManager
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                    }
                    .tag(0)

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)

                LibraryView()
                    .tabItem {
                        Label("Your Library", systemImage: selectedTab == 2 ? "books.vertical.fill" : "books.vertical")
                    }
                    .tag(2)
            }
            .preferredColorScheme(.dark)
            .accentColor(Color.white)

            // When user is on Search (1) or Library (2), render MiniPlayer above the tab bar if playing
            if selectedTab != 0, audioManager.currentSong != nil {
                MiniPlayerBar()
                    .padding(.bottom, 54) // right above iOS Tab Bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AudioManager())
    }
}
#endif
