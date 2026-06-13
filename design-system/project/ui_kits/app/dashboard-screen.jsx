// dashboard-screen.jsx — Personale Dashboard
// Exports: window.DashboardScreen

function DashboardScreen() {
  const { formatDuration, catColor, Card, SectionLabel, DonutChart, BarFill, TimelineStrip } = window.UI;
  const m = window.MOCK;
  const [dateOffset, setDateOffset] = React.useState(0);

  const HOURS = [8, 10, 12, 14, 16, 18];
  const total = m.totalSeconds;
  const pct = s => total > 0 ? Math.round(s / total * 100) : 0;

  return (
    <div style={{ height: '100%', overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}>

      {/* Date Navigator */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--color-foreground)' }}>
            {dateOffset === 0 ? m.date : dateOffset === -1 ? 'Wednesday, June 11, 2025' : 'Tuesday, June 10, 2025'}
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '3px 8px', borderRadius: 999, background: 'rgba(0,204,184,0.12)', fontSize: 11, fontWeight: 500, color: 'var(--color-accent)' }}>
            ✦ {m.freshStart}
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '3px 8px', borderRadius: 999, background: 'rgba(0,204,184,0.12)', fontSize: 11, fontWeight: 500, color: 'var(--color-accent)' }}>
            ⬥ {m.streak}d streak
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ display: 'flex', padding: 3, background: 'rgba(35,35,41,0.8)', borderRadius: 7 }}>
            {['Day','Week'].map(v => (
              <button key={v} onClick={() => {}} style={{ fontSize: 11, fontWeight: 500, color: v === 'Day' ? 'var(--color-foreground)' : 'var(--color-muted-foreground)', background: v === 'Day' ? 'var(--color-card)' : 'transparent', border: 'none', borderRadius: 5, padding: '4px 10px', cursor: 'pointer' }}>{v}</button>
            ))}
          </div>
          <button onClick={() => setDateOffset(o => o - 1)} style={navBtnStyle}>‹</button>
          {dateOffset < 0 && (
            <button onClick={() => setDateOffset(0)} style={{ ...navBtnStyle, fontSize: 11, padding: '4px 10px', color: 'var(--color-primary)', background: 'rgba(123,86,210,0.12)', borderRadius: 6 }}>Today</button>
          )}
          <button onClick={() => setDateOffset(o => Math.min(0, o + 1))} style={{ ...navBtnStyle, opacity: dateOffset >= 0 ? 0.3 : 1 }}>›</button>
        </div>
      </div>

      {/* Timeline */}
      <Card style={{ padding: '14px 16px 14px' }}>
        <SectionLabel style={{ marginBottom: 10 }}>Timeline</SectionLabel>
        <TimelineStrip blocks={m.timeline} dayStart={8} />
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6 }}>
          {HOURS.map(h => (
            <span key={h} style={{ fontSize: 9, fontFamily: 'monospace', color: 'var(--color-muted-foreground)' }}>
              {h < 12 ? `${h}AM` : h === 12 ? '12PM' : `${h - 12}PM`}
            </span>
          ))}
        </div>
      </Card>

      {/* 3-col row */}
      <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
        {/* Pie chart */}
        <Card style={{ width: 300, padding: '14px 16px 16px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
          <SectionLabel style={{ width: '100%' }}>Breakdown</SectionLabel>
          <DonutChart
            segments={m.categories}
            size={140}
            center={
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 13, fontWeight: 700, fontFamily: 'monospace', color: 'var(--color-foreground)' }}>
                  {formatDuration(total)}
                </div>
                <div style={{ fontSize: 9, color: 'var(--color-muted-foreground)' }}>tracked</div>
              </div>
            }
          />
        </Card>

        {/* Categories */}
        <Card style={{ flex: 1, padding: '14px 16px 14px', minHeight: 260 }}>
          <SectionLabel style={{ marginBottom: 10 }}>Categories</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
            {m.categories.map(cat => (
              <div key={cat.category} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)', width: 28, textAlign: 'right' }}>{cat.percent}%</span>
                <div style={{ width: 40, height: 6, borderRadius: 2, background: cat.color, opacity: 0.75 }} />
                <span style={{ fontSize: 11, color: 'var(--color-foreground)', flex: 1 }}>{cat.category}</span>
                <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)' }}>{formatDuration(cat.totalSeconds)}</span>
              </div>
            ))}
          </div>
        </Card>

        {/* Apps */}
        <Card style={{ width: 320, padding: '14px 16px 14px', minHeight: 260 }}>
          <SectionLabel style={{ marginBottom: 10 }}>Apps</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
            {m.apps.map(app => (
              <div key={app.appName} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)', width: 28, textAlign: 'right' }}>{app.percent}%</span>
                <BarFill value={app.percent} color="rgba(124,92,252,0.65)" height={6} style={{ width: 40, flex: 'none' }} />
                <span style={{ fontSize: 11, color: 'var(--color-foreground)', flex: 1 }}>{app.appName}</span>
                <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)' }}>{formatDuration(app.totalSeconds)}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Goals */}
      <Card style={{ padding: '14px 16px 14px' }}>
        <SectionLabel style={{ marginBottom: 10 }}>Goals</SectionLabel>
        <div style={{ display: 'flex', gap: 20 }}>
          {m.goals.map(g => {
            const progress = Math.min(1, g.currentHours / g.targetHours);
            return (
              <div key={g.category} style={{ flex: 1 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                    <span style={{ width: 7, height: 7, borderRadius: '50%', background: g.color, display: 'inline-block' }} />
                    <span style={{ fontSize: 11, color: 'var(--color-foreground)' }}>{g.category}</span>
                  </div>
                  <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)' }}>
                    {g.currentHours.toFixed(1)}h / {g.targetHours}h
                  </span>
                </div>
                <BarFill value={progress * 100} color={g.color} height={6} />
              </div>
            );
          })}
        </div>
      </Card>

      {/* Sessions strip */}
      <Card style={{ padding: '14px 0 14px' }}>
        <SectionLabel style={{ marginBottom: 10, paddingLeft: 16 }}>Today's Sessions</SectionLabel>
        <div style={{ display: 'flex', gap: 10, overflowX: 'auto', paddingLeft: 16, paddingRight: 16, paddingBottom: 2 }}>
          {m.sessions.map(s => (
            <div key={s.id} style={{
              minWidth: 200, padding: 10, flexShrink: 0,
              background: 'rgba(35,35,41,0.4)', borderRadius: 8,
              border: '1px solid rgba(43,43,49,0.3)',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: catColor(s.name), flexShrink: 0 }} />
                <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--color-foreground)' }}>{s.name}</span>
              </div>
              <div style={{ fontSize: 10, fontFamily: 'monospace', color: 'var(--color-muted-foreground)', marginBottom: 4 }}>{s.startTime} – {s.endTime}</div>
              <div style={{ fontSize: 13, fontWeight: 700, fontFamily: 'monospace', color: 'var(--color-foreground)', marginBottom: 6 }}>{formatDuration(s.durationSeconds)}</div>
              <div style={{ height: 1, background: 'rgba(43,43,49,0.4)', marginBottom: 6 }} />
              {s.apps.slice(0, 3).map(a => (
                <div key={a.appName} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 3 }}>
                  <span style={{ fontSize: 10, color: 'var(--color-muted-foreground)' }}>{a.appName}</span>
                  <span style={{ fontSize: 10, fontFamily: 'monospace', color: 'var(--color-muted-foreground)' }}>{a.percent}%</span>
                </div>
              ))}
            </div>
          ))}
        </div>
      </Card>

      {/* Websites */}
      <Card style={{ padding: '14px 16px 14px', marginBottom: 4 }}>
        <SectionLabel style={{ marginBottom: 10 }}>Websites</SectionLabel>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
          {m.websites.map(w => (
            <div key={w.domain} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)', width: 28, textAlign: 'right' }}>{pct(w.seconds)}%</span>
              <span style={{ width: 7, height: 7, borderRadius: '50%', background: catColor(w.category), flexShrink: 0 }} />
              <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-foreground)', flex: 1 }}>{w.domain}</span>
              <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)' }}>{formatDuration(w.seconds)}</span>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}

const navBtnStyle = { fontSize: 12, color: 'var(--color-muted-foreground)', background: 'transparent', border: 'none', cursor: 'pointer', width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center' };

window.DashboardScreen = DashboardScreen;
