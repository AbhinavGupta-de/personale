import React from 'react';

export interface CircularProgressProps {
  /** Progress 0–100 */
  value: number;
  /** Diameter in px */
  size?: number;
  /** Ring stroke width in px */
  strokeWidth?: number;
  /** Stroke color — CSS color or var() */
  color?: string;
  /** Content to render in the center of the ring */
  children?: React.ReactNode;
  style?: React.CSSProperties;
}

export declare function CircularProgress(props: CircularProgressProps): JSX.Element;
