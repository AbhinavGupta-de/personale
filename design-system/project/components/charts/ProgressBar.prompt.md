Horizontal fill bar for category/app breakdowns and weekday averages.

```jsx
// Category row with label + value
<ProgressBar value={63} color="var(--color-cat-code)" label="Code" showValue />

// App row (no label — rendered alongside other columns)
<ProgressBar value={45} color="var(--color-chart-purple)" height={6} />

// Focus score bar
<ProgressBar value={78} color="var(--color-chart-purple)" height={8} label="Monday" labelWidth={48} />

// Custom color from categoryColor helper
import { categoryColor } from '../core/CategoryBadge.jsx';
<ProgressBar value={cat.percent} color={categoryColor(cat.category)} />
```

## Notes
- Track color: `rgba(43,43,49,0.5)` (secondary at 50% opacity).
- Fill animates via CSS transition: `width 0.4s ease-out`.
- `value` is clamped 0–100.
- `height` defaults to 6px (matches --progress-bar-height token).
- `showValue` appends a right-aligned monospaced percentage.
