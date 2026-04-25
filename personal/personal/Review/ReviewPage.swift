#if os(macOS)
import Combine
import SwiftUI

// MARK: - ViewModel

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var blocks: [SessionReviewResponse] = []
    @Published var statusFilter: String = "pending"   // pending | approved | all
    @Published var selectedKey: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var generatingFor: String?
    @Published var batchGenerating = false
    @Published var selectedDate: Date
    @Published var availableCategories: [String] = []

    private let api = APIClient.shared

    static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    init() {
        selectedDate = ActivityViewModel.effectiveToday(
            dayStartHour: AppSettings.shared.dayStartHour)
    }

    var dateString: String { Self.dateFmt.string(from: selectedDate) }

    var displayDate: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: selectedDate)
    }

    var filtered: [SessionReviewResponse] {
        if statusFilter == "all" { return blocks }
        return blocks.filter { $0.status == statusFilter }
    }

    var selected: SessionReviewResponse? {
        blocks.first { $0.blockKey == selectedKey } ?? filtered.first
    }

    var counts: (pending: Int, approved: Int, all: Int) {
        (
            pending: blocks.filter { $0.status == "pending" }.count,
            approved: blocks.filter { $0.status == "approved" }.count,
            all: blocks.count
        )
    }

    func load() {
        isLoading = true
        Task {
            defer { Task { @MainActor in self.isLoading = false } }
            do {
                blocks = try await api.fetchReviews(date: dateString, status: "all")
                if selectedKey == nil { selectedKey = filtered.first?.blockKey }

                // Kick off AI drafts for any block that doesn't have one yet.
                // Fire-and-forget; UI will refresh when the batch comes back.
                let needsDraft = blocks.contains { $0.aiTitle == nil || $0.aiTitle?.isEmpty == true }
                if needsDraft { await self.generateMissing() }
            } catch {
                errorMessage = "Failed to load reviews: \(error.localizedDescription)"
            }
        }
        Task {
            if let cats = try? await api.fetchCategorySettings() {
                availableCategories = cats.map(\.name)
            }
        }
    }

    private func generateMissing() async {
        batchGenerating = true
        defer { batchGenerating = false }
        do {
            let refreshed = try await api.generateMissingReviewInsights(date: dateString)
            blocks = refreshed
        } catch {
            errorMessage = "Batch generate failed: \(error.localizedDescription)"
        }
    }

    func regenerateAll() {
        batchGenerating = true
        Task {
            defer { Task { @MainActor in self.batchGenerating = false } }
            do {
                let refreshed = try await api.regenerateAllReviewInsights(date: dateString)
                blocks = refreshed
                errorMessage = nil
            } catch {
                errorMessage = "Regenerate-all failed: \(error.localizedDescription)"
            }
        }
    }

    func goToPreviousDay() { shiftDay(-1) }
    func goToNextDay() { shiftDay(1) }

    private func shiftDay(_ delta: Int) {
        let cal = Calendar.current
        let next = cal.date(byAdding: .day, value: delta, to: selectedDate) ?? selectedDate
        let bound = ActivityViewModel.effectiveToday(dayStartHour: AppSettings.shared.dayStartHour)
        if delta > 0 && next > bound { return }
        selectedDate = next
        selectedKey = nil
        load()
    }

    func save(_ req: SessionReviewUpdateRequest, key: String) {
        Task {
            do {
                let updated = try await api.updateReview(key: key, date: dateString, req: req)
                replace(updated)
            } catch {
                errorMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    func setStatus(_ status: String, key: String) {
        Task {
            do {
                let updated = try await api.setReviewStatus(key: key, date: dateString, status: status)
                replace(updated)
                // Advance to next pending if user accepts/rejects current
                if statusFilter == "pending" && status != "pending" {
                    selectedKey = filtered.first(where: { $0.blockKey != key })?.blockKey
                }
            } catch {
                errorMessage = "Status failed: \(error.localizedDescription)"
            }
        }
    }

    func generate(key: String) {
        generatingFor = key
        Task {
            defer { Task { @MainActor in self.generatingFor = nil } }
            do {
                let updated = try await api.generateReviewInsight(key: key, date: dateString)
                replace(updated)
            } catch {
                errorMessage = "Generate failed: \(error.localizedDescription)"
            }
        }
    }

    private func replace(_ r: SessionReviewResponse) {
        if let idx = blocks.firstIndex(where: { $0.blockKey == r.blockKey }) {
            blocks[idx] = r
        }
    }
}

// MARK: - Page

struct ReviewPage: View {
    @Environment(\.theme) private var theme
    @StateObject private var vm = ReviewViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)

            HStack(alignment: .top, spacing: 0) {
                sidebar
                    .frame(width: 280)
                Divider().opacity(0.4)
                middle
                    .frame(maxWidth: .infinity)
                Divider().opacity(0.4)
                rightPanel
                    .frame(width: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { vm.load() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("Time Entry Review")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.foreground)

            HStack(spacing: 2) {
                filterButton("pending", label: "Pending (\(vm.counts.pending))")
                filterButton("approved", label: "Approved")
                filterButton("all", label: "All (\(vm.counts.all))")
            }
            .padding(3)
            .background(theme.secondary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            Spacer()

            if vm.batchGenerating {
                HStack(spacing: 5) {
                    ProgressView().controlSize(.mini)
                    Text("Generating AI drafts…")
                        .font(.system(size: 11)).foregroundStyle(theme.mutedForeground)
                }
                .padding(.trailing, 10)
            } else {
                Button {
                    vm.regenerateAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise.circle").font(.system(size: 10))
                        Text("Regen all").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(theme.primary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(theme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Re-generate AI drafts for every block on this day, even if one already exists. Use after the prompt has improved.")
                .padding(.trailing, 10)
            }

            Text(vm.displayDate)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.foreground)

            HStack(spacing: 0) {
                Button { vm.goToPreviousDay() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                Button { vm.goToNextDay() } label: {
                    Image(systemName: "chevron.right").font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    @ViewBuilder
    private func filterButton(_ status: String, label: String) -> some View {
        Button { vm.statusFilter = status } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(vm.statusFilter == status ? theme.foreground : theme.mutedForeground)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(vm.statusFilter == status ? theme.card : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // Left sidebar — list of blocks

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if vm.filtered.isEmpty {
                    Text(vm.isLoading ? "Loading…" : "No entries")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.mutedForeground)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                ForEach(vm.filtered) { block in
                    BlockRow(block: block, selected: block.blockKey == vm.selectedKey) {
                        vm.selectedKey = block.blockKey
                    }
                }
            }
            .padding(12)
        }
    }

    // Middle — editor

    @ViewBuilder
    private var middle: some View {
        if let sel = vm.selected {
            ReviewEditor(block: sel, vm: vm)
        } else {
            Text("Select an entry to review")
                .font(.system(size: 13))
                .foregroundStyle(theme.mutedForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // Right — overview of this block's apps + websites

    @ViewBuilder
    private var rightPanel: some View {
        if let sel = vm.selected {
            OverviewPanel(block: sel)
        } else {
            Spacer()
        }
    }
}

// MARK: - Block row

private struct BlockRow: View {
    let block: SessionReviewResponse
    let selected: Bool
    let onTap: () -> Void
    @Environment(\.theme) private var theme

    private func fmt(_ s: Int) -> String {
        let m = s / 60
        if m < 60 { return "\(m) min" }
        return "\(m / 60) hr \(m % 60) min"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(CategoryColors.color(for: block.category))
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(block.title ?? block.aiTitle ?? block.category)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                    Text("\(block.startTime) – \(block.endTime) · \(fmt(block.durationSeconds))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.mutedForeground)
                }
                Spacer()
                statusBadge
            }
            .padding(10)
            .background(selected ? theme.primary.opacity(0.12) : theme.secondary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? theme.primary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = switch block.status {
        case "approved": ("Approved", theme.success)
        case "rejected": ("Rejected", theme.mutedForeground)
        default: ("Pending", theme.accent)
        }
        return Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Editor

private struct ReviewEditor: View {
    let block: SessionReviewResponse
    @ObservedObject var vm: ReviewViewModel
    @Environment(\.theme) private var theme

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var task: String = ""
    @State private var project: String = ""
    @State private var client: String = ""
    @State private var category: String = ""

    private var categoryBadge: some View {
        Menu {
            ForEach(vm.availableCategories, id: \.self) { cat in
                Button {
                    category = cat
                    vm.save(SessionReviewUpdateRequest(
                        title: nil, description: nil, task: nil, project: nil, client: nil,
                        category: cat
                    ), key: block.blockKey)
                } label: {
                    HStack {
                        Text(cat)
                        if cat == category {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Circle().fill(CategoryColors.color(for: category)).frame(width: 6, height: 6)
                Text(category.uppercased())
                    .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                Image(systemName: "chevron.down").font(.system(size: 8)).opacity(0.5)
            }
            .foregroundStyle(theme.foreground)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(theme.secondary.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func fmt(_ s: Int) -> String {
        let m = s / 60
        if m < 60 { return "\(m) min" }
        return "\(m / 60) hr \(m % 60) min"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    categoryBadge
                    Spacer()
                    Text("\(block.startTime) – \(block.endTime)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.foreground)
                    Text(fmt(block.durationSeconds))
                        .font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                    Button {
                        vm.generate(key: block.blockKey)
                    } label: {
                        HStack(spacing: 4) {
                            if vm.generatingFor == block.blockKey {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "sparkles").font(.system(size: 10))
                            }
                            Text("AI").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(theme.primary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(theme.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.generatingFor == block.blockKey)
                }

                TextField("Title", text: $title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                    .padding(12)
                    .background(theme.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .lineLimit(1...3)

                TextField("Description — what specifically did you do? (helps AI learn)",
                          text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.foreground)
                    .padding(12)
                    .background(theme.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .lineLimit(3...8)

                HStack(spacing: 8) {
                    metadataField(icon: "checkmark.square", placeholder: "Task", text: $task)
                    metadataField(icon: "folder", placeholder: "Project", text: $project)
                    metadataField(icon: "person", placeholder: "Client", text: $client)
                }

                HStack(spacing: 10) {
                    Button {
                        save()
                        vm.setStatus("approved", key: block.blockKey)
                    } label: {
                        HStack(spacing: 5) {
                            Text("Accept").font(.system(size: 12, weight: .semibold))
                            Text("⌘↵").font(.system(size: 10)).opacity(0.7)
                        }
                        .foregroundStyle(theme.primaryForeground)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(theme.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [.command])

                    Button {
                        vm.setStatus("rejected", key: block.blockKey)
                    } label: {
                        HStack(spacing: 5) {
                            Text("Reject").font(.system(size: 12))
                            Text("⌘⌫").font(.system(size: 10)).opacity(0.7)
                        }
                        .foregroundStyle(theme.foreground)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(theme.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.delete, modifiers: [.command])

                    Spacer()
                }
                .padding(.top, 4)

                if let err = vm.errorMessage {
                    Text(err).font(.system(size: 11)).foregroundStyle(theme.warning)
                }
            }
            .padding(20)
        }
        .onAppear { populate() }
        .onChange(of: block.blockKey) { _, _ in populate() }
        .onChange(of: block.aiTitle) { _, _ in populate() }
        .onChange(of: block.title) { _, _ in populate() }
    }

    @ViewBuilder
    private func metadataField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(theme.mutedForeground)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(theme.foreground)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(theme.secondary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .frame(maxWidth: .infinity)
    }

    private func populate() {
        title = block.title ?? block.aiTitle ?? ""
        description = block.description ?? block.aiDescription ?? ""
        task = block.task ?? ""
        project = block.project ?? ""
        client = block.client ?? ""
        category = block.category
    }

    private func save() {
        let req = SessionReviewUpdateRequest(
            title: title.isEmpty ? nil : title,
            description: description.isEmpty ? nil : description,
            task: task.isEmpty ? nil : task,
            project: project.isEmpty ? nil : project,
            client: client.isEmpty ? nil : client,
            category: category == block.category ? nil : category
        )
        vm.save(req, key: block.blockKey)
    }
}

// MARK: - Overview panel

private struct OverviewPanel: View {
    let block: SessionReviewResponse
    @Environment(\.theme) private var theme

    private func fmt(_ s: Int) -> String {
        let m = s / 60
        if m == 0 { return "\(s)s" }
        if m < 60 { return "\(m)m \(s % 60)s" }
        return "\(m / 60)h \(m % 60)m"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(text: "Overview")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Apps & Websites")
                        .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                        .foregroundStyle(theme.mutedForeground)
                    ForEach(block.apps.prefix(8), id: \.appName) { app in
                        HStack(spacing: 6) {
                            Text(app.appName)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                            Spacer()
                            Text(fmt(app.totalSeconds))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                        }
                    }
                }

                if let domains = block.topDomains, !domains.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Top Domains")
                            .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                            .foregroundStyle(theme.mutedForeground)
                        ForEach(domains.prefix(6)) { dom in
                            HStack(spacing: 6) {
                                Text(dom.domain)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.foreground)
                                    .lineLimit(1)
                                Spacer()
                                Text(fmt(dom.seconds))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(theme.mutedForeground)
                            }
                        }
                    }
                }

                if !block.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Categories in this block")
                            .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                            .foregroundStyle(theme.mutedForeground)
                        ForEach(block.categories, id: \.category) { c in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(CategoryColors.color(for: c.category))
                                    .frame(width: 6, height: 6)
                                Text(c.category)
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.foreground)
                                Spacer()
                                Text("\(c.percent)%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(theme.mutedForeground)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }
}
#endif
