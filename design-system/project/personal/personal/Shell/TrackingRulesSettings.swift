#if os(macOS)
import Combine
import SwiftUI

@MainActor
class TrackingRulesViewModel: ObservableObject {
    @Published var rules: [TrackingRuleResponse] = []
    @Published var search: String = ""
    @Published var sourceFilter: String = "all"    // all | macos | browser
    @Published var categoryFilter: String = "all"
    @Published var errorMessage: String?
    @Published var editingRule: TrackingRuleResponse?
    @Published var showingNewRule = false

    private let api = APIClient.shared

    var categoriesInUse: [String] {
        Array(Set(rules.map(\.category))).sorted()
    }

    var filtered: [TrackingRuleResponse] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return rules.filter { r in
            if sourceFilter != "all" && r.source != sourceFilter { return false }
            if categoryFilter != "all" && r.category != categoryFilter { return false }
            if q.isEmpty { return true }
            if r.appName.lowercased().contains(q) { return true }
            if r.category.lowercased().contains(q) { return true }
            if let kw = r.keywords?.lowercased(), kw.contains(q) { return true }
            return false
        }
    }

    func load() {
        Task {
            do {
                rules = try await api.fetchTrackingRules()
                errorMessage = nil
            } catch {
                errorMessage = "Failed to load rules: \(error.localizedDescription)"
            }
        }
    }

    func save(_ req: TrackingRuleRequest, editing: TrackingRuleResponse?) {
        Task {
            do {
                if let editing {
                    let updated = try await api.updateTrackingRule(editing.id, req)
                    if let i = rules.firstIndex(where: { $0.id == updated.id }) {
                        rules[i] = updated
                    }
                } else {
                    let created = try await api.createTrackingRule(req)
                    rules.append(created)
                    rules.sort { ($0.source, $0.appName.lowercased()) < ($1.source, $1.appName.lowercased()) }
                }
                editingRule = nil
                showingNewRule = false
                errorMessage = nil
            } catch {
                errorMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    func delete(_ rule: TrackingRuleResponse) {
        Task {
            do {
                try await api.deleteTrackingRule(rule.id)
                rules.removeAll { $0.id == rule.id }
            } catch {
                errorMessage = "Delete failed: \(error.localizedDescription)"
            }
        }
    }
}

struct TrackingRulesCard: View {
    @Environment(\.theme) private var theme
    @StateObject private var vm = TrackingRulesViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if let err = vm.errorMessage {
                Text(err).font(.system(size: 11)).foregroundStyle(theme.warning)
            }

            columnHeader
            Divider().opacity(0.4)

            if vm.filtered.isEmpty {
                Text("No rules match")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.filtered) { rule in
                        RuleRow(rule: rule,
                                onEdit: { vm.editingRule = rule },
                                onDelete: { vm.delete(rule) })
                        Divider().opacity(0.2)
                    }
                }
            }
        }
        .onAppear { vm.load() }
        .sheet(isPresented: $vm.showingNewRule) {
            RuleEditSheet(rule: nil, onSave: { vm.save($0, editing: nil) },
                          onCancel: { vm.showingNewRule = false })
        }
        .sheet(item: $vm.editingRule) { rule in
            RuleEditSheet(rule: rule, onSave: { vm.save($0, editing: rule) },
                          onCancel: { vm.editingRule = nil })
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            TextField("Search rules", text: $vm.search)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(theme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.border.opacity(0.6), lineWidth: 1))
                .frame(width: 180)

            Picker("", selection: $vm.sourceFilter) {
                Text("All").tag("all")
                Text("macOS").tag("macos")
                Text("Browser").tag("browser")
            }
            .labelsHidden()
            .frame(width: 100)

            Picker("", selection: $vm.categoryFilter) {
                Text("All categories").tag("all")
                ForEach(vm.categoriesInUse, id: \.self) { c in
                    Text(c).tag(c)
                }
            }
            .labelsHidden()
            .frame(width: 140)

            Spacer()

            Button("New Rule") { vm.showingNewRule = true }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.primaryForeground)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .buttonStyle(.plain)
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("Source").frame(width: 70, alignment: .leading)
            Text("App / Domain").frame(width: 200, alignment: .leading)
            Text("Category").frame(width: 110, alignment: .leading)
            Text("Keywords").frame(maxWidth: .infinity, alignment: .leading)
            Text("Flags").frame(width: 80, alignment: .leading)
            Spacer().frame(width: 60)
        }
        .font(.system(size: 10, weight: .semibold))
        .tracking(0.5)
        .foregroundStyle(theme.mutedForeground)
        .padding(.vertical, 4)
    }
}

// MARK: - Row

private struct RuleRow: View {
    let rule: TrackingRuleResponse
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: rule.source == "macos" ? "desktopcomputer" : "safari")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.mutedForeground)
                Text(rule.source)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.mutedForeground)
            }
            .frame(width: 70, alignment: .leading)

            Text(rule.appName)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)

            HStack(spacing: 4) {
                Circle().fill(CategoryColors.color(for: rule.category)).frame(width: 6, height: 6)
                Text(rule.category).font(.system(size: 11)).foregroundStyle(theme.foreground)
            }
            .frame(width: 110, alignment: .leading)

            Text(rule.keywords ?? "—")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.mutedForeground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                if rule.alwaysBlock {
                    flagBadge("Block", color: theme.warning)
                }
                if rule.blockFocus || rule.blockBreaks || rule.blockMeetings {
                    flagBadge("Cond", color: theme.primary)
                }
                if !rule.trackTitles {
                    flagBadge("No⟂T", color: theme.mutedForeground)
                }
            }
            .frame(width: 80, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                        .padding(4)
                }
                .buttonStyle(.plain)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 60)
        }
        .padding(.vertical, 6)
    }

    private func flagBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Edit Sheet

private struct RuleEditSheet: View {
    let rule: TrackingRuleResponse?
    let onSave: (TrackingRuleRequest) -> Void
    let onCancel: () -> Void
    @Environment(\.theme) private var theme

    @State private var source: String = "macos"
    @State private var appName: String = ""
    @State private var keywords: String = ""
    @State private var category: String = "Other"
    @State private var alwaysBlock = false
    @State private var blockBreaks = false
    @State private var blockMeetings = false
    @State private var blockFocus = false
    @State private var trackTitles = true
    @State private var trackFullUrls = false

    private let categoryOptions = [
        "Code", "Reading", "Writing", "Design", "Documenting", "Learning",
        "Communication", "Email", "Messaging", "Meetings",
        "Browsing", "Media", "Entertainment", "Gaming",
        "Utilities", "Break", "Miscellaneous", "Other"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(rule == nil ? "New Tracking Rule" : "Edit Tracking Rule")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.foreground)

            Divider().opacity(0.3)

            labeled("App / Domain") {
                TextField(source == "macos" ? "com.apple.Safari" : "github.com", text: $appName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            HStack(spacing: 14) {
                labeled("Source") {
                    Picker("", selection: $source) {
                        Text("macOS").tag("macos")
                        Text("Browser").tag("browser")
                    }
                    .labelsHidden()
                }

                labeled("Category") {
                    Picker("", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { c in Text(c).tag(c) }
                    }
                    .labelsHidden()
                }
            }

            labeled("Keywords (optional, comma-separated)") {
                TextField("onboarding, pricing", text: $keywords)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 6) {
                Text("Blocking").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.mutedForeground)
                toggle("Always Block", $alwaysBlock)
                toggle("Block during Breaks", $blockBreaks)
                toggle("Block during Meetings", $blockMeetings)
                toggle("Block during Focus Sessions", $blockFocus)
            }

            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tracking").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.mutedForeground)
                toggle("Track Titles", $trackTitles)
                toggle("Track Full URLs", $trackFullUrls)
            }

            Spacer()

            HStack {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.mutedForeground)
                Spacer()
                Button(rule == nil ? "Create" : "Save") {
                    onSave(TrackingRuleRequest(
                        source: source, appName: appName,
                        keywords: keywords.isEmpty ? nil : keywords,
                        category: category,
                        alwaysBlock: alwaysBlock, blockBreaks: blockBreaks,
                        blockMeetings: blockMeetings, blockFocus: blockFocus,
                        trackTitles: trackTitles, trackFullUrls: trackFullUrls))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.primaryForeground)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
                .disabled(appName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480, height: 560)
        .background(theme.card)
        .onAppear { populate() }
    }

    private func populate() {
        guard let r = rule else { return }
        source = r.source
        appName = r.appName
        keywords = r.keywords ?? ""
        category = r.category
        alwaysBlock = r.alwaysBlock
        blockBreaks = r.blockBreaks
        blockMeetings = r.blockMeetings
        blockFocus = r.blockFocus
        trackTitles = r.trackTitles
        trackFullUrls = r.trackFullUrls
    }

    @ViewBuilder
    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(theme.mutedForeground)
            content()
        }
    }

    @ViewBuilder
    private func toggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(theme.foreground)
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }
}
#endif
