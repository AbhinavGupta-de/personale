import React from 'react';

/**
 * Horizontal segmented tab switcher. Used in Pomodoro, Productivity, Insights pages.
 * Matches the DateNavigator view toggle and page section tabs in AppShell.swift.
 */
export function TabBar({ tabs, activeTab, onTabChange, size = 'md', style }) {
  return (
    <div
      style={{
        display: 'inline-flex',
        gap: '2px',
        padding: '3px',
        background: 'rgba(35,35,41,0.8)',
        borderRadius: '7px',
        ...style,
      }}
    >
      {tabs.map((tab) => (
        <button
          key={tab}
          onClick={() => onTabChange(tab)}
          style={{
            fontSize: size === 'sm' ? 'var(--text-xs)' : 'var(--text-sm)',
            fontWeight: 'var(--font-weight-medium)',
            fontFamily: 'var(--font-sans)',
            color: activeTab === tab
              ? 'var(--color-foreground)'
              : 'var(--color-muted-foreground)',
            background: activeTab === tab ? 'var(--color-card)' : 'transparent',
            border: 'none',
            borderRadius: '5px',
            padding: size === 'sm' ? '3px 8px' : '4px 10px',
            cursor: 'pointer',
            transition: 'color 0.12s, background 0.12s',
            outline: 'none',
            whiteSpace: 'nowrap',
          }}
        >
          {tab}
        </button>
      ))}
    </div>
  );
}
