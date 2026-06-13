import React from 'react';

export interface StatCardProps {
  /** Section label (rendered ALL CAPS) */
  title: string;
  /** The big number or value to display */
  value: string;
  /** Optional secondary caption line */
  caption?: string;
  /** Override text color for the value (e.g. use --color-accent for timer values) */
  color?: string;
  style?: React.CSSProperties;
}

/**
 * @startingPoint section="Components" subtitle="Headline stat tile — title, big value, caption" viewport="700x100"
 */
export declare function StatCard(props: StatCardProps): JSX.Element;
