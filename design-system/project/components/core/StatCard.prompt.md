Headline stat tile — a card surface with a section title, large bold monospaced value, and caption.

```jsx
<StatCard title="Productive" value="6h 32m" caption="of 8h 0m tracked" />
<StatCard title="Avg / Day" value="5h 14m" caption="7 days with data" />
<StatCard title="Streak" value="7 days" caption="current" color="var(--color-accent)" />
<StatCard title="Focus Score" value="78" caption="above avg" />
```

## Notes
- The value renders with `font-family: var(--font-mono)` and `font-variant-numeric: tabular-nums` — always monospaced.
- Use `color` prop to override value color for accent/semantic meaning (e.g. accent cyan for timer).
- `flex: 1` by default — drop multiple StatCards in a `display:flex; gap:14px` row for the Insights headline row pattern.
- `caption` is optional — omit for raw numeric tiles.
