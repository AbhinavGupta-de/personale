// pomodoro-screen.jsx — Personale Pomodoro Timer
// Exports: window.PomodoroScreen

function PomodoroScreen() {
  const { formatTime, catColor, Card, SectionLabel, CircularRing, Divider } = window.UI;
  const m = window.MOCK;

  const [isRunning, setIsRunning] = React.useState(false);
  const [elapsed, setElapsed] = React.useState(0);
  const [target, setTarget] = React.useState(25 * 60);
  const [goal, setGoal] = React.useState('');
  const [tab, setTab] = React.useState('Current Session');
  const [sessions, setSessions] = React.useState(m.pomodoroSessions);
  const [aiInsight, setAiInsight] = React.useState(null);
  const [generating, setGenerating] = React.useState(false);

  const intervalRef = React.useRef(null);

  React.useEffect(() => {
    if (isRunning) {
      intervalRef.current = setInterval(() => setElapsed(e => e + 1), 1000);
    } else {
      clearInterval(intervalRef.current);
    }
    return () => clearInterval(intervalRef.current);
  }, [isRunning]);

  const progress = Math.min(1, elapsed / target);

  const handleStart = () => { setElapsed(0); setIsRunning(true); };
  const handleEnd = () => {
    setIsRunning(false);
    const newSession = {
      id: sessions.length + 1,
      goal: goal || 'Untitled session',
      startTime: '17:00',
      durationSeconds: elapsed,
      status: elapsed >= target ? 'completed' : 'partial',
    };
    setSessions(s => [newSession, ...s]);
    setElapsed(0);
    setGoal('');
  };

  const handleGenerate = () => {
    setGenerating(true);
    setTimeout(() => {
      setAiInsight("Strong deep-work session. You stayed in Code for 78% of the time with minimal context switches. VS Code dominated — likely architecture or feature work given the 90-minute block.");
      setGenerating(false);
    }, 1800);
  };

  return (
    <div style={{ padding: 20, display: 'flex', gap: 14, height: '100%', overflow: 'hidden' }}>
      {/* Timer column */}
      <Card style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '32px 24px', gap: 0 }}>
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <CircularRing
            value={progress}
            size={240}
            strokeWidth={10}
            color="var(--color-chart-cyan)"
          >
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 48, fontWeight: 700, fontFamily: 'monospace', color: 'var(--color-foreground)', letterSpacing: '-2px', lineHeight: 1 }}>
                {formatTime(isRunning ? elapsed : target)}
              </div>
              <div style={{ fontSize: 11, color: 'var(--color-muted-foreground)', marginTop: 8 }}>
                {isRunning ? 'Focus running' : 'Ready to start'}
              </div>
            </div>
          </CircularRing>
        </div>

        {/* Controls */}
        <div style={{ display: 'flex', gap: 10, marginTop: 24 }}>
          {!isRunning ? (
            <button onClick={handleStart} style={pomoBtnStyle(true)}>
              ▶  Start
            </button>
          ) : (
            <>
              <button onClick={handleEnd} style={pomoBtnStyle(true)}>◼  End Focus</button>
              <button onClick={() => setTarget(t => t + 300)} style={pomoBtnStyle(false)}>+5 min</button>
              <button onClick={() => { setIsRunning(false); setElapsed(0); }} style={pomoBtnStyle(false)}>✕ Discard</button>
            </>
          )}
        </div>

        {/* Target picker */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 16 }}>
          <span style={{ fontSize: 11, color: 'var(--color-muted-foreground)' }}>Target:</span>
          {[15, 25, 45, 60].map(m => (
            <button key={m} onClick={() => setTarget(m * 60)} style={{
              fontSize: 11, fontWeight: 500,
              color: target === m * 60 ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
              background: target === m * 60 ? 'var(--color-secondary)' : 'transparent',
              border: 'none', borderRadius: 4, padding: '3px 8px', cursor: 'pointer',
            }}>{m}m</button>
          ))}
        </div>
      </Card>

      {/* Right column */}
      <Card style={{ width: 320, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* Tabs */}
        <div style={{ display: 'flex', gap: 2, padding: '14px 16px 10px' }}>
          {['Current Session', 'Timeline'].map(t => (
            <button key={t} onClick={() => setTab(t)} style={{
              fontSize: 11, fontWeight: 500,
              color: tab === t ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
              background: tab === t ? 'var(--color-secondary)' : 'transparent',
              border: 'none', borderRadius: 4, padding: '4px 10px', cursor: 'pointer',
            }}>{t}</button>
          ))}
        </div>
        <Divider />

        {tab === 'Current Session' ? (
          <div style={{ padding: 16, flex: 1, overflow: 'auto', display: 'flex', flexDirection: 'column', gap: 12 }}>
            <SectionLabel>Goal</SectionLabel>
            <textarea
              value={goal}
              onChange={e => setGoal(e.target.value)}
              placeholder="I will [task] so that [outcome]…"
              rows={3}
              style={{
                background: 'var(--color-secondary)', border: '1px solid var(--color-border)',
                borderRadius: 6, padding: 10, fontSize: 12, color: 'var(--color-foreground)',
                fontFamily: 'inherit', resize: 'none', outline: 'none', lineHeight: 1.5,
              }}
            />
            {!isRunning && goal.length > 0 && goal.length < 15 && (
              <div style={{ display: 'flex', gap: 6, padding: '8px 10px', background: 'rgba(0,204,184,0.08)', borderRadius: 6 }}>
                <span style={{ fontSize: 11, color: 'var(--color-accent)' }}>✦</span>
                <span style={{ fontSize: 10, color: 'var(--color-muted-foreground)', lineHeight: 1.5 }}>
                  Tip: write an intention, not just a topic. "Draft the migration spec" beats "work on DB".
                </span>
              </div>
            )}
            <Divider />
            <SectionLabel>Session Info</SectionLabel>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {[['Target', `${target / 60} min`], ['Status', isRunning ? 'Running' : 'Idle'], ...(isRunning ? [['Elapsed', formatTime(elapsed)]] : [])].map(([k, v]) => (
                <div key={k} style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontSize: 11, color: 'var(--color-muted-foreground)' }}>{k}</span>
                  <span style={{ fontSize: 12, fontFamily: 'monospace', color: 'var(--color-foreground)' }}>{v}</span>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div style={{ flex: 1, overflowY: 'auto', padding: '12px 16px' }}>
            {sessions.map((s, i) => (
              <div key={s.id}>
                <div style={{ display: 'flex', gap: 10, padding: '8px 0' }}>
                  <span style={{ width: 6, height: 6, borderRadius: '50%', background: s.status === 'completed' ? 'var(--color-success)' : 'var(--color-warning)', marginTop: 4, flexShrink: 0 }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 12, fontWeight: 500, color: 'var(--color-foreground)', marginBottom: 2 }}>{s.goal}</div>
                    <div style={{ fontSize: 10, color: 'var(--color-muted-foreground)', marginBottom: 4 }}>{s.startTime} · {s.durationSeconds < 3600 ? Math.floor(s.durationSeconds / 60) + 'm' : (s.durationSeconds / 3600).toFixed(1) + 'h'}</div>
                    {i === 0 && aiInsight && (
                      <div style={{ fontSize: 10, color: 'var(--color-muted-foreground)', lineHeight: 1.5, marginBottom: 4 }}>{aiInsight}</div>
                    )}
                    {i === 0 && (
                      <button onClick={handleGenerate} style={{ fontSize: 10, color: 'var(--color-primary)', background: 'transparent', border: 'none', cursor: 'pointer', padding: 0 }}>
                        {generating ? '…' : aiInsight ? '✦ Regenerate' : '✦ Generate AI insight'}
                      </button>
                    )}
                  </div>
                </div>
                {i < sessions.length - 1 && <Divider />}
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}

function pomoBtnStyle(primary) {
  return {
    display: 'inline-flex', alignItems: 'center', gap: 6,
    fontSize: 12, fontWeight: 500, fontFamily: 'inherit',
    color: primary ? 'var(--color-primary-foreground)' : 'var(--color-foreground)',
    background: primary ? 'var(--color-primary)' : 'var(--color-secondary)',
    border: primary ? 'none' : '1px solid rgba(43,43,49,0.6)',
    borderRadius: 7, padding: '7px 14px', cursor: 'pointer',
  };
}

window.PomodoroScreen = PomodoroScreen;
