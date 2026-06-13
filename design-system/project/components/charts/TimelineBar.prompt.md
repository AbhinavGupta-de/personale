Horizontal daily timeline strip — colored blocks represent app sessions over 24 hours.

```jsx
const blocks = [
  { start: 8,   end: 9.5,  type: 'Code',          label: 'VS Code' },
  { start: 9.5, end: 10,   type: 'Communication',  label: 'Slack' },
  { start: 10,  end: 12,   type: 'Code',            label: 'VS Code' },
  { start: 12,  end: 12.5, type: 'Browsing',        label: 'Chrome' },
  { start: 13,  end: 14.5, type: 'Code',            label: 'Cursor' },
  { start: 14.5,end: 15,   type: 'Design',          label: 'Figma' },
];

<TimelineBar blocks={blocks} dayStart={8} />
```

## Notes
- The bar spans 24 hours starting from `dayStart`.
- Each block's left offset and width are computed as `(relativeHour / 24) * 100%`.
- Block colors come from `categoryColor()` in CategoryBadge.
- `label` appears as an HTML `title` tooltip on hover.
- Minimum block width is 0.4% to keep tiny sessions visible.
- Height defaults to 36px (matches `--timeline-bar-height` token).
