import React from 'react';

export interface ProgressBarProps {
  /** Fill percentage 0–100 */
  value: number;
  /** Bar fill color (CSS color or var()) */
  color?: string;
  /** Bar height in px */
  height?: number;
  /** Optional label rendered to the left */
  label?: string;
  /** Width of the label column in px */
  labelWidth?: number;
  /** Show percentage value to the right */
  showValue?: boolean;
  style?: React.CSSProperties;
}

export declare function ProgressBar(props: ProgressBarProps): JSX.Element;
