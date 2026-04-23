#if os(macOS)
import Combine
import SwiftUI

// MARK: - View Model

@MainActor
class CategoriesSettingsViewModel: ObservableObject {
    @Published var categories: [CategoryResponse] = []
    @Published var search: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var newCategoryName: String = ""

    private let api = APIClient.shared

    var filtered: [CategoryResponse] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return categories }
        return categories.filter { $0.name.lowercased().contains(q) }
    }

    func load() {
        isLoading = true
        Task {
            defer { Task { @MainActor in self.isLoading = false } }
            do {
                let result = try await api.fetchCategorySettings()
                self.categories = result
                self.errorMessage = nil
            } catch {
                self.errorMessage = "Failed to load categories: \(error.localizedDescription)"
            }
        }
    }

    func toggle(_ category: CategoryResponse, _ flag: WritableKeyPath<CategoryUpdateRequest, Bool?>,
                _ value: Bool) {
        var req = CategoryUpdateRequest(
            idleThresholdSeconds: nil, focus: nil, workHours: nil,
            idleDetection: nil, distractionBlocker: nil,
            dailyGoalSeconds: nil, goalIsMax: nil)
        req[keyPath: flag] = value
        Task {
            do {
                let updated = try await api.updateCategory(category.name, req)
                if let idx = self.categories.firstIndex(where: { $0.id == updated.id }) {
                    self.categories[idx] = updated
                }
            } catch {
                self.errorMessage = "Update failed: \(error.localizedDescription)"
            }
        }
    }

    func updateThreshold(_ category: CategoryResponse, seconds: Int) {
        var req = CategoryUpdateRequest(
            idleThresholdSeconds: nil, focus: nil, workHours: nil,
            idleDetection: nil, distractionBlocker: nil,
            dailyGoalSeconds: nil, goalIsMax: nil)
        req.idleThresholdSeconds = seconds
        applyUpdate(category, req)
    }

    func updateGoal(_ category: CategoryResponse, seconds: Int, isMax: Bool) {
        var req = CategoryUpdateRequest(
            idleThresholdSeconds: nil, focus: nil, workHours: nil,
            idleDetection: nil, distractionBlocker: nil,
            dailyGoalSeconds: nil, goalIsMax: nil)
        req.dailyGoalSeconds = seconds
        req.goalIsMax = isMax
        applyUpdate(category, req)
    }

    private func applyUpdate(_ category: CategoryResponse, _ req: CategoryUpdateRequest) {
        Task {
            do {
                let updated = try await api.updateCategory(category.name, req)
                if let idx = self.categories.firstIndex(where: { $0.id == updated.id }) {
                    self.categories[idx] = updated
                }
            } catch {
                self.errorMessage = "Update failed: \(error.localizedDescription)"
            }
        }
    }

    func create() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let req = CategoryCreateRequest(
            name: name, idleThresholdSeconds: 300,
            focus: true, workHours: true, idleDetection: true, distractionBlocker: false,
            dailyGoalSeconds: nil, goalIsMax: nil)
        Task {
            do {
                let created = try await api.createCategory(req)
                self.categories.append(created)
                self.categories.sort { $0.name.lowercased() < $1.name.lowercased() }
                self.newCategoryName = ""
                self.errorMessage = nil
            } catch {
                self.errorMessage = "Create failed: \(error.localizedDescription)"
            }
        }
    }

    func delete(_ category: CategoryResponse) {
        Task {
            do {
                try await api.deleteCategory(category.name)
                self.categories.removeAll { $0.id == category.id }
                self.errorMessage = nil
            } catch {
                self.errorMessage = "Delete failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Card

struct CategoriesSettingsCard: View {
    @Environment(\.theme) private var theme
    @StateObject private var vm = CategoriesSettingsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if let err = vm.errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.warning)
            }

            columnHeader
            Divider().opacity(0.4)

            if vm.filtered.isEmpty {
                Text(vm.isLoading ? "Loading…" : "No categories")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.filtered) { cat in
                        CategoryRow(category: cat, vm: vm)
                        Divider().opacity(0.2)
                    }
                }
            }
        }
        .onAppear { vm.load() }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            TextField("Search categories", text: $vm.search)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(theme.foreground)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.border.opacity(0.6), lineWidth: 1)
                )
                .frame(width: 200)

            Spacer()

            TextField("New category name", text: $vm.newCategoryName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(theme.foreground)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.border.opacity(0.6), lineWidth: 1)
                )
                .frame(width: 180)
                .onSubmit { vm.create() }

            Button("Create") { vm.create() }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.primaryForeground)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .buttonStyle(.plain)
                .disabled(vm.newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("Name").frame(width: 180, alignment: .leading)
            Text("Idle (s)").frame(width: 80, alignment: .trailing)
            Text("Focus").frame(width: 70, alignment: .center)
            Text("Work Hours").frame(width: 90, alignment: .center)
            Text("Idle Detect").frame(width: 90, alignment: .center)
            Text("Blocker").frame(width: 70, alignment: .center)
            Text("Goal").frame(width: 60, alignment: .center)
            Spacer()
        }
        .font(.system(size: 10, weight: .semibold))
        .tracking(0.5)
        .foregroundStyle(theme.mutedForeground)
        .padding(.vertical, 4)
    }
}

// MARK: - Row

private struct CategoryRow: View {
    let category: CategoryResponse
    @ObservedObject var vm: CategoriesSettingsViewModel
    @Environment(\.theme) private var theme

    @State private var idleText: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // Name + category colour dot
            HStack(spacing: 6) {
                Circle()
                    .fill(CategoryColors.color(for: category.name))
                    .frame(width: 8, height: 8)
                Text(category.name)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
            }
            .frame(width: 180, alignment: .leading)

            // Idle threshold
            TextField("", text: $idleText)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.foreground)
                .frame(width: 64)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onAppear { idleText = String(category.idleThresholdSeconds) }
                .onSubmit {
                    if let n = Int(idleText), n > 0 { vm.updateThreshold(category, seconds: n) }
                    else { idleText = String(category.idleThresholdSeconds) }
                }
                .frame(width: 80, alignment: .trailing)

            flagToggle(value: category.focus) { vm.toggle(category, \.focus, $0) }
                .frame(width: 70, alignment: .center)
            flagToggle(value: category.workHours) { vm.toggle(category, \.workHours, $0) }
                .frame(width: 90, alignment: .center)
            flagToggle(value: category.idleDetection) { vm.toggle(category, \.idleDetection, $0) }
                .frame(width: 90, alignment: .center)
            flagToggle(value: category.distractionBlocker) { vm.toggle(category, \.distractionBlocker, $0) }
                .frame(width: 70, alignment: .center)

            goalButton
                .frame(width: 60, alignment: .center)

            Spacer()

            Button {
                vm.delete(category)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .padding(.vertical, 6)
    }

    @State private var showGoalPopover = false
    @State private var goalMinutes: String = ""
    @State private var goalIsMax = false

    @ViewBuilder
    private var goalButton: some View {
        Button {
            goalMinutes = category.dailyGoalSeconds > 0 ? String(category.dailyGoalSeconds / 60) : ""
            goalIsMax = category.goalIsMax
            showGoalPopover = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: category.dailyGoalSeconds > 0 ? "flag.fill" : "flag")
                    .font(.system(size: 9))
                if category.dailyGoalSeconds > 0 {
                    Text("\(category.dailyGoalSeconds / 60)m")
                        .font(.system(size: 9, design: .monospaced))
                }
            }
            .foregroundStyle(category.dailyGoalSeconds > 0 ? theme.primary : theme.mutedForeground)
            .padding(.horizontal, 5).padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showGoalPopover, arrowEdge: .trailing) {
            goalEditor
                .padding(14)
                .frame(width: 220)
        }
    }

    private var goalEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Goal — \(category.name)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.foreground)

            HStack(spacing: 6) {
                TextField("0", text: $goalMinutes)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 70)
                Text("minutes / day")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
            }

            Picker("", selection: $goalIsMax) {
                Text("Floor (stay above)").tag(false)
                Text("Ceiling (stay under)").tag(true)
            }
            .labelsHidden()
            .pickerStyle(.radioGroup)

            HStack {
                Button("Clear") {
                    vm.updateGoal(category, seconds: 0, isMax: false)
                    showGoalPopover = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.mutedForeground)
                Spacer()
                Button("Save") {
                    let mins = Int(goalMinutes) ?? 0
                    vm.updateGoal(category, seconds: max(0, mins) * 60, isMax: goalIsMax)
                    showGoalPopover = false
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.primaryForeground)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func flagToggle(value: Bool, onChange: @escaping (Bool) -> Void) -> some View {
        Toggle("", isOn: Binding(
            get: { value },
            set: { onChange($0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
    }
}
#endif
