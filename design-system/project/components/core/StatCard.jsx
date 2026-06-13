import React from 'react';
import { SectionTitle } from './SectionTitle.jsx';

/**
 * Headline stat tile — used in Insights page and Productivity headlineRow.
 * Displays a large bold number with an uppercase label and small caption.
 */
export function StatCard({ title, value, caption, color, style }) {
  return (
    <div
      style={{
        background: 'var(--color-card)',
        borderRadius: 'var(--card-radius)',
        border: '1px solid rgba(43,43,49,0.5)',
        padding: '14px 16px',
        display: 'flex',
        flexDirection: 'column',
        gap: '6px',
        flex: 1,
        minWidth: 0,
        ...style,
      }}
    >
      <SectionTitle>{title}</SectionTitle>
      <div
        style={{
          fontSize: 'var(--text-2xl)',
          fontWeight: 'var(--font-weight-bold)',
          fontVariantNumeric: 'tabular-nums',
          color: color || 'var(--color-foreground)',
          lineHeight: 'var(--leading-tight)',
          fontFamily: 'var(--font-mono)',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
        }}
      >
        {value}
      </div>
      {caption && (
        <div
          style={{
            fontSize: 'var(--text-xs)',
            color: 'var(--color-muted-foreground)',
            fontFamily: 'var(--font-sans)',
            lineHeight: 1.4,
          }}
        >
          {caption}
        </div>
      )}
    </div>
  );
}
