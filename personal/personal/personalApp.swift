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

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            AppShell()
                .environmentObject(appTracker)
                .onAppear {
                    DistractionBlockerService.shared.wire(
                        appTracker: appTracker,
                        pomodoro: PomodoroViewModel.shared
                    )
                    BreakDetectionService.shared.wire(appTracker: appTracker)
                    DailyRecapService.shared.start()
                    EyeStrainNudgeService.shared.wire(
                        appTracker: appTracker,
                        pomodoro: PomodoroViewModel.shared
                    )
                    SafariBrowserCapture.shared.wire(appTracker: appTracker)
                }
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
