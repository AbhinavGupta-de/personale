#if os(macOS)
import SwiftUI

// MARK: - Theme Protocol

protocol AppTheme {
    // Core
    var background: Color { get }
    var foreground: Color { get }
    var card: Color { get }
    var cardForeground: Color { get }

    // Surfaces
    var secondary: Color { get }
    var muted: Color { get }
    var mutedForeground: Color { get }

    // Accents
    var primary: Color { get }
    var primaryForeground: Color { get }
    var accent: Color { get }

    // Semantic
    var success: Color { get }
    var warning: Color { get }
    var destructive: Color { get }

    // Borders
    var border: Color { get }

    // Chart
    var chartPurple: Color { get }
    var chartPurpleLight: Color { get }
    var chartCyan: Color { get }
    var chartTeal: Color { get }
    var chartPink: Color { get }
    var chartAmber: Color { get }
    var chartBlue: Color { get }
    var chartGray: Color { get }
    var chartGrayLight: Color { get }
}

// MARK: - Shared category→hex color map (single source of truth)

enum CategoryColors {
    static let map: [String: UInt] = [
        "Code": 0x7C5CFC,
        "Browsing": 0xF5A623,
        "Communication": 0xD64D8A,
        "Design": 0x00CCBF,
        "Writing": 0x35A882,
        "Media": 0x9B85F5,
        "Utilities": 0x6B7280,
        "Reading": 0x3B82F6,
        "Other": 0x3D4451,
    ]

    static let fallback: UInt = 0x3D4451

    static func color(for category: String) -> Color {
        Color(hex: map[category] ?? fallback)
    }
}

// MARK: - Activity color lookup (shared across themes)

extension AppTheme {
    func activityColor(for type: String) -> Color {
        // Try exact match from CategoryColors first (real API data: "Code", "Browsing", etc.)
        if CategoryColors.map[type] != nil {
            return CategoryColors.color(for: type)
        }
        // Fallback: capitalize first letter for lowercased input ("code" → "Code")
        let capitalized = type.prefix(1).uppercased() + type.dropFirst()
        if CategoryColors.map[capitalized] != nil {
            return CategoryColors.color(for: capitalized)
        }
        return CategoryColors.color(for: type)
    }
}

// MARK: - Dark Theme (default — matches dashboard-designs CSS tokens)

struct DarkTheme: AppTheme {
    // Converted from CSS HSL tokens in dashboard-designs/frontend/src/index.css
    let background = Color(hex: 0x101014)
    let foreground = Color(white: 0.88)
    let card = Color(hex: 0x17171C)
    let cardForeground = Color(white: 0.88)

    let secondary = Color(hex: 0x232329)
    let muted = Color(hex: 0x1F1F23)
    let mutedForeground = Color(white: 0.48)

    let primary = Color(hex: 0x7B56D2)
    let primaryForeground = Color(white: 0.98)
    let accent = Color(hex: 0x00CCB8)

    let success = Color(hex: 0x2BAB7C)
    let warning = Color(hex: 0xF59F0A)
    let destructive = Color(hex: 0xDC2828)

    let border = Color(hex: 0x2B2B31)

    let chartPurple = Color(hex: 0x7C5CFC)
    let chartPurpleLight = Color(hex: 0x9B85F5)
    let chartCyan = Color(hex: 0x00CCBF)
    let chartTeal = Color(hex: 0x35A882)
    let chartPink = Color(hex: 0xD64D8A)
    let chartAmber = Color(hex: 0xF5A623)
    let chartBlue = Color(hex: 0x3B82F6)
    let chartGray = Color(hex: 0x3D4451)
    let chartGrayLight = Color(hex: 0x6B7280)
}

// MARK: - Environment key for theme injection

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = DarkTheme()
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - AppMetrics Constants (theme-independent)

enum AppMetrics {
    static let sidebarWidth: CGFloat = 52
    static let topHeaderHeight: CGFloat = 42
    static let bottomBarHeight: CGFloat = 50
    static let cardCornerRadius: CGFloat = 8
    static let contentPadding: CGFloat = 20
    static let cardGap: CGFloat = 14
}

// MARK: - Color hex extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Card Modifier

struct DashboardCardModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius)
                    .stroke(theme.border.opacity(0.5), lineWidth: 1)
            )
    }
}

extension View {
    func dashboardCard() -> some View {
        modifier(DashboardCardModifier())
    }
}

// MARK: - Section Title

struct SectionTitle: View {
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(theme.mutedForeground)
    }
}

// MARK: - Circular Progress

struct CircularProgress: View {
    let value: Double  // 0-100
    let size: CGFloat
    let strokeWidth: CGFloat
    let color: Color
    @Environment(\.theme) private var theme

    init(value: Double, size: CGFloat = 52, strokeWidth: CGFloat = 4, color: Color) {
        self.value = value
        self.size = size
        self.strokeWidth = strokeWidth
        self.color = color
    }

    private var radius: CGFloat { (size - strokeWidth) / 2 }
    private var circumference: CGFloat { 2 * .pi * radius }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.border, lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: value / 100)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: value)
        }
        .frame(width: size, height: size)
    }
}
#endif
