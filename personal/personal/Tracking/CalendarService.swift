#if os(macOS)
import Combine
import EventKit
import SwiftUI

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let calendarName: String
    let color: Color
    let isAllDay: Bool
}

@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()

    @Published var authStatus: EKAuthorizationStatus

    var hasFullAccess: Bool {
        authStatus == .fullAccess
    }

    var isAccessDenied: Bool {
        authStatus == .denied || authStatus == .restricted
    }

    private init() {
        self.authStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            authStatus = EKEventStore.authorizationStatus(for: .event)
            return false
        }
    }

    func events(forDay date: Date, dayStartHour: Int) -> [CalendarEvent] {
        guard hasFullAccess else { return [] }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let windowStart = calendar.date(byAdding: .hour, value: dayStartHour, to: dayStart),
              let windowEnd = calendar.date(byAdding: .hour, value: 24, to: windowStart)
        else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: windowStart,
            end: windowEnd,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? fallbackID(for: event),
                    title: event.title ?? "Untitled",
                    start: event.startDate,
                    end: event.endDate,
                    calendarName: event.calendar.title,
                    color: Color(cgColor: event.calendar.cgColor),
                    isAllDay: event.isAllDay
                )
            }
    }

    private func fallbackID(for event: EKEvent) -> String {
        "\(event.startDate.timeIntervalSinceReferenceDate)-\(event.endDate.timeIntervalSinceReferenceDate)-\(event.title ?? "")"
    }
}
#endif
