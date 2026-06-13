import React from 'react';

export interface BadgeProps {
  children: React.ReactNode;
  /** Visual variant — maps to semantic color */
  variant?: 'default' | 'primary' | 'accent' | 'success' | 'warning' | 'destructive' | 'outline';
  style?: React.CSSProperties;
}

export declare function Badge(props: BadgeProps): JSX.Element;
