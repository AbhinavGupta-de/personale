#if os(macOS)
import Foundation

/// Replaces the Java StatsService + APIClient — all analytics computed locally from SQLite.
final class StatsEngine {
    static let shared = StatsEngine()

    private let db = DatabaseManager.shared

    // In-memory category cache with TTL
    private var categoryCache: [String: String] = [:]
    private var lastCacheLoad: Date?
    private static let cacheTTL: TimeInterval = 300 // 5 minutes

    // Sessions shorter than this are absorbed into their neighbor
    private static let mergeThresholdSeconds: Int = 300 // 5 minutes

    // Gaps longer than this split sessions apart
    private static let gapThresholdSeconds: Int = 600 // 10 minutes

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {}

    // MARK: - Category Resolution

    private func getCategoryCache() -> [String: String] {
        if categoryCache.isEmpty || lastCacheLoad == nil ||
            Date().timeIntervalSince(lastCacheLoad!) > Self.cacheTTL {
            categoryCache = [:]
            let rows = db.query("SELECT bundle_id, category FROM category_mappings")
            for row in rows {
                if let bid = row["bundle_id"] as? String, let cat = row["category"] as? String {
                    categoryCache[bid] = cat
                }
            }
            lastCacheLoad = Date()
        }
        return categoryCache
    }

    /// Invalidates the category cache (called after settings change).
    func invalidateCategoryCache() {
        categoryCache = [:]
        lastCacheLoad = nil
    }

    func resolveCategory(_ bundleId: String?) -> String {
        guard let bid = bundleId else { return "Other" }
        return getCategoryCache()[bid] ?? "Other"
    }

    // MARK: - Internal Types

    private struct RawSession {
        let id: Int
        let appName: String
        let bundleId: String?
        let windowTitle: String?
        let startedAt: Date
        let endedAt: Date? // nil = still active
    }

    private struct Constituent {
        let appName: String
        let bundleId: String?
        let category: String
        let seconds: Int
    }

    private struct MergedBlock {
        let category: String
        let start: Date
        let end: Date
        let seconds: Int
        let label: String
        let constituents: [Constituent]
    }

    private struct DayContext {
        let dateStr: String
        let startOfDay: Date
        let endOfDay: Date
        let sessions: [RawSession]
    }

    // MARK: - Day Context

    private func dayContext(date: String) -> DayContext {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone.current
        let cal = Calendar.current

        let parsedDate = fmt.date(from: date) ?? Date()
        let startOfDay = cal.startOfDay(for: parsedDate)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        let startISO = iso8601.string(from: startOfDay)
        let endISO = iso8601.string(from: endOfDay)

        // Find sessions overlapping this day
        let rows = db.query("""
            SELECT id, app_name, bundle_id, window_title, started_at, ended_at
            FROM app_sessions
            WHERE started_at < ? AND (ended_at IS NULL OR ended_at > ?)
            ORDER BY started_at
        """, params: [endISO, startISO])

        let sessions: [RawSession] = rows.compactMap { row in
            guard let id = row["id"] as? Int,
                  let appName = row["app_name"] as? String,
                  let startStr = row["started_at"] as? String,
                  let start = iso8601.date(from: startStr)
            else { return nil }

            let bundleId = row["bundle_id"] as? String
            let windowTitle = row["window_title"] as? String
            let endedAt: Date? = (row["ended_at"] as? String).flatMap { iso8601.date(from: $0) }

            return RawSession(id: id, appName: appName, bundleId: bundleId,
                              windowTitle: windowTitle, startedAt: start, endedAt: endedAt)
        }

        return DayContext(dateStr: date, startOfDay: startOfDay, endOfDay: endOfDay, sessions: sessions)
    }

    // Clamp session to day window
    private func effectiveStart(_ session: RawSession, startOfDay: Date) -> Date {
        session.startedAt < startOfDay ? startOfDay : session.startedAt
    }

    private func effectiveEnd(_ session: RawSession, endOfDay: Date) -> Date {
        let end = session.endedAt ?? Date()
        return end > endOfDay ? endOfDay : end
    }

    // MARK: - Daily Stats

    func getTimePerApp(date: String) -> DailyStatsResponse {
        let ctx = dayContext(date: date)

        var timeByKey: [String: Int] = [:]
        var nameByKey: [String: String] = [:]
        var bundleByKey: [String: String?] = [:]
        var idleCount = 0

        for session in ctx.sessions {
            let effStart = effectiveStart(session, startOfDay: ctx.startOfDay)
            let effEnd = effectiveEnd(session, endOfDay: ctx.endOfDay)
            let seconds = max(0, Int(effEnd.timeIntervalSince(effStart)))

            let key = session.bundleId ?? session.appName
            timeByKey[key, default: 0] += seconds
            if nameByKey[key] == nil {
                nameByKey[key] = session.appName
                bundleByKey[key] = session.bundleId
            }

            // Count idle sessions (zero-duration closed sessions)
            if let ended = session.endedAt, ended <= session.startedAt {
                idleCount += 1
            }
        }

        let apps = timeByKey
            .sorted { $0.value > $1.value }
            .map { (key, totalSecs) in
                let name = nameByKey[key] ?? key
                let bid = name == key ? nil : bundleByKey[key] ?? nil
                return AppTimeEntry(appName: name, bundleId: bid, totalSeconds: totalSecs)
            }

        let total = apps.reduce(0) { $0 + $1.totalSeconds }
        return DailyStatsResponse(date: ctx.dateStr, apps: apps, totalTrackedSeconds: total, idleSessionCount: idleCount)
    }

    // MARK: - Focus Session Merging

    private func buildMergedSessions(_ ctx: DayContext) -> [MergedBlock] {
        let raw: [MergedBlock] = ctx.sessions.compactMap { session in
            let effStart = effectiveStart(session, startOfDay: ctx.startOfDay)
            let effEnd = effectiveEnd(session, endOfDay: ctx.endOfDay)
            let secs = max(0, Int(effEnd.timeIntervalSince(effStart)))
            guard secs > 0 else { return nil }

            let cat = resolveCategory(session.bundleId)
            let constituent = Constituent(appName: session.appName, bundleId: session.bundleId,
                                          category: cat, seconds: secs)
            return MergedBlock(category: cat, start: effStart, end: effEnd, seconds: secs,
                               label: session.appName, constituents: [constituent])
        }
        .sorted { $0.start < $1.start }

        if raw.count <= 1 { return raw }

        var merged = mergeAdjacentSameCategory(raw)
        merged = absorbSmallBlocks(merged)
        return mergeAdjacentSameCategory(merged)
    }

    private func mergeAdjacentSameCategory(_ blocks: [MergedBlock]) -> [MergedBlock] {
        guard !blocks.isEmpty else { return blocks }
        var result: [MergedBlock] = []
        var current = blocks[0]

        for i in 1..<blocks.count {
            let next = blocks[i]
            let gap = Int(next.start.timeIntervalSince(current.end))

            if next.category == current.category && gap < Self.gapThresholdSeconds {
                let combined = current.constituents + next.constituents
                current = MergedBlock(
                    category: current.category,
                    start: current.start,
                    end: next.end,
                    seconds: current.seconds + next.seconds,
                    label: current.label,
                    constituents: combined
                )
            } else {
                result.append(current)
                current = next
            }
        }
        result.append(current)
        return result
    }

    private func absorbSmallBlocks(_ blocks: [MergedBlock]) -> [MergedBlock] {
        if blocks.count <= 1 { return blocks }
        var result = blocks
        var changed = true

        while changed {
            changed = false
            for i in 0..<result.count {
                let block = result[i]
                guard block.seconds < Self.mergeThresholdSeconds && result.count > 1 else { continue }

                // Find a neighbor within gap threshold
                var target = -1
                if i > 0 {
                    let gap = Int(block.start.timeIntervalSince(result[i - 1].end))
                    if gap < Self.gapThresholdSeconds { target = i - 1 }
                }
                if target == -1 && i + 1 < result.count {
                    let gap = Int(result[i + 1].start.timeIntervalSince(block.end))
                    if gap < Self.gapThresholdSeconds { target = i + 1 }
                }
                guard target != -1 else { continue }

                let neighbor = result[target]
                let mergedStart = neighbor.start < block.start ? neighbor.start : block.start
                let mergedEnd = neighbor.end > block.end ? neighbor.end : block.end
                let combined = neighbor.constituents + block.constituents
                let dominant = dominantCategory(combined)

                result[target] = MergedBlock(
                    category: dominant,
                    start: mergedStart,
                    end: mergedEnd,
                    seconds: neighbor.seconds + block.seconds,
                    label: neighbor.label,
                    constituents: combined
                )
                result.remove(at: i)
                changed = true
                break
            }
        }
        return result
    }

    private func dominantCategory(_ constituents: [Constituent]) -> String {
        var timeByCategory: [String: Int] = [:]
        for c in constituents {
            timeByCategory[c.category, default: 0] += c.seconds
        }
        return timeByCategory.max(by: { $0.value < $1.value })?.key ?? "Other"
    }

    // MARK: - Timeline

    func getTimeline(date: String) -> [TimelineEntryResponse] {
        let ctx = dayContext(date: date)
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone.current

        return buildMergedSessions(ctx).map { block in
            TimelineEntryResponse(
                startTime: fmt.string(from: block.start),
                endTime: fmt.string(from: block.end),
                appName: block.label,
                bundleId: nil,
                category: block.category
            )
        }
    }

    // MARK: - Activity Log

    func getActivityLog(date: String) -> [ActivityLogEntryResponse] {
        let ctx = dayContext(date: date)
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        fmt.timeZone = TimeZone.current

        return ctx.sessions.compactMap { session in
            let effStart = effectiveStart(session, startOfDay: ctx.startOfDay)
            let effEnd = effectiveEnd(session, endOfDay: ctx.endOfDay)
            let secs = max(0, Int(effEnd.timeIntervalSince(effStart)))
            guard secs > 0 else { return nil }

            let detail = session.windowTitle ?? resolveCategory(session.bundleId)
            return ActivityLogEntryResponse(
                time: fmt.string(from: effStart),
                appName: session.appName,
                bundleId: session.bundleId,
                detail: detail,
                durationSeconds: secs
            )
        }
        .sorted { $0.time < $1.time }
    }

    // MARK: - Workblocks

    func getWorkblocks(date: String) -> [WorkblockEntryResponse] {
        let ctx = dayContext(date: date)
        let fmt = DateFormatter()
        fmt.dateFormat = "H:mm"
        fmt.timeZone = TimeZone.current

        return buildMergedSessions(ctx).map { block in
            WorkblockEntryResponse(
                time: fmt.string(from: block.start),
                task: block.category,
                duration: formatDuration(block.seconds),
                durationSeconds: block.seconds
            )
        }
    }

    // MARK: - Focus Sessions

    func getFocusSessions(date: String) -> [FocusSessionResponse] {
        let ctx = dayContext(date: date)
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone.current

        return buildMergedSessions(ctx).map { block in
            // Per-app breakdown
            var appTime: [String: Int] = [:]
            var appBundle: [String: String?] = [:]
            var appCategory: [String: String] = [:]

            for c in block.constituents {
                let key = c.bundleId ?? c.appName
                appTime[key, default: 0] += c.seconds
                if appBundle[key] == nil {
                    appBundle[key] = c.bundleId
                    appCategory[key] = c.category
                }
            }

            let apps = appTime.sorted { $0.value > $1.value }.map { (key, secs) in
                let pct = block.seconds > 0 ? Int(round(Double(secs) * 100.0 / Double(block.seconds))) : 0
                let name = block.constituents.first(where: {
                    ($0.bundleId ?? $0.appName) == key
                })?.appName ?? key
                return SessionAppBreakdownResponse(
                    appName: name,
                    bundleId: appBundle[key] ?? nil,
                    category: appCategory[key] ?? "Other",
                    totalSeconds: secs,
                    percent: pct
                )
            }

            // Per-category breakdown within this session
            var catTime: [String: Int] = [:]
            for c in block.constituents {
                catTime[c.category, default: 0] += c.seconds
            }
            let categories = catTime.sorted { $0.value > $1.value }.map { (cat, secs) in
                let pct = block.seconds > 0 ? Int(round(Double(secs) * 100.0 / Double(block.seconds))) : 0
                return CategoryBreakdownResponse(category: cat, totalSeconds: secs, percent: pct)
            }

            return FocusSessionResponse(
                name: block.category,
                startTime: fmt.string(from: block.start),
                endTime: fmt.string(from: block.end),
                durationSeconds: block.seconds,
                duration: formatDuration(block.seconds),
                apps: apps,
                categories: categories
            )
        }
    }

    // MARK: - Category Breakdown

    func getCategoryBreakdown(date: String) -> [CategoryBreakdownResponse] {
        let ctx = dayContext(date: date)
        var timeByCategory: [String: Int] = [:]

        for session in ctx.sessions {
            let effStart = effectiveStart(session, startOfDay: ctx.startOfDay)
            let effEnd = effectiveEnd(session, endOfDay: ctx.endOfDay)
            let seconds = max(0, Int(effEnd.timeIntervalSince(effStart)))
            guard seconds > 0 else { continue }

            let category = resolveCategory(session.bundleId)
            timeByCategory[category, default: 0] += seconds
        }

        let total = timeByCategory.values.reduce(0, +)
        return timeByCategory
            .sorted { $0.value > $1.value }
            .map { (cat, secs) in
                let pct = total > 0 ? Int(round(Double(secs) * 100.0 / Double(total))) : 0
                return CategoryBreakdownResponse(category: cat, totalSeconds: secs, percent: pct)
            }
    }

    // MARK: - Helpers

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 { return "\(hours) hr \(minutes) min" }
        return "\(minutes) min"
    }
}
#endif
