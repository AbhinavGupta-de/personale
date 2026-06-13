import React from 'react';

/**
 * Status badge / tag used for categories, session states, and contextual labels.
 */
export function Badge({ children, variant = 'default', style }) {
  const variantMap = {
    default: {
      background: 'var(--color-secondary)',
      color: 'var(--color-foreground)',
    },
    primary: {
      background: 'rgba(123,86,210,0.12)',
      color: 'var(--color-primary)',
    },
    accent: {
      background: 'rgba(0,204,184,0.12)',
      color: 'var(--color-accent)',
    },
    success: {
      background: 'rgba(43,171,124,0.15)',
      color: 'var(--color-success)',
    },
    warning: {
      background: 'rgba(245,159,10,0.15)',
      color: 'var(--color-warning)',
    },
    destructive: {
      background: 'rgba(220,40,40,0.15)',
      color: 'var(--color-destructive)',
    },
    outline: {
      background: 'transparent',
      color: 'var(--color-foreground)',
      border: '1px solid var(--color-border)',
    },
  };

  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '4px',
        padding: '3px 8px',
        borderRadius: 'var(--radius-pill)',
        fontSize: 'var(--text-sm)',
        fontWeight: 'var(--font-weight-medium)',
        fontFamily: 'var(--font-sans)',
        lineHeight: 1.4,
        ...variantMap[variant],
        ...style,
      }}
    >
      {children}
    </span>
  );
}
