//
//  personalApp.swift
//  personal
//
//  Created by Abhinav Gupta on 01/03/26.
//

import SwiftUI

@main
struct personalApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appTracker = AppTracker()
    #endif

    init() {
        #if os(macOS)
        // Touch singletons to initialize database and session store on launch
        _ = DatabaseManager.shared
        _ = SessionStore.shared
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            AppShell()
                .environmentObject(appTracker)
            #else
            Text("Personale")
            #endif
        }

        #if os(macOS)
        MenuBarExtra("Personale", systemImage: "clock.fill") {
            MenuBarView()
                .environmentObject(appTracker)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
#endif
