// app-shell.jsx — Personale App Shell
// Main entry: mounts <App /> to #root

const { useState, useEffect, useRef } = React;

// ── Icons ────────────────────────────────────────────────────
const I = {
  house:     <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>,
  activity:  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>,
  review:    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2z"/><path d="m9 12 2 2 4-4"/></svg>,
  pomodoro:  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>,
  prod:      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>,
  insights:  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3Z"/></svg>,
  settings:  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>,
};

const NAV = [
  { id: 'dashboard',   icon: I.house,    label: 'Dashboard' },
  { id: 'activity',    icon: I.activity,  label: 'Activity' },
  { id: 'review',      icon: I.review,    label: 'Review' },
  { id: 'pomodoro',    icon: I.pomodoro,  label: 'Timer' },
  { id: 'productivity',icon: I.prod,      label: 'Productivity' },
  { id: 'insights',    icon: I.insights,  label: 'Insights' },
];

// ── Productivity Screen (inline) ─────────────────────────────
function ProductivityScreen() {
  const { catColor, Card, SectionLabel, BarFill, CircularRing } = window.UI;
  const [tab, setTab] = React.useState('Focus');
  const cats = window.MOCK.categories;

  return (
    <div style={{ padding: 20, height: '100%', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <span style={{ fontSize: 22, fontWeight: 700, color: 'var(--color-foreground)' }}>Productivity</span>
        <div style={{ display: 'flex', gap: 2, padding: 3, background: 'rgba(35,35,41,0.8)', borderRadius: 7 }}>
          {['Focus','Breaks','Meetings','Goals'].map(t => (
            <button key={t} onClick={() => setTab(t)} style={{
              fontSize: 11, fontWeight: 500,
              color: tab === t ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
              background: tab === t ? 'var(--color-card)' : 'transparent',
              border: 'none', borderRadius: 5, padding: '4px 10px', cursor: 'pointer',
            }}>{t}</button>
          ))}
        </div>
      </div>

      {tab === 'Focus' && (
        <>
          <div style={{ display: 'flex', gap: 14 }}>
            <Card style={{ width: 220, padding: '14px 16px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
              <SectionLabel style={{ width: '100%' }}>Avg Focus Score</SectionLabel>
              <CircularRing value={0.78} size={120} strokeWidth={10} color="var(--color-chart-purple)">
                <div style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: 28, fontWeight: 700, fontFamily: 'monospace', color: 'var(--color-foreground)' }}>78</div>
                  <div style={{ fontSize: 9, color: 'var(--color-muted-foreground)' }}>score</div>
                </div>
              </CircularRing>
            </Card>
            <Card style={{ flex: 1, padding: '14px 16px' }}>
              <SectionLabel style={{ marginBottom: 10 }}>Work Categories</SectionLabel>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
                {cats.map(c => (
                  <div key={c.category} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)', width: 28, textAlign: 'right' }}>{c.percent}%</span>
                    <span style={{ fontSize: 11, color: 'var(--color-foreground)', width: 110 }}>{c.category}</span>
                    <BarFill value={c.percent} color={c.color} height={6} style={{ flex: 1 }} />
                    <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)', width: 50, textAlign: 'right' }}>
                      {window.UI.formatDuration(c.totalSeconds)}
                    </span>
                  </div>
                ))}
              </div>
            </Card>
            <Card style={{ width: 260, padding: '14px 16px' }}>
              <SectionLabel style={{ marginBottom: 10 }}>Top Interruptors</SectionLabel>
              {[['Slack',14],['Twitter/X',8],['Email',6],['YouTube',4],['Linear',3]].map(([n,c]) => (
                <div key={n} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 7 }}>
                  <span style={{ fontSize: 11, color: 'var(--color-foreground)' }}>{n}</span>
                  <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--color-muted-foreground)' }}>{c}×</span>
                </div>
              ))}
            </Card>
          </div>
        </>
      )}
      {(tab === 'Meetings' || tab === 'Goals') && (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1, gap: 8, minHeight: 300 }}>
          <span style={{ fontSize: 22, color: 'var(--color-muted-foreground)', opacity: 0.4 }}>✦</span>
          <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--color-muted-foreground)' }}>{tab} — coming soon</span>
        </div>
      )}
      {tab === 'Breaks' && (
        <div style={{ display: 'flex', gap: 14 }}>
          {[['Breaks Taken','4'],['Avg Length','12m'],['Away Sessions','2']].map(([t,v])=>(
            <Card key={t} style={{ flex:1, padding:'14px 16px' }}>
              <SectionLabel style={{ marginBottom:6 }}>{t}</SectionLabel>
              <div style={{ fontSize:22, fontWeight:700, fontFamily:'monospace', color:'var(--color-foreground)' }}>{v}</div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Activity Screen (inline) ──────────────────────────────────
function ActivityScreen() {
  const { catColor, Card, SectionLabel, TimelineStrip } = window.UI;
  const m = window.MOCK;
  return (
    <div style={{ padding: 20, height: '100%', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--color-foreground)' }}>Thursday, June 12, 2025</span>
        <div style={{ display: 'flex', gap: 2, padding: 3, background: 'rgba(35,35,41,0.8)', borderRadius: 7 }}>
          {['Day','Week'].map(v => (
            <button key={v} style={{ fontSize:11, fontWeight:500, color: v==='Day' ? 'var(--color-foreground)' : 'var(--color-muted-foreground)', background: v==='Day' ? 'var(--color-card)' : 'transparent', border:'none', borderRadius:5, padding:'4px 10px', cursor:'pointer' }}>{v}</button>
          ))}
        </div>
      </div>
      <Card style={{ padding:'14px 16px' }}>
        <SectionLabel style={{ marginBottom:10 }}>Timeline</SectionLabel>
        <TimelineStrip blocks={m.timeline} dayStart={8} />
      </Card>
      <Card style={{ padding:'14px 16px' }}>
        <SectionLabel style={{ marginBottom:10 }}>Activity Log</SectionLabel>
        {[
          ['18:01','Notion','workspace/docs'],
          ['17:49','VS Code','personale/Theme.swift'],
          ['17:35','Chrome','github.com/pulls'],
          ['17:12','Slack','#engineering'],
          ['16:55','VS Code','personale/Dashboard.swift'],
          ['16:30','Figma','Design System — Components'],
          ['16:10','Arc','linear.app/issues'],
          ['15:45','Cursor','components/Button.jsx'],
          ['15:20','Slack','#design'],
          ['14:58','VS Code','app-shell.jsx'],
        ].map(([t,app,detail])=>(
          <div key={t+app} style={{ display:'flex', alignItems:'center', gap:10, marginBottom:7 }}>
            <span style={{ fontSize:10, fontFamily:'monospace', color:'var(--color-muted-foreground)', width:40 }}>{t}</span>
            <span style={{ fontSize:11, fontWeight:500, color:'var(--color-foreground)', width:80 }}>{app}</span>
            <span style={{ fontSize:10, fontFamily:'monospace', color:'var(--color-muted-foreground)', flex:1, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{detail}</span>
          </div>
        ))}
      </Card>
    </div>
  );
}

// ── Settings Screen (inline) ──────────────────────────────────
function SettingsScreen() {
  const { Card, SectionLabel, Divider } = window.UI;
  const [serverUrl, setServerUrl] = React.useState('http://localhost:8696');
  const [dayStart, setDayStart] = React.useState('8');
  const [dayEnd, setDayEnd] = React.useState('18');
  const [dailyTarget, setDailyTarget] = React.useState('8');

  return (
    <div style={{ padding: 20, height: '100%', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 14, maxWidth: 640 }}>
      <Card style={{ padding: '16px 20px' }}>
        <SectionLabel style={{ marginBottom: 14 }}>Server</SectionLabel>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <label style={{ fontSize: 11, color: 'var(--color-muted-foreground)' }}>Server URL</label>
          <input value={serverUrl} onChange={e => setServerUrl(e.target.value)} style={{ background:'var(--color-secondary)', border:'1px solid var(--color-border)', borderRadius:6, padding:'7px 10px', fontSize:12, color:'var(--color-foreground)', fontFamily:'monospace', outline:'none', width:'100%' }} />
        </div>
      </Card>
      <Card style={{ padding: '16px 20px' }}>
        <SectionLabel style={{ marginBottom: 14 }}>Work Day</SectionLabel>
        <div style={{ display: 'flex', gap: 20 }}>
          {[['Start hour', dayStart, setDayStart],['End hour', dayEnd, setDayEnd],['Daily target (h)', dailyTarget, setDailyTarget]].map(([lbl,val,set])=>(
            <div key={lbl} style={{ flex:1 }}>
              <label style={{ fontSize:11, color:'var(--color-muted-foreground)', display:'block', marginBottom:6 }}>{lbl}</label>
              <input type="number" value={val} onChange={e=>set(e.target.value)} style={{ background:'var(--color-secondary)', border:'1px solid var(--color-border)', borderRadius:6, padding:'7px 10px', fontSize:12, color:'var(--color-foreground)', outline:'none', width:'100%' }} />
            </div>
          ))}
        </div>
      </Card>
      <Card style={{ padding: '16px 20px' }}>
        <SectionLabel style={{ marginBottom: 14 }}>Idle Thresholds</SectionLabel>
        {[['Code','180s'],['Media','60s'],['Communication','30s'],['Other','120s']].map(([cat,val])=>(
          <div key={cat} style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:10 }}>
            <span style={{ fontSize:11, color:'var(--color-foreground)' }}>{cat}</span>
            <span style={{ fontSize:11, fontFamily:'monospace', color:'var(--color-muted-foreground)' }}>{val}</span>
          </div>
        ))}
      </Card>
    </div>
  );
}

// ── BottomBar ─────────────────────────────────────────────────
function BottomBar({ onPageChange }) {
  const { formatTime } = window.UI;
  const [focusOn, setFocusOn] = React.useState(true);
  const [secs, setSecs] = React.useState(1174);

  React.useEffect(() => {
    const t = setInterval(() => { if (focusOn) setSecs(s => Math.max(0, s - 1)); }, 1000);
    return () => clearInterval(t);
  }, [focusOn]);

  const progress = secs / 1800;
  const r = 9, circ = 2 * Math.PI * r;

  return (
    <div style={{
      height: 50, background: 'var(--color-card)',
      borderTop: '1px solid rgba(43,43,49,0.4)',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '0 16px', flexShrink: 0,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <button style={bareBtn} title="Tracking active">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#2bab7c" strokeWidth="2" strokeLinecap="round"><circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/></svg>
        </button>
        <button style={bareBtn} title="Continue">
          <svg width="10" height="10" viewBox="0 0 24 24" fill="#2bab7c" stroke="none"><polygon points="5 3 19 12 5 21 5 3"/></svg>
        </button>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg width="22" height="22" viewBox="0 0 22 22">
            <circle cx="11" cy="11" r={r} fill="none" stroke="rgba(43,43,49,0.6)" strokeWidth="2" />
            <circle cx="11" cy="11" r={r} fill="none" stroke="#00ccb8"
              strokeWidth="2" strokeLinecap="round"
              strokeDasharray={circ} strokeDashoffset={circ * (1 - progress)}
              transform="rotate(-90 11 11)" />
          </svg>
          <button onClick={() => onPageChange('pomodoro')} style={{ ...bareBtn, cursor: 'pointer' }}>
            <span style={{ fontSize: 13, fontWeight: 700, fontFamily: 'monospace', color: '#00ccb8', letterSpacing: '-0.5px' }}>{formatTime(secs)}</span>
          </button>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontSize: 7, fontWeight: 600, letterSpacing: '0.5px', color: 'var(--color-muted-foreground)', textTransform: 'uppercase' }}>Focus time</span>
            <span style={{ fontSize: 7, fontWeight: 600, letterSpacing: '0.5px', color: 'var(--color-muted-foreground)', textTransform: 'uppercase' }}>Remaining</span>
          </div>
        </div>
        <button onClick={() => setFocusOn(f => !f)} style={{
          fontSize: 11, fontWeight: 500, color: 'var(--color-foreground)',
          background: 'var(--color-secondary)', border: '1px solid rgba(43,43,49,0.6)',
          borderRadius: 6, padding: '5px 12px', cursor: 'pointer', fontFamily: 'inherit',
        }}>
          {focusOn ? 'End Focus' : 'Start Focus'} ˅
        </button>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ fontSize: 11, color: 'var(--color-muted-foreground)' }}>Silence</span>
        <button style={bareBtn}>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--color-muted-foreground)" strokeWidth="1.75" strokeLinecap="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/></svg>
        </button>
        <button style={bareBtn}>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--color-muted-foreground)" strokeWidth="1.75" strokeLinecap="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
        </button>
      </div>
    </div>
  );
}

const bareBtn = { background: 'transparent', border: 'none', cursor: 'default', padding: 4, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--color-muted-foreground)' };

// ── App ───────────────────────────────────────────────────────
function App() {
  const [page, setPage] = React.useState('dashboard');

  const pages = {
    dashboard:    window.DashboardScreen,
    activity:     ActivityScreen,
    review:       () => <div style={{padding:20,color:'var(--color-muted-foreground)',fontSize:13}}>Review — coming soon</div>,
    pomodoro:     window.PomodoroScreen,
    productivity: ProductivityScreen,
    insights:     window.InsightsScreen,
    settings:     SettingsScreen,
  };
  const CurrentPage = pages[page] || pages.dashboard;

  return (
    <div style={{ width: '100%', height: '100vh', display: 'flex', background: 'var(--color-background)', minWidth: 1100 }}>
      {/* Sidebar */}
      <div style={{
        width: 52, background: 'var(--color-card)',
        borderRight: '1px solid rgba(43,43,49,0.6)',
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', paddingTop: 12, paddingBottom: 12,
        flexShrink: 0,
      }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2, flex: 1 }}>
          {NAV.map(item => {
            const active = page === item.id;
            return (
              <button key={item.id} title={item.label} onClick={() => setPage(item.id)} style={{
                width: 36, height: 36, borderRadius: 8, border: 'none', cursor: 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                background: active ? 'rgba(123,86,210,0.12)' : 'transparent',
                color: active ? 'var(--color-primary)' : 'var(--color-muted-foreground)',
                transition: 'all 0.12s',
              }}>
                {item.icon}
              </button>
            );
          })}
        </div>
        <button title="Settings" onClick={() => setPage('settings')} style={{
          width: 36, height: 36, borderRadius: 8, border: 'none', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: page === 'settings' ? 'rgba(123,86,210,0.12)' : 'transparent',
          color: page === 'settings' ? 'var(--color-primary)' : 'var(--color-muted-foreground)',
        }}>
          {I.settings}
        </button>
      </div>

      {/* Main area */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* Top header */}
        <div style={{
          height: 42, borderBottom: '1px solid rgba(43,43,49,0.4)',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '0 20px', flexShrink: 0,
        }}>
          <div style={{ display: 'flex', gap: 2 }}>
            {['‹','›'].map(ch => (
              <button key={ch} style={{ ...bareBtn, width:28, height:28, cursor:'pointer', fontSize:14, color:'var(--color-muted-foreground)' }}>{ch}</button>
            ))}
          </div>
          <span style={{ fontSize: 13, fontWeight: 600, letterSpacing: '3px', color: 'rgba(224,224,224,0.8)' }}>PERSONALE</span>
          <div style={{
            width: 24, height: 24, borderRadius: '50%',
            background: 'var(--color-primary)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 9, fontWeight: 700, color: 'var(--color-primary-foreground)',
          }}>A</div>
        </div>

        {/* Page content */}
        <div style={{ flex: 1, overflow: 'hidden' }}>
          <CurrentPage />
        </div>

        {/* Bottom bar */}
        <BottomBar onPageChange={setPage} />
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
