Horizontal segmented control for switching between views or sections.

```jsx
// Page section tabs (Productivity page)
const [tab, setTab] = React.useState('Focus');
<TabBar tabs={['Focus','Breaks','Meetings','Goals']} activeTab={tab} onTabChange={setTab} />

// Date view toggle (DateNavigator)
<TabBar tabs={['Day','Week']} activeTab="Day" onTabChange={setView} size="sm" />

// Insights range toggle
<TabBar tabs={['7d','30d','90d']} activeTab="30d" onTabChange={setRange} size="sm" />
```

## Notes
- Renders all tabs in a single pill container (muted bg, 7px radius).
- Active tab gets `var(--color-card)` background — visible lift against the pill bg.
- Inactive tabs use `var(--color-muted-foreground)` text.
- `size="sm"` → 10px text, 3px/8px padding. `size="md"` → 11px, 4px/10px.
- Keep labels short (≤10 chars). Use `Select` for 5+ options or long labels.
