#if os(macOS)
import Foundation

// MARK: - Mock Data (from dashboard-designs/frontend/src/data/mockData.js)

enum MockData {
    struct TimelineBlock {
        let start: Double  // hour as decimal (e.g., 8.5 = 8:30)
        let end: Double
        let type: String
        let label: String
    }

    struct WorkHours {
        let totalWorked: String
        let percentOfDay: Double
        let targetHours: String
        let trackingOn: Bool
        let trackingHours: String
    }

    struct BreakTimer {
        let timeSinceBreak: String
        let breakToWorkRatio: String
        let notificationsOn: Bool
        let threshold: String
    }

    struct Workblock {
        let time: String
        let task: String
        let duration: String
        let score: Double?
    }

    struct ActivityEntry {
        let time: String
        let app: String
        let detail: String
    }

    struct Project {
        let name: String
        let percent: Int
        let time: String
        let color: String  // hex string
    }

    struct ScoreSet {
        let focus: Score
        let communication: Score
        let other: Score
    }

    struct Score {
        let percent: Int
        let time: String
    }

    struct TimeBreakdownEntry {
        let category: String
        let percent: Int
        let time: String
        let colorHex: UInt
    }

    static let date = "Friday, January 29, 2021"

    static let workHours = WorkHours(
        totalWorked: "7 hr 51 min",
        percentOfDay: 98.1,
        targetHours: "8 hr 0 min",
        trackingOn: true,
        trackingHours: "8:00 - 18:00"
    )

    static let breakTimer = BreakTimer(
        timeSinceBreak: "0:42:35",
        breakToWorkRatio: "1 / 3.6",
        notificationsOn: true,
        threshold: "40 min"
    )

    static let timeline: [TimelineBlock] = [
        .init(start: 8, end: 8.5, type: "meeting", label: "Stand-Up"),
        .init(start: 8.5, end: 9, type: "email", label: "Email"),
        .init(start: 9, end: 10.5, type: "coding", label: "Code"),
        .init(start: 10.5, end: 11, type: "break", label: "Break"),
        .init(start: 11, end: 12.5, type: "coding", label: "Code"),
        .init(start: 12.5, end: 13, type: "break", label: "Lunch"),
        .init(start: 13, end: 14.5, type: "design", label: "Design"),
        .init(start: 14.5, end: 15.5, type: "coding", label: "Code"),
        .init(start: 15.5, end: 16, type: "meeting", label: "Meeting"),
        .init(start: 16, end: 17, type: "coding", label: "Code"),
        .init(start: 17, end: 17.5, type: "writing", label: "Docs"),
    ]

    static let workblocks: [Workblock] = [
        .init(time: "9:00", task: "Daily Stand-Up", duration: "32 min", score: nil),
        .init(time: "10:03", task: "Code", duration: "1 hr 10 min", score: 97.3),
        .init(time: "11:24", task: "Documentation", duration: "34 min", score: 88.9),
        .init(time: "12:57", task: "Design", duration: "45 min", score: 94.4),
        .init(time: "13:49", task: "Code", duration: "23 min", score: 95.1),
        .init(time: "14:45", task: "Code", duration: "20 min", score: 96.8),
        .init(time: "16:05", task: "Investor Meeting", duration: "42 min", score: nil),
        .init(time: "17:10", task: "Documentation", duration: "39 min", score: 96.2),
    ]

    static let activityLog: [ActivityEntry] = [
        .init(time: "18:04:33", app: "Chrome", detail: "twitter.com/home"),
        .init(time: "18:01:15", app: "Superhuman", detail: "Inbox - unread"),
        .init(time: "18:01:10", app: "Airtable", detail: "Tasks"),
        .init(time: "18:00:03", app: "Slack", detail: "General"),
        .init(time: "17:57:29", app: "Superhuman", detail: "Inbox - unread"),
        .init(time: "17:56:14", app: "Chrome", detail: "rize.io/settings/notific..."),
        .init(time: "17:53:01", app: "Chrome", detail: "rize.io/settings"),
        .init(time: "17:53:12", app: "Slack", detail: "Product Team"),
        .init(time: "17:49:58", app: "Sketch", detail: "Rize (Master)"),
        .init(time: "17:49:40", app: "Webstorm", detail: "product.js"),
        .init(time: "17:49:15", app: "Sketch", detail: "Rize (Master)"),
        .init(time: "17:47:21", app: "Webstorm", detail: "index.js"),
        .init(time: "17:35:14", app: "Sketch", detail: "Rize (Master)"),
    ]

    static let projects: [Project] = [
        .init(name: "MVP Release", percent: 45, time: "2 hr 46 min", color: "purple"),
        .init(name: "Bugs & Fixes", percent: 10, time: "40 min", color: "pink"),
        .init(name: "Launch Campaign", percent: 8, time: "32 min", color: "teal"),
    ]

    static let scores = ScoreSet(
        focus: .init(percent: 60, time: "3 hr 43 min"),
        communication: .init(percent: 12, time: "55 min"),
        other: .init(percent: 18, time: "1 hr 24 min")
    )

    static let timeBreakdown: [TimeBreakdownEntry] = [
        .init(category: "Code", percent: 45, time: "2 hr 46 min", colorHex: 0x7C5CFC),
        .init(category: "Meetings", percent: 15, time: "1 hr 25 min", colorHex: 0xD64D8A),
        .init(category: "Documentation", percent: 13, time: "1 hr 15 min", colorHex: 0x35A882),
        .init(category: "Design", percent: 10, time: "45 min", colorHex: 0x00CCBF),
        .init(category: "Messaging", percent: 5, time: "23 min", colorHex: 0x9B85F5),
        .init(category: "Email", percent: 4, time: "20 min", colorHex: 0xF5A623),
        .init(category: "Task Management", percent: 2, time: "11 min", colorHex: 0x3B82F6),
        .init(category: "Productivity", percent: 2, time: "10 min", colorHex: 0x6B7280),
        .init(category: "Miscellaneous", percent: 1, time: "4 min", colorHex: 0x3D4451),
    ]
}
#endif
