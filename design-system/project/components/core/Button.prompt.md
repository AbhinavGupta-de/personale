Primary action button for Personale interfaces.

```jsx
<Button variant="primary" onClick={handleStart}>Start Focus</Button>
<Button variant="secondary" icon={<PlusIcon />}>+5 min</Button>
<Button variant="ghost" size="sm">Discard</Button>
<Button variant="destructive" size="sm">Delete</Button>
<Button variant="primary" disabled>Generating…</Button>
```

## Variants
- `primary` — filled purple (#7B56D2), white text. Use for the single primary CTA per view.
- `secondary` — muted surface (#232329), default text. Use for supporting actions.
- `ghost` — transparent bg. Use for icon-adjacent text actions, nav back/forward.
- `destructive` — red tint. Use for delete/discard only.

## Sizes
- `sm` — 11px, 26px height. Toolbar, inline actions.
- `md` — 12px, 30px height. Default for most contexts.
- `lg` — 13px, 36px height. Primary CTAs in empty-state or modal contexts.

## Notes
- Hover: opacity 0.85. Press: opacity 0.7.
- Always combine icon + label for ambiguous actions (don't rely on icon alone outside sidebars).
- Never use emoji in button labels — use Lucide or SF Symbols.
