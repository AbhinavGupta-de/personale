Color-coded activity category indicator — dot + optional label. Use everywhere an activity type is shown.

```jsx
<CategoryBadge category="Code" />
<CategoryBadge category="Communication" size="sm" />
<CategoryBadge category="Design" showLabel={false} size="lg" />

// Dot-only in a tight list row:
<CategoryBadge category={row.category} showLabel={false} />

// Get the raw color for SVG/canvas:
import { categoryColor } from './CategoryBadge.jsx';
const color = categoryColor('Browsing'); // '#f5a623'
```

## Category → Color Map
| Category | Color |
|---|---|
| Code | #7C5CFC (purple) |
| Browsing | #F5A623 (amber) |
| Communication | #D64D8A (pink) |
| Design | #00CCBF (cyan) |
| Writing | #35A882 (teal) |
| Media | #9B85F5 (light purple) |
| Utilities | #6B7280 (gray) |
| Reading | #3B82F6 (blue) |
| Other | #3D4451 (dark gray) |

## Notes
- Unknown categories fall back to "Other" (#3D4451).
- Case-insensitive match (e.g. "code" → "Code").
- `categoryColor()` is exported separately for SVG chart fills, progress bar colors, etc.
