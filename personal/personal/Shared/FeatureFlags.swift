#if os(macOS)

// MARK: - Sidebar Feature Flags

enum SidebarFeatures {
    static let showActivity = true        // M3
    static let showFocus = false          // M4
    static let showGoals = false          // deferred
    static let showCalendar = false       // deferred
    static let showTasks = false          // deferred
    static let showHabits = false         // deferred
    static let showProductivity = false   // M4
    static let showTeam = false           // M9
}

// MARK: - Dashboard Feature Flags

enum DashboardFeatures {
    static let showBreakTimer = false     // M5 (no backend yet)
    static let showWorkblocks = true      // M3 (wired to real data)
    static let showScores = false         // M4 (no backend yet)
    static let showProjects = false       // deferred (no product logic yet)
}
#endif
