//
//  ContentView.swift
//  Soundify
//
//  Created for Soundify online music streaming and AVPlayer engine.
//

import SwiftUI

public struct ContentView: View {
    @EnvironmentObject public var audioManager: AudioManager
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            searchView
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            libraryView
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(2)
        }
        .preferredColorScheme(.dark)
        .accentColor(Color(red: 0.11, green: 0.84, blue: 0.38))
    }

    private var searchView: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(Color.gray)

                Text("Search")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Find songs, artists, and podcasts")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }

    private var libraryView: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.gray)

                Text("Your Library")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Your playlists, saved tracks, and artists will appear here")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
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
