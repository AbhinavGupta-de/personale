#if os(macOS)
import SwiftUI

// MARK: - Distraction Blocker (M14)

struct DistractionBlockerCard: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var settings = AppSettings.shared
    @State private var availableCategories: [String] = []
    private let api = APIClient.shared

    private let thresholdOptions: [(label: String, seconds: Int)] = [
        ("30 sec", 30), ("1 min", 60), ("2 min", 120),
        ("5 min", 300), ("10 min", 600)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space6) {
            row(title: "Blocker Type",
                help: "What to show when a distraction threshold is crossed") {
                Picker("", selection: $settings.blockerType) {
                    Text("Pop-Up Window").tag(AppSettings.BlockerType.popup)
                    Text("System Notification").tag(AppSettings.BlockerType.notification)
                }
                .labelsHidden()
                .frame(width: 180)
            }

            Divider().opacity(0.3)

            row(title: "Threshold",
                help: "Accumulated time in a distraction category before blocker triggers") {
                Picker("", selection: $settings.blockerThresholdSeconds) {
                    ForEach(thresholdOptions, id: \.seconds) { opt in
                        Text(opt.label).tag(opt.seconds)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }

            Divider().opacity(0.3)

            row(title: "Urge Surfing",
                help: "Lock the blocker for 10 seconds before it's dismissible") {
                Toggle("", isOn: $settings.urgeSurfing)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }

            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: Spacing.space2) {
                Text("Distraction Categories")
                    .font(AppFont.text(FontSize.base, .medium))
                    .foregroundStyle(theme.foreground)
                Text("Time spent in these categories during a focus session triggers the blocker")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground)

                FlowLayout(spacing: Spacing.space2) {
                    ForEach(availableCategories, id: \.self) { cat in
                        categoryChip(cat)
                    }
                }
            }

            Text("Note: engine + overlay ship in a follow-up; settings persist today.")
                .font(AppFont.text(FontSize.xs))
                .foregroundStyle(theme.mutedForeground.opacity(0.7))
        }
        .onAppear { loadCategories() }
    }

    private func categoryChip(_ name: String) -> some View {
        let selected = settings.distractionCategories.contains(name)
        return Button {
            if selected {
                settings.distractionCategories.remove(name)
            } else {
                settings.distractionCategories.insert(name)
            }
        } label: {
            HStack(spacing: Spacing.space1) {
                if selected {
                    Image(systemName: "checkmark").font(AppFont.text(FontSize.xs2, .bold))
                }
                Text(name).font(AppFont.text(FontSize.sm))
            }
            .foregroundStyle(selected ? theme.primaryForeground : theme.foreground)
            .padding(.horizontal, Spacing.space3).padding(.vertical, Spacing.space1)
            .background(selected ? theme.primary : theme.secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func loadCategories() {
        Task {
            if let cats = try? await api.fetchCategorySettings() {
                availableCategories = cats.map(\.name)
            }
        }
    }

    @ViewBuilder
    private func row<Content: View>(title: String, help: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.text(FontSize.md, .medium)).foregroundStyle(theme.foreground)
                Text(help).font(AppFont.text(FontSize.xs)).foregroundStyle(theme.mutedForeground)
            }
            Spacer()
            trailing()
        }
    }
}

// MARK: - Breaks (M15)

struct BreaksSettingsCard: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var settings = AppSettings.shared

    private let durationOptions: [Int] = [5, 10, 15]
    private let maxOptions: [Int] = [15, 30, 60, 90]
    private let intervalOptions: [Int] = [30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space6) {
            row(title: "Automatic Break Detection",
                help: "Auto-create Break sessions from gaps between focus sessions") {
                Toggle("", isOn: $settings.autoDetectBreaks)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
            }

            Divider().opacity(0.3)

            row(title: "Default Break Duration", help: "How long a typical break is") {
                Picker("", selection: $settings.defaultBreakMinutes) {
                    ForEach(durationOptions, id: \.self) { Text("\($0) min").tag($0) }
                }
                .labelsHidden().frame(width: 100)
            }

            Divider().opacity(0.3)

            row(title: "Maximum Break Duration",
                help: "Gaps longer than this are classified as \"Away\"") {
                Picker("", selection: $settings.maxBreakMinutes) {
                    ForEach(maxOptions, id: \.self) { Text("\($0) min").tag($0) }
                }
                .labelsHidden().frame(width: 100)
            }

            Divider().opacity(0.3)

            row(title: "Full Screen Break Mode",
                help: "Show a full-screen break overlay when a break starts") {
                Toggle("", isOn: $settings.fullScreenBreakMode)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
            }

            Divider().opacity(0.3)

            row(title: "Smart Break Notifications",
                help: "Nudge to take a break after N minutes of continuous non-break work") {
                Toggle("", isOn: $settings.smartBreakNotifications)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
            }

            if settings.smartBreakNotifications {
                row(title: "Nudge Interval", help: "") {
                    Picker("", selection: $settings.smartBreakIntervalMinutes) {
                        ForEach(intervalOptions, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .labelsHidden().frame(width: 100)
                }
            }

            Text("Note: detection engine + overlay ship in a follow-up; settings persist today.")
                .font(AppFont.text(FontSize.xs))
                .foregroundStyle(theme.mutedForeground.opacity(0.7))
        }
    }

    @ViewBuilder
    private func row<Content: View>(title: String, help: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.text(FontSize.md, .medium)).foregroundStyle(theme.foreground)
                if !help.isEmpty {
                    Text(help).font(AppFont.text(FontSize.xs)).foregroundStyle(theme.mutedForeground)
                }
            }
            Spacer()
            trailing()
        }
    }
}

// MARK: - Flow layout helper (for chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? .infinity
        var total = CGSize.zero
        var row = CGSize.zero
        for s in sizes {
            if row.width + s.width > width {
                total.width = max(total.width, row.width)
                total.height += row.height + spacing
                row = .zero
            }
            row.width += s.width + spacing
            row.height = max(row.height, s.height)
        }
        total.width = max(total.width, row.width)
        total.height += row.height
        return total
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
#endif
