SVG donut ring progress indicator. Used for focus score (Productivity) and as the Pomodoro timer ring.

```jsx
// Focus score circle with centered label
<CircularProgress value={78} size={120} strokeWidth={10} color="var(--color-chart-purple)">
  <div>
    <div style={{fontSize:28,fontWeight:700}}>78</div>
    <div style={{fontSize:9,color:'var(--color-muted-foreground)'}}>score</div>
  </div>
</CircularProgress>

// Small progress ring (no center content)
<CircularProgress value={62} size={48} strokeWidth={4.5} color="var(--color-accent)" />

// Pomodoro timer ring
<CircularProgress value={progress * 100} size={260} strokeWidth={10} color="var(--color-chart-cyan)" />
```

## Notes
- `value` is clamped to 0–100.
- Ring fills clockwise from the 12 o'clock position.
- Track (unfilled) color is always `var(--color-border)`.
- Fill animates via CSS transition: `stroke-dashoffset 0.6s ease-out`.
- `children` renders centered inside the ring — use for number labels, icons.
- Default color is `var(--color-chart-purple)`.
