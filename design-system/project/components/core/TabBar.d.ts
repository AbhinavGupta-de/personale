import React from 'react';

export interface TabBarProps {
  /** Array of tab label strings */
  tabs: string[];
  /** Currently active tab label */
  activeTab: string;
  onTabChange: (tab: string) => void;
  /** sm for compact contexts (date nav toggle), md for page section tabs */
  size?: 'sm' | 'md';
  style?: React.CSSProperties;
}

export declare function TabBar(props: TabBarProps): JSX.Element;
