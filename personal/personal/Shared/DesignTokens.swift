#if os(macOS)
import SwiftUI

// MARK: - Design Tokens (single source of truth)
//
// These mirror the Personale design system token CSS exactly, 1:1:
//   design-system/project/tokens/spacing.css     → Spacing, Radius, AppMetrics
//   design-system/project/tokens/typography.css  → FontSize, AppFont, Tracking, Leading
//   design-system/project/tokens/colors.css      → Theme.swift (colors live there)
//
// Rule: NO hardcoded sizes/spacing/radii in views. Reference these tokens so a
// single edit here re-themes the whole app and the app stays consistent with
// the design system. When the design changes, change the value here only.

// MARK: Spacing — 4px base grid (--space-1 … --space-10)

enum Spacing {
    static let space1: CGFloat = 4
    static let space2: CGFloat = 6
    static let space3: CGFloat = 8
    static let space4: CGFloat = 10
    static let space5: CGFloat = 12
    static let space6: CGFloat = 14
    static let space7: CGFloat = 16
    static let space8: CGFloat = 20
    static let space9: CGFloat = 24
    static let space10: CGFloat = 32

    // Semantic aliases (also defined in spacing.css)
    static let cardGap: CGFloat = 14
    static let cardPaddingX: CGFloat = 16
    static let cardPaddingY: CGFloat = 14
    static let contentPadding: CGFloat = 20
}

// MARK: Radius (--radius-xs … --radius-pill)

enum Radius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8          // == card radius
    static let pill: CGFloat = 9999
    static let progressBar: CGFloat = 2
}

// MARK: Type scale (--text-2xs … --text-timer)

enum FontSize {
    static let xs2: CGFloat = 9     // --text-2xs
    static let xs: CGFloat = 10     // --text-xs
    static let sm: CGFloat = 11     // --text-sm
    static let base: CGFloat = 12   // --text-base
    static let md: CGFloat = 13     // --text-md
    static let lg: CGFloat = 15     // --text-lg
    static let xl: CGFloat = 20     // --text-xl
    static let xl2: CGFloat = 22    // --text-2xl
    static let xl3: CGFloat = 26    // --text-3xl
    static let xl4: CGFloat = 28    // --text-4xl
    static let timer: CGFloat = 48  // --text-timer
}

// MARK: Letter spacing (tracking) — em-based in the design, points in SwiftUI

enum Tracking {
    static let sectionEm: CGFloat = 0.08   // --tracking-section
    static let brandEm: CGFloat = 0.23     // --tracking-brand

    /// SwiftUI `.tracking()` takes points; the design defines em (relative to
    /// font size). Convert at the call site: `.tracking(Tracking.points(0.08, FontSize.xs))`.
    static func points(_ em: CGFloat, _ size: CGFloat) -> CGFloat { em * size }

    static var section: CGFloat { points(sectionEm, FontSize.xs) }   // 0.8 @ 10px
}

// MARK: Line height (--leading-*)

enum Leading {
    static let tight: CGFloat = 1.2
    static let normal: CGFloat = 1.5
    static let relaxed: CGFloat = 1.65
}

// MARK: Font factory — proportional + tabular-mono for all numeric data

enum AppFont {
    /// Proportional UI text (SF Pro / system).
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Monospaced, tabular-nums — durations, percentages, timestamps, counts.
    /// The design mandates mono tabular-nums for ALL numeric data.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Named roles from the type hierarchy
    static var brand: Font { text(FontSize.md, .semibold) }       // PERSONALE wordmark
    static var pageHeader: Font { text(FontSize.lg, .semibold) }
    static var sectionTitle: Font { text(FontSize.xs, .semibold) } // ALL-CAPS labels
    static var body: Font { text(FontSize.base) }
    static var caption: Font { text(FontSize.sm) }
    static var timer: Font { mono(FontSize.timer, .medium) }
}

// MARK: - Extended layout metrics (mirror spacing.css; AppMetrics core lives in Theme.swift)

extension AppMetrics {
    static let sidebarIconSize: CGFloat = 36
    static let avatarSizeSm: CGFloat = 24
    static let dotSizeSm: CGFloat = 6
    static let dotSizeMd: CGFloat = 8
    static let timelineBarHeight: CGFloat = 36
    static let progressBarHeight: CGFloat = 6
    static let cardPaddingX: CGFloat = 16
    static let cardPaddingY: CGFloat = 14
}
#endif
