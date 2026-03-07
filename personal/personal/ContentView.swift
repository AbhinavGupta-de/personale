//
//  ContentView.swift
//  personal
//
//  Created by Abhinav Gupta on 01/03/26.
//

import SwiftUI

struct ContentView: View {
    #if os(macOS)
    @EnvironmentObject var appTracker: AppTracker
    #endif

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            #if os(macOS)
            Divider()
            Text("Tracking: \(appTracker.currentAppName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif
        }
        .padding()
    }
}
