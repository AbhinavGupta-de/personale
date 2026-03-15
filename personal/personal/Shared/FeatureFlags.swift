#if os(macOS)

// MARK: - Sidebar Feature Flags

enum SidebarFeatures {
    static let showActivity = false       // M3
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
    static let showBreakTimer = true      // M5 (showing with mock data)
    static let showWorkblocks = true      // M3/M4 (showing with mock data)
    static let showScores = true          // M4 (showing with mock data)
    static let showProjects = false       // deferred (no product logic yet)
}
#endif
