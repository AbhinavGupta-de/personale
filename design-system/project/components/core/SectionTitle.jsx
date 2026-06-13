import React from 'react';

/**
 * ALL-CAPS section label — used above every card section in the dashboard.
 * Mirrors SectionTitle in Theme.swift.
 */
export function SectionTitle({ children, style }) {
  return (
    <span
      style={{
        display: 'block',
        fontSize: 'var(--text-xs)',
        fontWeight: 'var(--font-weight-semibold)',
        letterSpacing: 'var(--tracking-section)',
        textTransform: 'uppercase',
        color: 'var(--color-muted-foreground)',
        fontFamily: 'var(--font-sans)',
        lineHeight: 1,
        ...style,
      }}
    >
      {children}
    </span>
  );
}
