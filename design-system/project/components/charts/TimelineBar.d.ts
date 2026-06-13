import React from 'react';

export interface TimelineBlock {
  /** Start hour as decimal (e.g. 9.5 = 9:30 AM) */
  start: number;
  /** End hour as decimal */
  end: number;
  /** Activity category name — used to look up color */
  type: string;
  /** Optional hover tooltip label */
  label?: string;
}

export interface TimelineBarProps {
  blocks: TimelineBlock[];
  /** Hour that the timeline starts from (default 8 = 8 AM) */
  dayStart?: number;
  /** Bar height in px (default 36) */
  height?: number;
  style?: React.CSSProperties;
}

export declare function TimelineBar(props: TimelineBarProps): JSX.Element;
