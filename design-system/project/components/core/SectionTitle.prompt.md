ALL-CAPS section label rendered above every card section. Mirrors SectionTitle in Theme.swift.

```jsx
<SectionTitle>Timeline</SectionTitle>
<SectionTitle>Apps &amp; Websites</SectionTitle>
<SectionTitle>Today's Sessions</SectionTitle>
```

## Notes
- Text is automatically uppercased via CSS — pass the label in normal case.
- Always rendered at `10px`, `font-weight: 600`, `letter-spacing: 0.8px`, muted foreground color.
- Typically placed 14px from card top, 16px from card left edge (matching --card-padding-y / --card-padding-x).
- Renders as `<span style="display:block">` — wrap in a div if you need margin control.
