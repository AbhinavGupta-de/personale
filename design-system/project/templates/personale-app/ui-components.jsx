// ui-components.jsx — Shared UI primitives for Personale UI Kit
// Exports: window.UI

const { useState, useEffect, useRef, useCallback } = React;

// ── Utilities ────────────────────────────────────────────────
function formatDuration(secs) {
  if (!secs) return '0m';
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  if (h > 0 && m > 0) return `${h}h ${m}m`;
  if (h > 0) return `${h}h`;
  return `${m}m`;
}

function formatTime(secs) {
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

const CATEGORY_COLORS = {
  Code: '#7c5cfc', Browsing: '#f5a623', Communication: '#d64d8a',
  Design: '#00ccbf', Writing: '#35a882', Media: '#9b85f5',
  Utilities: '#6b7280', Reading: '#3b82f6', Other: '#3d4451',
};

function catColor(cat) {
  return CATEGORY_COLORS[cat] || CATEGORY_COLORS.Other;
}

// ── Card ─────────────────────────────────────────────────────
function Card({ children, style, ...rest }) {
  return (
    <div style={{
      background: 'var(--color-card)',
      borderRadius: '8px',
      border: '1px solid rgba(43,43,49,0.5)',
      ...style,
    }} {...rest}>
      {children}
    </div>
  );
}

// ── SectionLabel ─────────────────────────────────────────────
function SectionLabel({ children, style }) {
  return (
    <span style={{
      display: 'block',
      fontSize: '10px', fontWeight: 600, letterSpacing: '0.8px',
      textTransform: 'uppercase', color: 'var(--color-muted-foreground)',
      ...style,
    }}>
      {children}
    </span>
  );
}

// ── DonutChart ───────────────────────────────────────────────
function DonutChart({ segments, size = 130, holeRatio = 0.55, center }) {
  const conicParts = [];
  let cum = 0;
  segments.forEach(seg => {
    const deg = seg.percent * 3.6;
    conicParts.push(`${seg.color} ${cum}deg ${cum + deg}deg`);
    cum += deg;
  });
  const holeSize = size * holeRatio;
  const holePad = (size - holeSize) / 2;

  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <div style={{
        width: size, height: size, borderRadius: '50%',
        background: `conic-gradient(${conicParts.join(', ')})`,
        transform: 'rotate(-90deg)',
      }} />
      <div style={{
        position: 'absolute', top: holePad, left: holePad,
        width: holeSize, height: holeSize, borderRadius: '50%',
        background: 'var(--color-card)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        {center}
      </div>
    </div>
  );
}

// ── CircularRing ─────────────────────────────────────────────
function CircularRing({ value = 0, size = 200, strokeWidth = 8, color = '#7c5cfc', children }) {
  const r = (size - strokeWidth) / 2;
  const circ = 2 * Math.PI * r;
  const offset = circ * (1 - Math.min(1, Math.max(0, value)));
  return (
    <div style={{ position: 'relative', width: size, height: size, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ position: 'absolute', top: 0, left: 0 }}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="rgba(43,43,49,0.6)" strokeWidth={strokeWidth} />
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color}
          strokeWidth={strokeWidth} strokeLinecap="round"
          strokeDasharray={circ} strokeDashoffset={offset}
          transform={`rotate(-90 ${size/2} ${size/2})`}
          style={{ transition: 'stroke-dashoffset 0.5s ease-out' }} />
      </svg>
      <div style={{ position: 'relative', zIndex: 1, textAlign: 'center' }}>{children}</div>
    </div>
  );
}

// ── BarFill ──────────────────────────────────────────────────
function BarFill({ value, color, height = 6, style }) {
  return (
    <div style={{ height, borderRadius: 2, background: 'rgba(43,43,49,0.5)', overflow: 'hidden', ...style }}>
      <div style={{
        width: `${Math.min(100, Math.max(0, value))}%`, height: '100%',
        background: color, borderRadius: 2, transition: 'width 0.4s ease',
      }} />
    </div>
  );
}

// ── TimelineStrip ─────────────────────────────────────────────
function TimelineStrip({ blocks, dayStart = 8 }) {
  return (
    <div style={{ position: 'relative', height: 36, borderRadius: 4, background: 'rgba(35,35,41,0.4)', overflow: 'hidden' }}>
      {blocks.map((b, i) => {
        const left = ((b.start - dayStart + 24) % 24) / 24 * 100;
        const width = Math.max(0.5, (b.end - b.start) / 24 * 100);
        return (
          <div key={i} title={b.label || b.type} style={{
            position: 'absolute', top: 0, height: '100%',
            left: `${left}%`, width: `${width}%`,
            background: catColor(b.type), opacity: 0.85, borderRadius: 2,
          }} />
        );
      })}
    </div>
  );
}

// ── Divider ──────────────────────────────────────────────────
function Divider({ style }) {
  return <div style={{ height: 1, background: 'rgba(43,43,49,0.4)', ...style }} />;
}

window.UI = {
  formatDuration, formatTime, catColor, CATEGORY_COLORS,
  Card, SectionLabel, DonutChart, CircularRing, BarFill, TimelineStrip, Divider,
};
