import React from 'react';

export interface ButtonProps {
  /** Button label or content */
  children: React.ReactNode;
  /** Visual style */
  variant?: 'primary' | 'secondary' | 'ghost' | 'destructive';
  /** Size — sm for toolbar/icon contexts, md for most, lg for primary CTAs */
  size?: 'sm' | 'md' | 'lg';
  /** Optional leading icon (SVG element or Lucide icon) */
  icon?: React.ReactNode;
  /** Disabled state — reduces opacity, blocks interaction */
  disabled?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}

/**
 * @startingPoint section="Components" subtitle="Primary, secondary, ghost, destructive variants" viewport="700x120"
 */
export declare function Button(props: ButtonProps): JSX.Element;
