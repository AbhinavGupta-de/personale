#if os(macOS)
import SwiftUI

/// Inline review editor shown as a popover anchored to an Activity Day view
/// session block. Editing here PUTs to the same /api/reviews/{key} endpoint
/// as the Review page — edits flow to the Dashboard + Review page immediately
/// on the next fetch.
struct InlineReviewPopover: View {
    let session: FocusSessionResponse
    let dateString: String                          // "yyyy-MM-dd"
    let availableCategories: [String]
    let initialReview: SessionReviewResponse?       // may be nil (first time)
    let formatDuration: (Int) -> String
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme
    private let api = APIClient.shared

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: String = ""
    @State private var task: String = ""
    @State private var project: String = ""
    @State private var client: String = ""
    @State private var status: String = "pending"
    @State private var aiTitle: String? = nil
    @State private var aiDescription: String? = nil
    @State private var generating = false
    @State private var saving = false
    @State private var errorMessage: String?

    private var blockKey: String {
        ReviewKey.make(
            date: dateString,
            startTime: session.startTime,
            endTime: session.endTime,
            category: session.name
        )
    }

    private var timeRangeText: String {
        let dur = formatDuration(session.durationSeconds)
        return "\(session.startTime) – \(session.endTime) · \(dur)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            header

            Divider().opacity(0.3)

            TextField("Title", text: $title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AppFont.text(FontSize.md, .semibold))
                .foregroundStyle(theme.foreground)
                .padding(Spacing.space4)
                .background(theme.secondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                .lineLimit(1...3)

            TextField("Description — what specifically did you do?",
                      text: $description, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AppFont.text(FontSize.sm))
                .foregroundStyle(theme.foreground)
                .padding(Spacing.space4)
                .background(theme.secondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                .lineLimit(3...8)

            HStack(spacing: Spacing.space2) {
                field(icon: "checkmark.square", placeholder: "Task", text: $task)
                field(icon: "folder", placeholder: "Project", text: $project)
                field(icon: "person", placeholder: "Client", text: $client)
            }

            if let err = errorMessage {
                Text(err).font(AppFont.text(FontSize.xs)).foregroundStyle(theme.warning)
            }

            HStack(spacing: Spacing.space2) {
                Button {
                    Task { await save(autoApprove: true) }
                } label: {
                    HStack(spacing: Spacing.space1) {
                        if saving { ProgressView().controlSize(.mini) }
                        Text("Save & Accept").font(AppFont.text(FontSize.sm, .semibold))
                    }
                    .foregroundStyle(theme.primaryForeground)
                    .padding(.horizontal, Spacing.space5).padding(.vertical, 5)
                    .background(theme.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(saving)

                Button {
                    Task { await setStatus("rejected") }
                } label: {
                    Text("Reject")
                        .font(AppFont.text(FontSize.sm))
                        .foregroundStyle(theme.foreground)
                        .padding(.horizontal, Spacing.space5).padding(.vertical, 5)
                        .background(theme.secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(saving)

                Spacer()

                if status == "approved" {
                    statusBadge(text: "Approved", color: theme.success)
                } else if status == "rejected" {
                    statusBadge(text: "Rejected", color: theme.mutedForeground)
                }
            }
        }
        .padding(Spacing.space6)
        .frame(width: 420)
        .onAppear { populate() }
    }

    // MARK: — Header (category picker + AI button)

    private var header: some View {
        HStack(spacing: Spacing.space3) {
            Menu {
                ForEach(availableCategories, id: \.self) { cat in
                    Button {
                        category = cat
                    } label: {
                        HStack {
                            Circle().fill(CategoryColors.color(for: cat)).frame(width: 6, height: 6)
                            Text(cat)
                            if cat == category { Spacer(); Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(CategoryColors.color(for: category)).frame(width: 7, height: 7)
                    Text(category.uppercased())
                        .font(AppFont.text(FontSize.xs, .semibold)).tracking(0.4)
                    Image(systemName: "chevron.down").font(.system(size: 8)).opacity(0.5)
                }
                .foregroundStyle(theme.foreground)
                .padding(.horizontal, Spacing.space3).padding(.vertical, Spacing.space1)
                .background(theme.secondary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Text(timeRangeText)
                .font(AppFont.mono(FontSize.sm))
                .foregroundStyle(theme.mutedForeground)

            Button {
                Task { await generate() }
            } label: {
                HStack(spacing: Spacing.space1) {
                    if generating {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "sparkles").font(AppFont.text(FontSize.xs))
                    }
                    Text(aiTitle == nil ? "AI" : "Regen")
                        .font(AppFont.text(FontSize.xs, .medium))
                }
                .foregroundStyle(theme.primary)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(theme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(generating)
        }
    }

    @ViewBuilder
    private func field(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: Spacing.space1) {
            Image(systemName: icon).font(AppFont.text(FontSize.xs2)).foregroundStyle(theme.mutedForeground)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(AppFont.text(FontSize.sm))
                .foregroundStyle(theme.foreground)
        }
        .padding(.horizontal, Spacing.space2).padding(.vertical, Spacing.space1)
        .background(theme.secondary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
        .frame(maxWidth: .infinity)
    }

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(AppFont.text(FontSize.xs2, .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.space2).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: — Data

    private func populate() {
        if let r = initialReview {
            title = r.title ?? r.aiTitle ?? ""
            description = r.description ?? r.aiDescription ?? ""
            category = r.category
            task = r.task ?? ""
            project = r.project ?? ""
            client = r.client ?? ""
            status = r.status
            aiTitle = r.aiTitle
            aiDescription = r.aiDescription
        } else {
            category = session.name
        }
    }

    private func save(autoApprove: Bool) async {
        saving = true
        defer { saving = false }
        do {
            let req = SessionReviewUpdateRequest(
                title: title.isEmpty ? nil : title,
                description: description.isEmpty ? nil : description,
                task: task.isEmpty ? nil : task,
                project: project.isEmpty ? nil : project,
                client: client.isEmpty ? nil : client,
                // Always send the explicit choice. Sending nil when it
                // matches session.name silently kept the previously-saved
                // override, so switching back to the auto-category looked
                // like a no-op.
                category: category.isEmpty ? nil : category
            )
            _ = try await api.updateReview(key: blockKey, date: dateString, req: req)
            if autoApprove {
                let r = try await api.setReviewStatus(key: blockKey, date: dateString, status: "approved")
                status = r.status
            }
            errorMessage = nil
            DispatchQueue.main.async { onDismiss() }
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func setStatus(_ new: String) async {
        saving = true
        defer { saving = false }
        do {
            let r = try await api.setReviewStatus(key: blockKey, date: dateString, status: new)
            status = r.status
            DispatchQueue.main.async { onDismiss() }
        } catch {
            errorMessage = "Status failed: \(error.localizedDescription)"
        }
    }

    private func generate() async {
        generating = true
        defer { generating = false }
        do {
            let r = try await api.generateReviewInsight(key: blockKey, date: dateString)
            aiTitle = r.aiTitle
            aiDescription = r.aiDescription
            // Regen is explicit intent — replace current draft with fresh AI output.
            if let t = r.aiTitle { title = t }
            if let d = r.aiDescription { description = d }
            errorMessage = nil
        } catch {
            errorMessage = "Generate failed: \(error.localizedDescription)"
        }
    }
}
#endif
