// insights-screen.jsx — Personale Insights
// Exports: window.InsightsScreen

function InsightsScreen() {
  const { Card, SectionLabel, BarFill } = window.UI;
  const ins = window.MOCK.insights;
  const [range, setRange] = React.useState('30d');
  const [narrative, setNarrative] = React.useState(null);
  const [generating, setGenerating] = React.useState(false);

  const maxDow = Math.max(...ins.dayOfWeek.map(d => d.avgHours));
  const maxTrend = Math.max(...ins.trend.map(d => d.hours));
  const WEEKDAYS = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  const handleGenerate = () => {
    setGenerating(true);
    setTimeout(() => {
      setNarrative({
        summary: "Strong 30-day period with consistent deep-work blocks. Code dominated at 63% — well above your 50% baseline. Wednesday shows peak focus, likely linked to your no-meeting policy.",
        patterns: ["10–12 AM is your peak window: 40% more productive than afternoons.", "Context switches spike on Thursdays — likely sprint review overhead."],
        wins: ["7-day current streak — longest in 2 months.", "Design time up 3% vs prior period."],
        watchouts: ["Browsing crept up on Friday afternoons — consider a distraction block after 3 PM."],
      });
      setGenerating(false);
    }, 2000);
  };

  return (
    <div style={{ height: '100%', overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}>

      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <span style={{ fontSize: 22, fontWeight: 700, color: 'var(--color-foreground)' }}>Insights</span>
        <div style={{ display: 'flex', gap: 2, padding: 3, background: 'rgba(35,35,41,0.8)', borderRadius: 7 }}>
          {['7d','30d','90d'].map(r => (
            <button key={r} onClick={() => setRange(r)} style={{
              fontSize: 11, fontWeight: 500,
              color: range === r ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
              background: range === r ? 'var(--color-card)' : 'transparent',
              border: 'none', borderRadius: 5, padding: '4px 10px', cursor: 'pointer',
            }}>{r}</button>
          ))}
        </div>
      </div>

      {/* Headline stats */}
      <div style={{ display: 'flex', gap: 14 }}>
        {[
          { title: 'Productive', value: ins.totalProductive, caption: `of ${ins.totalTracked} tracked` },
          { title: 'Avg / Day', value: ins.avgPerDay, caption: `${ins.daysWithData} days with data` },
          { title: 'Switches / Day', value: ins.avgSwitches, caption: `${ins.totalSwitches} total` },
          { title: 'Best Day', value: ins.bestDay.label, caption: `${ins.bestDay.hours} avg` },
          { title: 'Peak Hour', value: ins.peakHour.label, caption: ins.peakHour.hours },
        ].map(s => (
          <Card key={s.title} style={{ flex: 1, padding: '14px 14px 12px' }}>
            <SectionLabel style={{ marginBottom: 6 }}>{s.title}</SectionLabel>
            <div style={{ fontSize: 20, fontWeight: 700, fontFamily: 'monospace', color: 'var(--color-foreground)', marginBottom: 4, lineHeight: 1.1 }}>{s.value}</div>
            <div style={{ fontSize: 10, color: 'var(--color-muted-foreground)' }}>{s.caption}</div>
          </Card>
        ))}
      </div>

      {/* Heatmap + Day of week */}
      <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
        <Card style={{ flex: 1, padding: '14px 16px 14px', overflowX: 'auto' }}>
          <SectionLabel style={{ marginBottom: 10 }}>Productive Hours · Weekday × Hour</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <div style={{ display: 'flex', marginLeft: 26, marginBottom: 2, gap: 2 }}>
              {Array.from({length:24},(_,h)=>(
                <div key={h} style={{ flex:1, fontSize:7, fontFamily:'monospace', color:'var(--color-muted-foreground)', textAlign:'center' }}>
                  {h%6===0?h:''}
                </div>
              ))}
            </div>
            {WEEKDAYS.map((day, row) => (
              <div key={day} style={{ display:'flex', alignItems:'center', gap:2 }}>
                <span style={{ width:24, fontSize:9, fontWeight:500, color:'var(--color-muted-foreground)', flexShrink:0 }}>{day}</span>
                {ins.heatmap[row].map((intensity, col) => (
                  <div key={col} style={{
                    flex:1, height:14, borderRadius:2,
                    background: intensity > 0.01 ? `rgba(124,92,252,${Math.min(0.9, 0.12 + intensity * 0.88)})` : 'rgba(43,43,49,0.3)',
                  }} />
                ))}
              </div>
            ))}
          </div>
        </Card>

        <Card style={{ width: 280, padding: '14px 16px 14px', flexShrink: 0 }}>
          <SectionLabel style={{ marginBottom: 10 }}>Average by Weekday</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
            {ins.dayOfWeek.map(d => (
              <div key={d.label} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 11, fontWeight: 500, color: 'var(--color-foreground)', width: 28 }}>{d.label}</span>
                <BarFill value={(d.avgHours / maxDow) * 100} color="var(--color-chart-purple)" height={7} style={{ flex: 1 }} />
                <span style={{ fontSize: 10, fontFamily: 'monospace', color: 'var(--color-muted-foreground)', width: 44, textAlign: 'right' }}>{d.avgHours.toFixed(1)}h</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Trend + Streak */}
      <div style={{ display: 'flex', gap: 14 }}>
        <Card style={{ flex: 1, padding: '14px 16px 14px' }}>
          <SectionLabel style={{ marginBottom: 10 }}>Daily Trend</SectionLabel>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, height: 100 }}>
            {ins.trend.map((d, i) => (
              <div key={i} title={`${d.hours.toFixed(1)}h`} style={{
                flex: 1,
                height: `${Math.max(4, (d.hours / maxTrend) * 96)}px`,
                background: 'var(--color-chart-purple)',
                borderRadius: '1px 1px 0 0',
                opacity: 0.75 + (i / ins.trend.length) * 0.25,
              }} />
            ))}
          </div>
        </Card>

        <Card style={{ width: 220, padding: '14px 16px 14px' }}>
          <SectionLabel style={{ marginBottom: 12 }}>Productive Streak</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[['current', ins.streaks.current], ['longest', ins.streaks.longest]].map(([label, val]) => (
              <div key={label} style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                <span style={{ fontSize: 26, fontWeight: 700, fontFamily: 'monospace', color: 'var(--color-foreground)' }}>{val}</span>
                <span style={{ fontSize: 11, color: 'var(--color-muted-foreground)' }}>days {label}</span>
              </div>
            ))}
            <span style={{ fontSize: 9, color: 'var(--color-muted-foreground)', lineHeight: 1.4 }}>
              Day counts when you log {ins.streaks.thresholdHours}+ productive hrs.
            </span>
          </div>
        </Card>
      </div>

      {/* AI Narrative */}
      <Card style={{ padding: '14px 16px 14px', marginBottom: 4 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <SectionLabel>AI Narrative</SectionLabel>
          <button onClick={handleGenerate} disabled={generating} style={{
            display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11, fontWeight: 500,
            color: 'var(--color-primary-foreground)', background: generating ? 'rgba(123,86,210,0.6)' : 'var(--color-primary)',
            border: 'none', borderRadius: 6, padding: '5px 10px', cursor: generating ? 'default' : 'pointer',
          }}>
            {generating ? '…' : '✦'} {narrative ? 'Regenerate' : 'Generate'}
          </button>
        </div>
        {narrative ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <p style={{ fontSize: 12, color: 'var(--color-foreground)', lineHeight: 1.6, margin: 0 }}>{narrative.summary}</p>
            {[['PATTERNS', narrative.patterns, 'var(--color-chart-purple)'], ['WINS', narrative.wins, 'var(--color-success)'], ['WATCHOUTS', narrative.watchouts, 'var(--color-warning)']].map(([title, items, color]) => items.length > 0 && (
              <div key={title}>
                <div style={{ fontSize: 9, fontWeight: 600, letterSpacing: '0.8px', color, marginBottom: 6 }}>{title}</div>
                {items.map((item, i) => (
                  <div key={i} style={{ display: 'flex', gap: 6, marginBottom: 4 }}>
                    <span style={{ width: 4, height: 4, borderRadius: '50%', background: color, marginTop: 6, flexShrink: 0 }} />
                    <span style={{ fontSize: 12, color: 'var(--color-foreground)', lineHeight: 1.6 }}>{item}</span>
                  </div>
                ))}
              </div>
            ))}
          </div>
        ) : (
          <p style={{ fontSize: 11, color: 'var(--color-muted-foreground)', margin: 0 }}>
            Hit Generate for an AI-written recap of this period — patterns, wins, and watchouts grounded in your data.
          </p>
        )}
      </Card>
    </div>
  );
}

window.InsightsScreen = InsightsScreen;
