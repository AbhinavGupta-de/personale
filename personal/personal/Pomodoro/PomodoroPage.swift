#if os(macOS)
import Combine
import SwiftUI

// MARK: - ViewModel

@MainActor
class PomodoroViewModel: ObservableObject {
    static let shared = PomodoroViewModel()

    @Published var isRunning = false
    @Published var goal: String = ""
    @Published var elapsedSeconds: Int = 0
    @Published var sessions: [PomodoroSessionResponse] = []
    @Published var targetSeconds: Int = 25 * 60
    @Published var currentSessionId: Int64?
    @Published var insights: [Int64: SessionInsightResponse] = [:]
    @Published var generatingInsightFor: Int64?
    @Published var insightError: String?

    private var startedAt: Date?
    private var timerCancellable: AnyCancellable?
    private let api = APIClient.shared

    init() {
        Task { await self.loadToday() }
    }

    var elapsedText: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var progress: Double {
        guard targetSeconds > 0 else { return 0 }
        return min(1.0, Double(elapsedSeconds) / Double(targetSeconds))
    }

    func start() {
        guard !isRunning else { return }
        let goalText = goal.isEmpty ? "Untitled session" : goal
        isRunning = true
        startedAt = Date()
        elapsedSeconds = 0
        startTimer()
        Task {
            if let session = try? await api.startPomodoro(goal: goalText, targetSeconds: targetSeconds) {
                self.currentSessionId = session.id
            }
        }
    }

    func end(discard: Bool = false) {
        guard isRunning else { return }
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        let idToEnd = currentSessionId
        let finishedGoal = goal
        goal = ""
        elapsedSeconds = 0
        startedAt = nil
        currentSessionId = nil
        _ = finishedGoal
        Task {
            if let id = idToEnd, let finished = try? await api.endPomodoro(id: id, discard: discard) {
                await MainActor.run { self.sessions.insert(finished, at: 0) }
            }
            await self.loadToday()
        }
    }

    func addFiveMinutes() {
        targetSeconds += 5 * 60
    }

    func resetTarget(minutes: Int) {
        targetSeconds = max(60, minutes * 60)
    }

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let started = self.startedAt else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(started))
            }
    }

    private func loadToday() async {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let dateStr = fmt.string(from: Date())
        if let list = try? await api.fetchPomodoros(date: dateStr) {
            await MainActor.run {
                self.sessions = list.filter { $0.status != "running" }
                if let running = list.first(where: { $0.status == "running" }) {
                    self.adoptRunningSession(running)
                }
            }
            // Preload any pre-existing insights in parallel.
            for s in list where s.status != "running" {
                Task {
                    if let ins = try? await api.fetchInsight(sessionId: s.id) {
                        await MainActor.run { self.insights[s.id] = ins }
                    }
                }
            }
        }
    }

    func generateInsight(for session: PomodoroSessionResponse) {
        generatingInsightFor = session.id
        insightError = nil
        Task {
            do {
                let ins = try await api.generateInsight(sessionId: session.id)
                self.insights[session.id] = ins
            } catch {
                self.insightError = "Generate failed: \(error.localizedDescription)"
            }
            self.generatingInsightFor = nil
        }
    }

    /// If the server has a session still in "running" state (e.g. app was quit
    /// mid-session), resume the timer locally so end() still works.
    private func adoptRunningSession(_ s: PomodoroSessionResponse) {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = parser.date(from: s.startedAt)
            ?? ISO8601DateFormatter().date(from: s.startedAt)
        guard let started = parsed else { return }
        startedAt = started
        goal = s.goal
        targetSeconds = s.targetSeconds
        currentSessionId = s.id
        isRunning = true
        elapsedSeconds = Int(Date().timeIntervalSince(started))
        startTimer()
    }
}

// MARK: - Page

struct PomodoroPage: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var vm = PomodoroViewModel.shared
    @State private var rightTab: RightTab = .current

    enum RightTab: String, CaseIterable {
        case current = "Current Session"
        case timeline = "Timeline"
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppMetrics.cardGap) {
            timerColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            rightColumn
                .frame(width: 320, alignment: .top)
        }
        .padding(AppMetrics.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Timer column

    private var timerColumn: some View {
        VStack(spacing: Spacing.space9) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .stroke(theme.border.opacity(0.3), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(theme.chartCyan, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: Spacing.space2) {
                    Text(vm.elapsedText)
                        .font(AppFont.mono(FontSize.timer, .bold))
                        .foregroundStyle(theme.foreground)
                    Text(vm.isRunning ? "Focus running" : "Ready to start")
                        .font(AppFont.text(FontSize.sm))
                        .foregroundStyle(theme.mutedForeground)
                }
            }
            .frame(width: 260, height: 260)

            // Controls
            HStack(spacing: Spacing.space4) {
                if !vm.isRunning {
                    pomodoroButton("Start", icon: "play.fill", primary: true) { vm.start() }
                } else {
                    pomodoroButton("End Focus", icon: "stop.fill", primary: true) { vm.end() }
                    pomodoroButton("+5 min", icon: "plus", primary: false) { vm.addFiveMinutes() }
                    pomodoroButton("Discard", icon: "trash", primary: false) { vm.end(discard: true) }
                }
            }

            // Target picker
            HStack(spacing: Spacing.space3) {
                Text("Target:")
                    .font(AppFont.text(FontSize.sm))
                    .foregroundStyle(theme.mutedForeground)
                ForEach([15, 25, 45, 60], id: \.self) { m in
                    Button("\(m)m") { vm.resetTarget(minutes: m) }
                        .font(AppFont.text(FontSize.sm, .medium))
                        .foregroundStyle(vm.targetSeconds == m * 60 ? theme.foreground : theme.mutedForeground)
                        .padding(.horizontal, Spacing.space3).padding(.vertical, 3)
                        .background(vm.targetSeconds == m * 60 ? theme.secondary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                        .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dashboardCard()
    }

    // MARK: Right column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar
            HStack(spacing: 2) {
                ForEach(RightTab.allCases, id: \.self) { tab in
                    Button { rightTab = tab } label: {
                        Text(tab.rawValue)
                            .font(AppFont.text(FontSize.sm, .medium))
                            .foregroundStyle(rightTab == tab ? theme.foreground : theme.mutedForeground)
                            .padding(.horizontal, Spacing.space4).padding(.vertical, 5)
                            .background(rightTab == tab ? theme.secondary : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.space7).padding(.top, Spacing.space6).padding(.bottom, Spacing.space4)

            Divider().opacity(0.3)

            Group {
                switch rightTab {
                case .current:
                    currentSessionTab
                case .timeline:
                    timelineTab
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardCard()
    }

    private var currentSessionTab: some View {
        VStack(alignment: .leading, spacing: Spacing.space5) {
            SectionTitle(text: "Goal")
            TextField("I will [task] so that [outcome]…", text: $vm.goal, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AppFont.text(FontSize.base))
                .foregroundStyle(theme.foreground)
                .padding(Spacing.space4)
                .background(theme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                .lineLimit(3...6)

            // Implementation-intention nudge (Gollwitzer 1999).
            // Soft-validates: short goals don't get the full intention effect.
            if !vm.isRunning && vm.goal.trimmingCharacters(in: .whitespaces).count < 15 {
                HStack(spacing: Spacing.space2) {
                    Image(systemName: "lightbulb")
                        .font(AppFont.text(FontSize.xs))
                        .foregroundStyle(theme.accent)
                    Text("Tip: write an intention, not just a topic. \"Draft the migration spec\" beats \"work on DB\".")
                        .font(AppFont.text(FontSize.xs))
                        .foregroundStyle(theme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().opacity(0.3)

            SectionTitle(text: "Session Info")
            infoRow(label: "Target", value: "\(vm.targetSeconds / 60) min")
            infoRow(label: "Status", value: vm.isRunning ? "Running" : "Idle")
            if vm.isRunning {
                infoRow(label: "Elapsed", value: vm.elapsedText)
            }
        }
        .padding(Spacing.space7)
    }

    private var timelineTab: some View {
        VStack(alignment: .leading, spacing: Spacing.space3) {
            if vm.sessions.isEmpty {
                Text("No sessions yet today")
                    .font(AppFont.text(FontSize.base))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                ForEach(vm.sessions) { session in
                    timelineRow(session)
                    Divider().opacity(0.2)
                }
                if let err = vm.insightError {
                    Text(err).font(AppFont.text(FontSize.xs)).foregroundStyle(theme.warning)
                }
            }
        }
        .padding(Spacing.space7)
    }

    @ViewBuilder
    private func timelineRow(_ session: PomodoroSessionResponse) -> some View {
        let insight = vm.insights[session.id]
        VStack(alignment: .leading, spacing: Spacing.space1) {
            HStack(spacing: Spacing.space4) {
                Circle()
                    .fill(session.status == "completed" ? theme.success : theme.warning)
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight?.title ?? session.goal)
                        .font(AppFont.text(FontSize.base, insight != nil ? .semibold : .regular))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(2)
                    Text(formatIso(session.startedAt))
                        .font(AppFont.text(FontSize.xs))
                        .foregroundStyle(theme.mutedForeground)
                }
                Spacer()
                Text(formatDuration(session.durationSeconds))
                    .font(AppFont.mono(FontSize.sm))
                    .foregroundStyle(theme.mutedForeground)
            }
            if let desc = insight?.description {
                Text(desc)
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.leading, Spacing.space7)
            }
            HStack {
                Spacer()
                if vm.generatingInsightFor == session.id {
                    ProgressView().controlSize(.mini)
                } else {
                    Button {
                        vm.generateInsight(for: session)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles").font(AppFont.text(FontSize.xs2))
                            Text(insight == nil ? "Generate AI insight" : "Regenerate")
                                .font(AppFont.text(FontSize.xs))
                        }
                        .foregroundStyle(theme.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, Spacing.space1)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(AppFont.text(FontSize.sm)).foregroundStyle(theme.mutedForeground)
            Spacer()
            Text(value).font(AppFont.mono(FontSize.base)).foregroundStyle(theme.foreground)
        }
    }

    @ViewBuilder
    private func pomodoroButton(_ title: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.space2) {
                Image(systemName: icon).font(AppFont.text(FontSize.xs))
                Text(title).font(AppFont.text(FontSize.base, .medium))
            }
            .foregroundStyle(primary ? theme.primaryForeground : theme.foreground)
            .padding(.horizontal, Spacing.space6).padding(.vertical, 7)
            .background(primary ? theme.primary : theme.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private func formatIso(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) ?? Date()
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
#endif
