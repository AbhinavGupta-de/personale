#if os(macOS)
import SwiftUI

struct WeekActivityColumn: View {
    let date: Date
    let sessions: [FocusSessionResponse]
    let dayStartHour: Int
    let hourHeight: CGFloat
    let parseTime: (String) -> Double?
    let categoryColor: (String) -> Color
    let formatDuration: (Int) -> String
    @Binding var selectedSession: FocusSessionResponse?

    @Environment(\.theme) private var theme

    private static let dayNameFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "E"; return f
    }()

    private static let dayNumFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private func yOffset(_ hour: Double) -> CGFloat {
        let shifted = (hour - Double(dayStartHour) + 24).truncatingRemainder(dividingBy: 24)
        return CGFloat(shifted) * hourHeight
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            VStack(spacing: 2) {
                Text(Self.dayNameFmt.string(from: date))
                    .font(AppFont.text(FontSize.xs, .medium))
                    .foregroundStyle(theme.mutedForeground)
                Text(Self.dayNumFmt.string(from: date))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isToday ? theme.primary : theme.foreground)
                    .frame(width: 28, height: 28)
                    .background(isToday ? theme.primary.opacity(0.12) : Color.clear)
                    .clipShape(Circle())
            }
            .frame(height: 58)

            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.clear).frame(height: 24 * hourHeight)
                ForEach(sessions) { session in
                    if let start = parseTime(session.startTime) {
                        // Use durationSeconds so midnight-crossing blocks render fully.
                        let top = yOffset(start)
                        let hours = Double(session.durationSeconds) / 3600.0
                        let height = CGFloat(hours) * hourHeight
                        weekSessionBlock(session: session, height: max(height, 2))
                            .padding(.horizontal, Spacing.space1)
                            .offset(y: top)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func weekSessionBlock(session: FocusSessionResponse, height: CGFloat) -> some View {
        let isSelected = selectedSession?.id == session.id
        Button {
            selectedSession = isSelected ? nil : session
        } label: {
            RoundedRectangle(cornerRadius: height > 4 ? 3 : 1)
                .fill(categoryColor(session.name).opacity(isSelected ? 1.0 : 0.75))
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(.plain)
        .help("\(session.name) \(session.startTime)-\(session.endTime) (\(session.duration))")
        .popover(isPresented: Binding(
            get: { isSelected },
            set: { if !$0 { selectedSession = nil } }
        ), arrowEdge: .top) {
            SessionPopoverCard(session: session, formatDuration: formatDuration)
        }
    }
}
#endif
