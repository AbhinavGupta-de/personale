import React from 'react';

/** Fixed category→color map (matches CategoryColors.map in Theme.swift) */
export const CATEGORY_COLORS = {
  Code:          '#7c5cfc',
  Browsing:      '#f5a623',
  Communication: '#d64d8a',
  Design:        '#00ccbf',
  Writing:       '#35a882',
  Media:         '#9b85f5',
  Utilities:     '#6b7280',
  Reading:       '#3b82f6',
  Other:         '#3d4451',
};

export function categoryColor(cat) {
  if (CATEGORY_COLORS[cat]) return CATEGORY_COLORS[cat];
  const c = cat ? cat.charAt(0).toUpperCase() + cat.slice(1) : 'Other';
  return CATEGORY_COLORS[c] || CATEGORY_COLORS.Other;
}

/**
 * Category color dot + optional label — used in list rows, session cards, timeline tooltips.
 */
export function CategoryBadge({
  category,
  showDot = true,
  showLabel = true,
  size = 'md',
  style,
}) {
  const color = categoryColor(category);
  const dotSize = size === 'sm' ? 5 : size === 'lg' ? 9 : 7;
  const fontSize = size === 'sm' ? 'var(--text-2xs)' : 'var(--text-sm)';

  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '5px',
        ...style,
      }}
    >
      {showDot && (
        <span
          style={{
            width: dotSize,
            height: dotSize,
            borderRadius: '50%',
            background: color,
            flexShrink: 0,
          }}
        />
      )}
      {showLabel && (
        <span
          style={{
            fontSize,
            color: 'var(--color-foreground)',
            fontFamily: 'var(--font-sans)',
          }}
        >
          {category}
        </span>
      )}
    </span>
  );
}
