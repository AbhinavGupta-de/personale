import React from 'react';
import { categoryColor } from '../core/CategoryBadge.jsx';

/**
 * Horizontal daily-timeline strip — colored blocks representing app sessions.
 * Mirrors HorizontalTimelineCard in DashboardCards.swift.
 */
export function TimelineBar({
  blocks = [],
  dayStart = 8,
  height = 36,
  style,
}) {
  const totalHours = 24;

  return (
    <div
      style={{
        position: 'relative',
        height,
        background: 'rgba(35,35,41,0.4)',
        borderRadius: '4px',
        overflow: 'hidden',
        ...style,
      }}
    >
      {blocks.map((block, i) => {
        const shiftedStart = ((block.start - dayStart + 24) % 24);
        const leftPct = (shiftedStart / totalHours) * 100;
        const widthPct = Math.max(0.4, ((block.end - block.start) / totalHours) * 100);
        const color = categoryColor(block.type);

        return (
          <div
            key={i}
            title={block.label ? `${block.label} · ${block.type}` : block.type}
            style={{
              position: 'absolute',
              top: 0,
              left: `${leftPct}%`,
              width: `${widthPct}%`,
              height: '100%',
              background: color,
              opacity: 0.85,
              borderRadius: '2px',
            }}
          />
        );
      })}
    </div>
  );
}
