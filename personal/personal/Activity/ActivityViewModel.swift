#if os(macOS)
import Combine
import Foundation
import SwiftUI

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    @Published var sessions: [FocusSessionResponse] = []
    @Published var selectedSession: FocusSessionResponse?

    private let api = APIClient.shared
    private var cache: [String: [FocusSessionResponse]] = [:]
    private var activeFetchDate: String?

    private static let dateFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private static let displayFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d, yyyy"
        return fmt
    }()

    var dateString: String { Self.dateFmt.string(from: selectedDate) }
    var displayDate: String { Self.displayFmt.string(from: selectedDate) }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    // MARK: - Navigation

    func load() {
        fetchSessions()
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        selectedSession = nil
        navigateToCurrentDate()
    }

    func goToNextDay() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        if tomorrow <= Date() {
            selectedDate = tomorrow
            selectedSession = nil
            navigateToCurrentDate()
        }
    }

    func goToToday() {
        selectedDate = Date()
        selectedSession = nil
        navigateToCurrentDate()
    }

    private func navigateToCurrentDate() {
        let date = dateString
        if let cached = cache[date] {
            sessions = cached
            isLoading = false
        } else {
            sessions = []
            isLoading = true
        }
        fetchSessions()
    }

    private func fetchSessions() {
        let date = dateString
        activeFetchDate = date
        if cache[date] == nil { isLoading = true }

        Task {
            guard let result = try? await api.fetchSessions(date: date),
                activeFetchDate == date
            else { return }
            self.sessions = result
            self.cache[date] = result
            self.isLoading = false
            // Auto-select first session if none selected
            if self.selectedSession == nil, let first = result.first {
                self.selectedSession = first
            }
        }

        // Prefetch adjacent
        for offset in [-1, 1] {
            guard let adjDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate),
                adjDate <= Date()
            else { continue }
            let adjStr = Self.dateFmt.string(from: adjDate)
            guard cache[adjStr] == nil else { continue }
            Task {
                if let r = try? await api.fetchSessions(date: adjStr) {
                    self.cache[adjStr] = r
                }
            }
        }
    }

    // MARK: - Helpers

    func categoryColor(for category: String) -> Color {
        CategoryColors.color(for: category)
    }

    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        if hours > 0 { return "\(hours) hr \(mins) min" }
        return "\(mins) min"
    }

    func parseTimeToHour(_ time: String) -> Double? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
            let h = Double(parts[0]),
            let m = Double(parts[1])
        else { return nil }
        return h + m / 60.0
    }
}
#endif
