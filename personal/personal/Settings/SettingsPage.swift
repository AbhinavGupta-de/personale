#if os(macOS)
import SwiftUI

// MARK: - Settings Page

struct SettingsPage: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppMetrics.cardGap) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                }

                // Category Management
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        SectionTitle(text: "App Categories")
                        Spacer()
                        Text("\(viewModel.apps.count) apps tracked")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.mutedForeground)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                    Text("Change which category an app belongs to. This affects all stats and breakdowns.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                    // Header row
                    HStack(spacing: 0) {
                        Text("App Name")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Bundle ID")
                            .frame(width: 260, alignment: .leading)
                        Text("Category")
                            .frame(width: 160, alignment: .leading)
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(theme.secondary.opacity(0.5))

                    // App rows
                    VStack(spacing: 0) {
                        ForEach(viewModel.apps) { app in
                            HStack(spacing: 0) {
                                Text(app.appName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(theme.foreground)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(app.bundleId ?? "—")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.mutedForeground)
                                    .lineLimit(1)
                                    .frame(width: 260, alignment: .leading)

                                CategoryPicker(
                                    currentCategory: app.category,
                                    categories: viewModel.allCategories
                                ) { newCategory in
                                    viewModel.updateCategory(bundleId: app.bundleId, appName: app.appName, to: newCategory)
                                }
                                .frame(width: 160, alignment: .leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(theme.border.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }

                    Spacer(minLength: 14)
                }
                .dashboardCard()

                // Database Info
                VStack(alignment: .leading, spacing: 0) {
                    SectionTitle(text: "Database")
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                    VStack(alignment: .leading, spacing: 6) {
                        infoRow(label: "Location", value: viewModel.dbPath)
                        infoRow(label: "Total Sessions", value: "\(viewModel.totalSessions)")
                        infoRow(label: "Category Mappings", value: "\(viewModel.totalMappings)")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .dashboardCard()
            }
            .padding(AppMetrics.contentPadding)
        }
        .onAppear { viewModel.load() }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }
}

// MARK: - Category Picker

struct CategoryPicker: View {
    let currentCategory: String
    let categories: [String]
    let onChange: (String) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            ForEach(categories, id: \.self) { cat in
                Button {
                    if cat != currentCategory {
                        onChange(cat)
                    }
                } label: {
                    HStack {
                        Text(cat)
                        if cat == currentCategory {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(CategoryColors.color(for: currentCategory))
                    .frame(width: 8, height: 8)
                Text(currentCategory)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.foreground)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.mutedForeground)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
#endif
