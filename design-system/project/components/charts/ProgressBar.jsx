import React from 'react';

/**
 * Horizontal fill-bar for category/app breakdowns.
 * Used in CategoriesListCard, AppsWebsitesCard, DayOfWeekCard in AppShell.swift.
 */
export function ProgressBar({
  value = 0,
  color = 'var(--color-chart-purple)',
  height = 6,
  label,
  labelWidth = 80,
  showValue = false,
  style,
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        width: '100%',
        ...style,
      }}
    >
      {label !== undefined && (
        <span
          style={{
            fontSize: 'var(--text-sm)',
            fontWeight: 'var(--font-weight-medium)',
            color: 'var(--color-foreground)',
            fontFamily: 'var(--font-sans)',
            width: labelWidth,
            flexShrink: 0,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {label}
        </span>
      )}
      <div
        style={{
          flex: 1,
          height,
          borderRadius: 'var(--progress-bar-radius)',
          background: 'rgba(43,43,49,0.5)',
          position: 'relative',
          overflow: 'hidden',
          minWidth: 40,
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: 0,
            top: 0,
            height: '100%',
            width: `${Math.min(100, Math.max(0, value))}%`,
            background: color,
            borderRadius: 'var(--progress-bar-radius)',
            transition: 'width 0.4s ease-out',
          }}
        />
      </div>
      {showValue && (
        <span
          style={{
            fontSize: 'var(--text-sm)',
            fontFamily: 'var(--font-mono)',
            fontVariantNumeric: 'tabular-nums',
            color: 'var(--color-muted-foreground)',
            minWidth: 32,
            textAlign: 'right',
          }}
        >
          {Math.round(value)}%
        </span>
      )}
    </div>
  );
}
