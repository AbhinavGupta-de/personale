#if os(macOS)
import SwiftUI

struct CalendarColumn: View {
    let events: [CalendarEvent]
    let date: Date
    let dayStartHour: Int
    let hourHeight: CGFloat
    let isEnabled: Bool
    let isAuthorized: Bool
    let accessDenied: Bool

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    private func yOffset(_ hour: Double) -> CGFloat {
        let shifted = (hour - Double(dayStartHour) + 24).truncatingRemainder(dividingBy: 24)
        return CGFloat(shifted) * hourHeight
    }

    var body: some View {
        if !isEnabled {
            PlaceholderColumn(title: "Calendar", icon: "calendar", hourHeight: hourHeight)
        } else if accessDenied {
            stateColumn {
                Text("Calendar access denied — open System Settings")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground.opacity(0.7))
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        openURL(url)
                    }
                } label: {
                    Text("Open System Settings")
                        .font(AppFont.text(FontSize.sm, .semibold))
                        .foregroundStyle(theme.primary)
                }
                .buttonStyle(.plain)
            }
        } else if isAuthorized && events.isEmpty {
            stateColumn {
                Text("No events")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground.opacity(0.7))
            }
        } else if isAuthorized {
            eventsColumn
        } else {
            PlaceholderColumn(title: "Calendar", icon: "calendar", hourHeight: hourHeight)
        }
    }

    private var eventsColumn: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.clear).frame(height: 24 * hourHeight)

            ForEach(events) { event in
                if let layout = layout(for: event) {
                    eventBlock(event)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: max(layout.height, Spacing.space1))
                        .offset(y: layout.top)
                        .padding(.horizontal, Spacing.space1)
                }
            }
        }
    }

    private func eventBlock(_ event: CalendarEvent) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(event.color.opacity(0.5))
            Text(event.title)
                .font(AppFont.text(FontSize.sm, .semibold))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
                .padding(.horizontal, Spacing.space3)
                .padding(.vertical, Spacing.space1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .help("\(event.title) · \(event.calendarName)")
    }

    @ViewBuilder
    private func stateColumn<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Rectangle().fill(Color.clear).frame(height: 24 * hourHeight)
            VStack(spacing: Spacing.space2) {
                content()
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func layout(for event: CalendarEvent) -> (top: CGFloat, height: CGFloat)? {
        guard let window = dayWindow else { return nil }
        let visibleStart = max(event.start, window.start)
        let visibleEnd = min(event.end, window.end)
        guard visibleEnd > visibleStart else { return nil }

        let top = yOffset(hourValue(for: visibleStart))
        let height = CGFloat(visibleEnd.timeIntervalSince(visibleStart) / 3600) * hourHeight
        return (top, height)
    }

    private var dayWindow: (start: Date, end: Date)? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .hour, value: dayStartHour, to: startOfDay),
              let end = calendar.date(byAdding: .hour, value: 24, to: start)
        else { return nil }
        return (start, end)
    }

    private func hourValue(for date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0) / 60
        let second = Double(components.second ?? 0) / 3600
        return hour + minute + second
    }
}
#endif
