Status badge / tag for session states, streaks, and contextual labels.

```jsx
<Badge variant="primary">7d streak</Badge>
<Badge variant="accent">Fresh start at 8:00 AM</Badge>
<Badge variant="success">Tracking active</Badge>
<Badge variant="warning">Away</Badge>
<Badge variant="destructive">Blocked</Badge>
<Badge variant="default">Code</Badge>
```

## Variants
- `default` — muted secondary bg. Use for category names, neutral labels.
- `primary` — purple tint. Use for streaks, feature highlights.
- `accent` — cyan tint. Use for fresh-start, timer-running indicators.
- `success` — green tint. Use for completed sessions, on-track goals.
- `warning` — amber tint. Use for away sessions, approaching limits.
- `destructive` — red tint. Use for blocked apps, errors.
- `outline` — transparent with border. Use as a light-weight alternative.

## Notes
- Renders as `<span>` — safe inside `<p>` or flex rows.
- Always Sentence case for badge text (never ALL CAPS inside badge).
- Use `CategoryBadge` instead when rendering an activity category with its color dot.
