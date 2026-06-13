# Personale Design System

**Personale** is a local-first, open-source macOS productivity tracker — a fully self-hostable alternative to [Rize](https://rize.io). It passively monitors application usage and browser time, segments it by category (Code, Communication, Design…), runs a Pomodoro timer, and generates AI-written narratives from your data using BYOC (Bring Your Own Claude) API keys. All data stays on your machine.

---

## Sources & References

| Resource | URL / Path |
|---|---|
| GitHub repo (primary source) | https://github.com/AbhinavGupta-de/personale |
| Swift app source | `personal/personal/` |
| Theme & tokens | `personal/personal/Shared/Theme.swift` |
| App shell & layout | `personal/personal/Shell/AppShell.swift` |
| Dashboard screens | `personal/personal/Dashboard/` |
| Server (Spring Boot) | `server/src/` |
| Browser extension | `extension/src/` |

> The reader does NOT need repo access — this design system is self-contained. The URLs above are provided for deeper exploration.

---

## Product Overview

Personale has three components:

| Component | Tech | Purpose |
|---|---|---|
| **macOS App** (`personal/`) | Swift + SwiftUI | Menu-bar agent + dashboard window |
| **Server** (`server/`) | Java Spring Boot + PostgreSQL | Local REST API, time event store |
| **Browser Extension** (`extension/`) | TypeScript | Per-site tracking inside Chrome/Brave |

### App Pages (routes)

| Route | Icon | Description |
|---|---|---|
| Dashboard | house | Daily overview — timeline, pie, categories, sessions |
| Activity | globe | Detailed per-app timeline with day/week toggle |
| Review | checkmark.seal | Session review & annotation |
| Pomodoro | timer | Focus timer with goal-setting and AI insights |
| Productivity | chart.bar | Focus score, breaks, category breakdown |
| Insights | sparkles | Heatmap, streaks, trends, AI narrative |
| Settings | gear | Server URL, work day, idle thresholds |

---

## Using This Design System

1. **Link tokens**: `<link rel="stylesheet" href="path/to/styles.css">` in your HTML.
2. **Load components**: `<script src="path/to/_ds_bundle.js"></script>` then `const { Button } = window.Personale`.
3. **Load React** (pinned versions) before the bundle script.
4. See individual component `.prompt.md` files for usage examples.

---

## CONTENT FUNDAMENTALS

### Voice & Tone

Personale is a personal tool — it talks *to* the user about *their* data. The voice is:

- **Precise**: numbers and durations appear exactly as computed. No rounding without disclosure.
- **Neutral**: the app reports without judgment. "3h 12m in Browsing" — not "too much Browsing."
- **Terse**: labels are 1–3 words. Tooltips add detail if needed. No filler phrases.
- **Direct**: uses "you" sparingly. Prefer imperative labels ("Start Focus", "End Focus") over possessive ("Your focus time").

### Copy Patterns

| Pattern | Example |
|---|---|
| Duration | `7h 51m` • `42 min` • `1:23:45` (timer) |
| Percentage | `63%` (no space before `%`) |
| Section titles | `TIMELINE` • `APPS & WEBSITES` (ALL CAPS) |
| Page titles | `Insights` • `Productivity` (Title Case) |
| Buttons | `Start Focus` • `End Focus` • `Generate` (Title Case) |
| Empty states | `No focus sessions yet` (Sentence case, no period) |
| Streak badge | `7d streak` (lowercase, compact) |
| Fresh start | `Fresh start at 8:00 AM` (Sentence case) |
| AI tip | `Tip: write an intention, not just a topic.` |

### Casing Rules

| Context | Rule |
|---|---|
| Section labels | ALL CAPS + letter-spacing 0.8px |
| Page headers | Title Case, bold |
| Buttons | Title Case |
| Body / list | Sentence case |
| Timestamps | `HH:mm` 24-hour or `8:00 AM` 12-hour |
| Dates | `Friday, January 29, 2021` (full) or `Jan 29` (compact) |

### Emoji & Unicode

**Never use emoji.** The app uses SF Symbols (`Image(systemName:)`) exclusively for iconography. On web, use Lucide icons as the substitute. Unicode characters (e.g. `·`, `–`, `×`) are acceptable in data display.

---

## VISUAL FOUNDATIONS

### Color System

Personale is **dark-only** — no light mode exists or is planned. The palette is cool near-black with a purple primary and cyan accent.

#### Surface Hierarchy (light-to-dark, darkest = base)

```
#101014  --color-background     Page / window bg
#17171C  --color-card           Card surface
#1F1F23  --color-muted          Subtle section bg
#232329  --color-secondary      Input bg, active tab bg
#2B2B31  --color-border         1px dividers, card outlines
```

#### Brand

- **Primary**: `#7B56D2` — purple. Used for active sidebar icons, primary buttons, progress highlights.
- **Accent**: `#00CCB8` — cyan/teal. Used for focus timer, streak counter, the "now" indicator.
- **Primary-foreground**: `#FAFAFA` — text on purple backgrounds.

#### Semantic

| Token | Hex | Use |
|---|---|---|
| `--color-success` | `#2BAB7C` | Completed sessions, on-track goals, tracking active |
| `--color-warning` | `#F59F0A` | Away sessions, caution indicators |
| `--color-destructive` | `#DC2828` | Delete actions, errors |
| `--color-muted-foreground` | `#7A7A7A` | Secondary text, section titles, placeholders |

#### Category Color Map

Every activity category has a fixed color. This is the single source of truth (`CategoryColors.map` in Theme.swift):

| Category | Hex | CSS Token |
|---|---|---|
| Code | `#7C5CFC` | `--color-cat-code` |
| Browsing | `#F5A623` | `--color-cat-browsing` |
| Communication | `#D64D8A` | `--color-cat-communication` |
| Design | `#00CCBF` | `--color-cat-design` |
| Writing | `#35A882` | `--color-cat-writing` |
| Media | `#9B85F5` | `--color-cat-media` |
| Utilities | `#6B7280` | `--color-cat-utilities` |
| Reading | `#3B82F6` | `--color-cat-reading` |
| Other | `#3D4451` | `--color-cat-other` |

---

### Typography

**Font stack**: SF Pro Text / SF Pro Display on macOS → Inter (Google Fonts) as web fallback. SF Mono / Menlo for all numeric/data display.

Key rules:
- Base body text is **11–12px** — this is intentional. The dashboard is a data-dense instrument panel.
- All durations, percentages, and timestamps use **tabular-nums** (monospaced digit alignment) to prevent layout jitter as values update.
- Section titles are **ALL CAPS**, `9–10px`, `font-weight: 600`, `letter-spacing: 0.8px`, `--color-muted-foreground`.
- The brand wordmark `PERSONALE` is `13px`, `font-weight: 600`, `letter-spacing: 3px`.
- Large stat values (headline stats, Pomodoro timer) use `--font-mono`.

---

### Spacing

4px grid throughout. Key landmarks from `AppMetrics`:

| Token | Value | Notes |
|---|---|---|
| `--sidebar-width` | `52px` | Icon-only sidebar |
| `--header-height` | `42px` | Top header bar |
| `--bottom-bar-height` | `50px` | Focus timer bar |
| `--content-padding` | `20px` | Page outer gutter |
| `--card-gap` | `14px` | Gap between dashboard cards |
| `--card-padding-x` | `16px` | Card horizontal inner padding |
| `--card-radius` | `8px` | Card corner radius |

---

### Cards & Surfaces

Cards are the primary layout unit. The `DashboardCardModifier` in Swift defines the spec:

```
background:    var(--color-card)    #17171C
border-radius: var(--card-radius)   8px
border:        1px solid rgba(43,43,49,0.5)   (--color-border at 50% opacity)
box-shadow:    none                  (no shadows — flat design)
```

Cards have **no shadow**. Depth is created purely through surface color layering.

---

### Layout

- **Sidebar**: Fixed left, 52px, icon-only. Right edge has a 1px `--color-border` at 60% opacity.
- **Top header**: 42px, contains back/forward nav + centered "PERSONALE" wordmark + avatar.
- **Bottom bar**: 50px, fixed to bottom, overlays content. Contains focus timer + ambient controls.
- **Main content**: `padding: 20px`, vertical scroll, `VStack(spacing: 14px)`.
- Min window size: `1100 × 700px`.

---

### Animation & Motion

- **Easing**: `easeOut` — progress bars and circular rings animate on appearance.
- **Duration**: `0.8s` for circular progress, `0.5s` for bar progress fills.
- **Entrance**: fade-in only (opacity). No slides or bounces.
- **Timer countdown**: 1-second timer tick — no animation, just a number update.
- **No decorative loops**: no spinning, pulsing, or shimmer effects.
- **Reduced motion**: show end-state immediately.

---

### Interaction States

| State | Treatment |
|---|---|
| Hover | `opacity: 0.85` on interactive elements |
| Active/press | No scale transform — just `opacity: 0.7` |
| Disabled | `opacity: 0.5`, `cursor: not-allowed` |
| Active sidebar icon | `--color-primary` icon + `rgba(123,86,210,0.12)` bg pill |
| Active tab | `--color-secondary` bg, `--color-foreground` text |
| Focused input | `--color-border` outline, no glow |

---

### Backgrounds & Visual Texture

- **No gradients**: backgrounds are flat hex colors.
- **No images**: zero photography or illustrations.
- **No blur**: no backdrop-filter or glass effects (this differs from macOS native materials — the web version is purely flat).
- **No shadows**: depth from surface layering only.
- **No patterns or textures**.

---

### Iconography

#### Production: SF Symbols

The Swift app uses `Image(systemName:)` exclusively. Common icons:

| Context | SF Symbol |
|---|---|
| Dashboard | `house` |
| Activity | `globe` |
| Review | `checkmark.seal` |
| Pomodoro | `timer` |
| Productivity | `chart.bar` |
| Insights | `sparkles` |
| Settings | `gear` |
| Back/forward | `chevron.left`, `chevron.right` |
| Power/tracking | `power` |
| Play/stop | `play.fill`, `stop.fill`, `forward.fill` |
| Calendar | `calendar` |
| Trash | `trash` |
| Lightbulb | `lightbulb` |
| Flame (streak) | `flame.fill` |

#### Web substitute: Lucide Icons

For web/HTML artifacts, use [Lucide](https://lucide.dev) (`lucide-react` or CDN) as the SF Symbols substitute. Same stroke weight (1.5px), same fill style (line icons).

```html
<script src="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js"></script>
<i data-lucide="house"></i>
```

**Do not** draw custom SVG icons — always use Lucide or SF Symbols.

---

## File Index

```
styles.css                      Global CSS entry point (@imports only)
tokens/
  fonts.css                     Font stacks + Google Fonts import (Inter fallback)
  colors.css                    All --color-* custom properties
  typography.css                All --font-* / --text-* / --tracking-* tokens
  spacing.css                   All --space-* / --card-* / layout metric tokens
assets/
  logo.svg                      App icon mark (48×48)
  logo-wordmark.svg             Icon + PERSONALE wordmark (160×32)
components/
  core/                         Button, Badge, SectionTitle, StatCard,
                                TabBar, CategoryBadge, CircularProgress
                                (each has .jsx · .d.ts · .prompt.md)
  charts/                       ProgressBar, TimelineBar
                                (each has .jsx · .d.ts · .prompt.md)
guidelines/                     Foundation specimen cards (Design System tab)
  colors-brand.card.html        Primary purple + accent cyan
  colors-neutral.card.html      Surface stack (background → card → secondary → border)
  colors-semantic.card.html     Success · warning · destructive · tints
  colors-chart.card.html        9-color data visualization palette
  colors-category.card.html     Fixed activity-category color map
  dark-surfaces.card.html       Surface elevation via color alone
  type-scale.card.html          9px → 48px size scale
  type-hierarchy.card.html      Brand · page header · section title · body · caption
  type-data.card.html           Monospaced tabular-nums for durations/times/%
  spacing-scale.card.html       4px grid — --space-1 through --space-10
  layout-metrics.card.html      Sidebar 52px · header 42px · bottom bar 50px · card 8px
  card-anatomy.card.html        Card surface spec (bg, border, radius, padding)
  interaction-states.card.html  Hover · active · disabled · sidebar active
ui_kits/
  app/                          Interactive macOS app prototype (Dashboard,
                                Pomodoro, Insights, Productivity, Activity)
templates/
  personale-app/                Copyable starting point — full app shell
                                (ds-base.js loads the DS bundle automatically)
SKILL.md                        Agent skill descriptor for Claude Code
```

### Components Quick Reference

| Component | Props | Notes |
|---|---|---|
| `Button` | `variant`, `size`, `icon`, `disabled` | primary / secondary / ghost |
| `Badge` | `variant` | default / success / warning / destructive / primary / accent |
| `SectionTitle` | `children` | Renders ALL-CAPS section label |
| `StatCard` | `title`, `value`, `caption`, `color` | Headline stat tile |
| `TabBar` | `tabs`, `activeTab`, `onTabChange` | Horizontal segment switcher |
| `CategoryBadge` | `category`, `showDot`, `showLabel` | Color-coded activity category |
| `CircularProgress` | `value`, `size`, `strokeWidth`, `color` | SVG donut ring |
| `ProgressBar` | `value`, `color`, `label`, `showValue` | Horizontal fill bar |
| `TimelineBar` | `blocks`, `dayStart` | Daily activity timeline strip |
