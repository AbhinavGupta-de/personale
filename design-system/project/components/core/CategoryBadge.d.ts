import React from 'react';

export interface CategoryBadgeProps {
  /** Activity category name — must match CategoryColors.map keys */
  category: string;
  /** Show the color dot (default true) */
  showDot?: boolean;
  /** Show the category name label (default true) */
  showLabel?: boolean;
  /** sm=5px dot/9px text, md=7px/11px, lg=9px/13px */
  size?: 'sm' | 'md' | 'lg';
  style?: React.CSSProperties;
}

/** Returns the hex color string for a given category name */
export declare function categoryColor(category: string): string;

export declare function CategoryBadge(props: CategoryBadgeProps): JSX.Element;
