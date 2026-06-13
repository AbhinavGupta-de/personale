/* @ds-bundle: {"format":3,"namespace":"PersonaleDesignSystem_0c6c40","components":[{"name":"ProgressBar","sourcePath":"components/charts/ProgressBar.jsx"},{"name":"TimelineBar","sourcePath":"components/charts/TimelineBar.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"CATEGORY_COLORS","sourcePath":"components/core/CategoryBadge.jsx"},{"name":"CategoryBadge","sourcePath":"components/core/CategoryBadge.jsx"},{"name":"CircularProgress","sourcePath":"components/core/CircularProgress.jsx"},{"name":"SectionTitle","sourcePath":"components/core/SectionTitle.jsx"},{"name":"StatCard","sourcePath":"components/core/StatCard.jsx"},{"name":"TabBar","sourcePath":"components/core/TabBar.jsx"}],"sourceHashes":{"components/charts/ProgressBar.jsx":"404706232d56","components/charts/TimelineBar.jsx":"c7448f942948","components/core/Badge.jsx":"8881f0630c94","components/core/Button.jsx":"4608a811ea5a","components/core/CategoryBadge.jsx":"743f2d6e6817","components/core/CircularProgress.jsx":"89ae3dc67bae","components/core/SectionTitle.jsx":"77ef2ec954a5","components/core/StatCard.jsx":"14495a69c439","components/core/TabBar.jsx":"7155224af3b0","ui_kits/app/app-shell.jsx":"e89a44402cab","ui_kits/app/dashboard-screen.jsx":"0a11b1c05142","ui_kits/app/insights-screen.jsx":"e8fa4f70111b","ui_kits/app/mock-data.jsx":"64adb62d89ab","ui_kits/app/pomodoro-screen.jsx":"ffeaa4272098","ui_kits/app/ui-components.jsx":"49c73fcf3c9d"},"inlinedExternals":[],"unexposedExports":[{"name":"categoryColor","sourcePath":"components/core/CategoryBadge.jsx"}]} */

(() => {

const __ds_ns = (window.PersonaleDesignSystem_0c6c40 = window.PersonaleDesignSystem_0c6c40 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/charts/ProgressBar.jsx
try { (() => {
/**
 * Horizontal fill-bar for category/app breakdowns.
 * Used in CategoriesListCard, AppsWebsitesCard, DayOfWeekCard in AppShell.swift.
 */
function ProgressBar({
  value = 0,
  color = 'var(--color-chart-purple)',
  height = 6,
  label,
  labelWidth = 80,
  showValue = false,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      width: '100%',
      ...style
    }
  }, label !== undefined && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-sm)',
      fontWeight: 'var(--font-weight-medium)',
      color: 'var(--color-foreground)',
      fontFamily: 'var(--font-sans)',
      width: labelWidth,
      flexShrink: 0,
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height,
      borderRadius: 'var(--progress-bar-radius)',
      background: 'rgba(43,43,49,0.5)',
      position: 'relative',
      overflow: 'hidden',
      minWidth: 40
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      top: 0,
      height: '100%',
      width: `${Math.min(100, Math.max(0, value))}%`,
      background: color,
      borderRadius: 'var(--progress-bar-radius)',
      transition: 'width 0.4s ease-out'
    }
  })), showValue && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-sm)',
      fontFamily: 'var(--font-mono)',
      fontVariantNumeric: 'tabular-nums',
      color: 'var(--color-muted-foreground)',
      minWidth: 32,
      textAlign: 'right'
    }
  }, Math.round(value), "%"));
}
Object.assign(__ds_scope, { ProgressBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/charts/ProgressBar.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
/**
 * Status badge / tag used for categories, session states, and contextual labels.
 */
function Badge({
  children,
  variant = 'default',
  style
}) {
  const variantMap = {
    default: {
      background: 'var(--color-secondary)',
      color: 'var(--color-foreground)'
    },
    primary: {
      background: 'rgba(123,86,210,0.12)',
      color: 'var(--color-primary)'
    },
    accent: {
      background: 'rgba(0,204,184,0.12)',
      color: 'var(--color-accent)'
    },
    success: {
      background: 'rgba(43,171,124,0.15)',
      color: 'var(--color-success)'
    },
    warning: {
      background: 'rgba(245,159,10,0.15)',
      color: 'var(--color-warning)'
    },
    destructive: {
      background: 'rgba(220,40,40,0.15)',
      color: 'var(--color-destructive)'
    },
    outline: {
      background: 'transparent',
      color: 'var(--color-foreground)',
      border: '1px solid var(--color-border)'
    }
  };
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '4px',
      padding: '3px 8px',
      borderRadius: 'var(--radius-pill)',
      fontSize: 'var(--text-sm)',
      fontWeight: 'var(--font-weight-medium)',
      fontFamily: 'var(--font-sans)',
      lineHeight: 1.4,
      ...variantMap[variant],
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
/**
 * Primary action button. Three visual variants matching Personale's interaction patterns.
 */
function Button({
  children,
  variant = 'primary',
  size = 'md',
  icon,
  disabled = false,
  onClick,
  style
}) {
  const [hovered, setHovered] = React.useState(false);
  const [pressed, setPressed] = React.useState(false);
  const base = {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '6px',
    border: 'none',
    borderRadius: size === 'sm' ? '5px' : '6px',
    cursor: disabled ? 'not-allowed' : 'pointer',
    fontFamily: 'var(--font-sans)',
    fontWeight: 'var(--font-weight-medium)',
    lineHeight: 1,
    outline: 'none',
    transition: 'opacity 0.12s ease',
    whiteSpace: 'nowrap',
    userSelect: 'none',
    opacity: disabled ? 0.5 : pressed ? 0.7 : hovered ? 0.85 : 1
  };
  const variantMap = {
    primary: {
      background: 'var(--color-primary)',
      color: 'var(--color-primary-foreground)',
      border: '1px solid transparent'
    },
    secondary: {
      background: 'var(--color-secondary)',
      color: 'var(--color-foreground)',
      border: '1px solid rgba(43,43,49,0.6)'
    },
    ghost: {
      background: 'transparent',
      color: 'var(--color-foreground)',
      border: '1px solid transparent'
    },
    destructive: {
      background: 'rgba(220,40,40,0.15)',
      color: 'var(--color-destructive)',
      border: '1px solid rgba(220,40,40,0.25)'
    }
  };
  const sizeMap = {
    sm: {
      fontSize: '11px',
      padding: '5px 10px',
      height: '26px'
    },
    md: {
      fontSize: '12px',
      padding: '6px 14px',
      height: '30px'
    },
    lg: {
      fontSize: '13px',
      padding: '8px 18px',
      height: '36px'
    }
  };
  return /*#__PURE__*/React.createElement("button", {
    style: {
      ...base,
      ...variantMap[variant],
      ...sizeMap[size],
      ...style
    },
    disabled: disabled,
    onClick: disabled ? undefined : onClick,
    onMouseEnter: () => setHovered(true),
    onMouseLeave: () => {
      setHovered(false);
      setPressed(false);
    },
    onMouseDown: () => setPressed(true),
    onMouseUp: () => setPressed(false)
  }, icon && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center'
    }
  }, icon), children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/CategoryBadge.jsx
try { (() => {
/** Fixed category→color map (matches CategoryColors.map in Theme.swift) */
const CATEGORY_COLORS = {
  Code: '#7c5cfc',
  Browsing: '#f5a623',
  Communication: '#d64d8a',
  Design: '#00ccbf',
  Writing: '#35a882',
  Media: '#9b85f5',
  Utilities: '#6b7280',
  Reading: '#3b82f6',
  Other: '#3d4451'
};
function categoryColor(cat) {
  if (CATEGORY_COLORS[cat]) return CATEGORY_COLORS[cat];
  const c = cat ? cat.charAt(0).toUpperCase() + cat.slice(1) : 'Other';
  return CATEGORY_COLORS[c] || CATEGORY_COLORS.Other;
}

/**
 * Category color dot + optional label — used in list rows, session cards, timeline tooltips.
 */
function CategoryBadge({
  category,
  showDot = true,
  showLabel = true,
  size = 'md',
  style
}) {
  const color = categoryColor(category);
  const dotSize = size === 'sm' ? 5 : size === 'lg' ? 9 : 7;
  const fontSize = size === 'sm' ? 'var(--text-2xs)' : 'var(--text-sm)';
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '5px',
      ...style
    }
  }, showDot && /*#__PURE__*/React.createElement("span", {
    style: {
      width: dotSize,
      height: dotSize,
      borderRadius: '50%',
      background: color,
      flexShrink: 0
    }
  }), showLabel && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize,
      color: 'var(--color-foreground)',
      fontFamily: 'var(--font-sans)'
    }
  }, category));
}
Object.assign(__ds_scope, { CATEGORY_COLORS, categoryColor, CategoryBadge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/CategoryBadge.jsx", error: String((e && e.message) || e) }); }

// components/charts/TimelineBar.jsx
try { (() => {
/**
 * Horizontal daily-timeline strip — colored blocks representing app sessions.
 * Mirrors HorizontalTimelineCard in DashboardCards.swift.
 */
function TimelineBar({
  blocks = [],
  dayStart = 8,
  height = 36,
  style
}) {
  const totalHours = 24;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height,
      background: 'rgba(35,35,41,0.4)',
      borderRadius: '4px',
      overflow: 'hidden',
      ...style
    }
  }, blocks.map((block, i) => {
    const shiftedStart = (block.start - dayStart + 24) % 24;
    const leftPct = shiftedStart / totalHours * 100;
    const widthPct = Math.max(0.4, (block.end - block.start) / totalHours * 100);
    const color = __ds_scope.categoryColor(block.type);
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      title: block.label ? `${block.label} · ${block.type}` : block.type,
      style: {
        position: 'absolute',
        top: 0,
        left: `${leftPct}%`,
        width: `${widthPct}%`,
        height: '100%',
        background: color,
        opacity: 0.85,
        borderRadius: '2px'
      }
    });
  }));
}
Object.assign(__ds_scope, { TimelineBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/charts/TimelineBar.jsx", error: String((e && e.message) || e) }); }

// components/core/CircularProgress.jsx
try { (() => {
/**
 * SVG donut ring progress indicator.
 * Used in Productivity focus score card and Pomodoro timer ring.
 * Mirrors CircularProgress in Theme.swift.
 */
function CircularProgress({
  value = 0,
  size = 52,
  strokeWidth = 4,
  color = 'var(--color-chart-purple)',
  children,
  style
}) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const clampedValue = Math.min(100, Math.max(0, value));
  const dashOffset = circumference * (1 - clampedValue / 100);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: size,
      height: size,
      flexShrink: 0,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      ...style
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    viewBox: `0 0 ${size} ${size}`,
    style: {
      position: 'absolute',
      top: 0,
      left: 0
    }
  }, /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: radius,
    fill: "none",
    stroke: "var(--color-border)",
    strokeWidth: strokeWidth
  }), /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: radius,
    fill: "none",
    stroke: color,
    strokeWidth: strokeWidth,
    strokeLinecap: "round",
    strokeDasharray: circumference,
    strokeDashoffset: dashOffset,
    transform: `rotate(-90 ${size / 2} ${size / 2})`,
    style: {
      transition: 'stroke-dashoffset 0.6s ease-out'
    }
  })), children && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 1
    }
  }, children));
}
Object.assign(__ds_scope, { CircularProgress });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/CircularProgress.jsx", error: String((e && e.message) || e) }); }

// components/core/SectionTitle.jsx
try { (() => {
/**
 * ALL-CAPS section label — used above every card section in the dashboard.
 * Mirrors SectionTitle in Theme.swift.
 */
function SectionTitle({
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: 'var(--text-xs)',
      fontWeight: 'var(--font-weight-semibold)',
      letterSpacing: 'var(--tracking-section)',
      textTransform: 'uppercase',
      color: 'var(--color-muted-foreground)',
      fontFamily: 'var(--font-sans)',
      lineHeight: 1,
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { SectionTitle });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/SectionTitle.jsx", error: String((e && e.message) || e) }); }

// components/core/StatCard.jsx
try { (() => {
/**
 * Headline stat tile — used in Insights page and Productivity headlineRow.
 * Displays a large bold number with an uppercase label and small caption.
 */
function StatCard({
  title,
  value,
  caption,
  color,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--color-card)',
      borderRadius: 'var(--card-radius)',
      border: '1px solid rgba(43,43,49,0.5)',
      padding: '14px 16px',
      display: 'flex',
      flexDirection: 'column',
      gap: '6px',
      flex: 1,
      minWidth: 0,
      ...style
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.SectionTitle, null, title), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-2xl)',
      fontWeight: 'var(--font-weight-bold)',
      fontVariantNumeric: 'tabular-nums',
      color: color || 'var(--color-foreground)',
      lineHeight: 'var(--leading-tight)',
      fontFamily: 'var(--font-mono)',
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, value), caption && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-xs)',
      color: 'var(--color-muted-foreground)',
      fontFamily: 'var(--font-sans)',
      lineHeight: 1.4
    }
  }, caption));
}
Object.assign(__ds_scope, { StatCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/StatCard.jsx", error: String((e && e.message) || e) }); }

// components/core/TabBar.jsx
try { (() => {
/**
 * Horizontal segmented tab switcher. Used in Pomodoro, Productivity, Insights pages.
 * Matches the DateNavigator view toggle and page section tabs in AppShell.swift.
 */
function TabBar({
  tabs,
  activeTab,
  onTabChange,
  size = 'md',
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'inline-flex',
      gap: '2px',
      padding: '3px',
      background: 'rgba(35,35,41,0.8)',
      borderRadius: '7px',
      ...style
    }
  }, tabs.map(tab => /*#__PURE__*/React.createElement("button", {
    key: tab,
    onClick: () => onTabChange(tab),
    style: {
      fontSize: size === 'sm' ? 'var(--text-xs)' : 'var(--text-sm)',
      fontWeight: 'var(--font-weight-medium)',
      fontFamily: 'var(--font-sans)',
      color: activeTab === tab ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
      background: activeTab === tab ? 'var(--color-card)' : 'transparent',
      border: 'none',
      borderRadius: '5px',
      padding: size === 'sm' ? '3px 8px' : '4px 10px',
      cursor: 'pointer',
      transition: 'color 0.12s, background 0.12s',
      outline: 'none',
      whiteSpace: 'nowrap'
    }
  }, tab)));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/TabBar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/app-shell.jsx
try { (() => {
// app-shell.jsx — Personale App Shell
// Main entry: mounts <App /> to #root

const {
  useState,
  useEffect,
  useRef
} = React;

// ── Icons ────────────────────────────────────────────────────
const I = {
  house: /*#__PURE__*/React.createElement("svg", {
    width: "15",
    height: "15",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }, /*#__PURE__*/React.createElement("path", {
    d: "m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"
  }), /*#__PURE__*/React.createElement("polyline", {
    points: "9 22 9 12 15 12 15 22"
  })),
  activity: /*#__PURE__*/React.createElement("svg", {
    width: "15",
    height: "15",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }, /*#__PURE__*/React.createElement("polyline", {
    points: "22 12 18 12 15 21 9 3 6 12 2 12"
  })),
  review: /*#__PURE__*/React.createElement("svg", {
    width: "15",
    height: "15",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2z"
  }), /*#__PURE__*/React.createElement("path", {
    d: "m9 12 2 2 4-4"
  })),
  pomodoro: /*#__PURE__*/React.createElement("svg", {
    width: "15",
    height: "15",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "10"
  }), /*#__PURE__*/React.createElement("polyline", {
    points: "12 6 12 12 16 14"
  })),
  prod: /*#__PURE__*/React.createElement("svg", {
    width: "15",
    height: "15",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }, /*#__PURE__*/React.createElement("line", {
    x1: "18",
    y1: "20",
    x2: "18",
    y2: "10"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "12",
    y1: "20",
    x2: "12",
    y2: "4"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "6",
    y1: "20",
    x2: "6",
    y2: "14"
  })),
  insights: /*#__PURE__*/React.createElement("svg", {
    width: "15",
    height: "15",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }, /*#__PURE__*/React.createElement("path", {
    d: "m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3Z"
  })),
  settings: /*#__PURE__*/React.createElement("svg", {
    width: "15",
    height: "15",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "3"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"
  }))
};
const NAV = [{
  id: 'dashboard',
  icon: I.house,
  label: 'Dashboard'
}, {
  id: 'activity',
  icon: I.activity,
  label: 'Activity'
}, {
  id: 'review',
  icon: I.review,
  label: 'Review'
}, {
  id: 'pomodoro',
  icon: I.pomodoro,
  label: 'Timer'
}, {
  id: 'productivity',
  icon: I.prod,
  label: 'Productivity'
}, {
  id: 'insights',
  icon: I.insights,
  label: 'Insights'
}];

// ── Productivity Screen (inline) ─────────────────────────────
function ProductivityScreen() {
  const {
    catColor,
    Card,
    SectionLabel,
    BarFill,
    CircularRing
  } = window.UI;
  const [tab, setTab] = React.useState('Focus');
  const cats = window.MOCK.categories;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 20,
      height: '100%',
      overflowY: 'auto',
      display: 'flex',
      flexDirection: 'column',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 22,
      fontWeight: 700,
      color: 'var(--color-foreground)'
    }
  }, "Productivity"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 2,
      padding: 3,
      background: 'rgba(35,35,41,0.8)',
      borderRadius: 7
    }
  }, ['Focus', 'Breaks', 'Meetings', 'Goals'].map(t => /*#__PURE__*/React.createElement("button", {
    key: t,
    onClick: () => setTab(t),
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: tab === t ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
      background: tab === t ? 'var(--color-card)' : 'transparent',
      border: 'none',
      borderRadius: 5,
      padding: '4px 10px',
      cursor: 'pointer'
    }
  }, t)))), tab === 'Focus' && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement(Card, {
    style: {
      width: 220,
      padding: '14px 16px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      width: '100%'
    }
  }, "Avg Focus Score"), /*#__PURE__*/React.createElement(CircularRing, {
    value: 0.78,
    size: 120,
    strokeWidth: 10,
    color: "var(--color-chart-purple)"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 28,
      fontWeight: 700,
      fontFamily: 'monospace',
      color: 'var(--color-foreground)'
    }
  }, "78"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 9,
      color: 'var(--color-muted-foreground)'
    }
  }, "score")))), /*#__PURE__*/React.createElement(Card, {
    style: {
      flex: 1,
      padding: '14px 16px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Work Categories"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 7
    }
  }, cats.map(c => /*#__PURE__*/React.createElement("div", {
    key: c.category,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      width: 28,
      textAlign: 'right'
    }
  }, c.percent, "%"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-foreground)',
      width: 110
    }
  }, c.category), /*#__PURE__*/React.createElement(BarFill, {
    value: c.percent,
    color: c.color,
    height: 6,
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      width: 50,
      textAlign: 'right'
    }
  }, window.UI.formatDuration(c.totalSeconds)))))), /*#__PURE__*/React.createElement(Card, {
    style: {
      width: 260,
      padding: '14px 16px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Top Interruptors"), [['Slack', 14], ['Twitter/X', 8], ['Email', 6], ['YouTube', 4], ['Linear', 3]].map(([n, c]) => /*#__PURE__*/React.createElement("div", {
    key: n,
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      marginBottom: 7
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-foreground)'
    }
  }, n), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)'
    }
  }, c, "\xD7")))))), (tab === 'Meetings' || tab === 'Goals') && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      flex: 1,
      gap: 8,
      minHeight: 300
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 22,
      color: 'var(--color-muted-foreground)',
      opacity: 0.4
    }
  }, "\u2726"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      fontWeight: 500,
      color: 'var(--color-muted-foreground)'
    }
  }, tab, " \u2014 coming soon")), tab === 'Breaks' && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14
    }
  }, [['Breaks Taken', '4'], ['Avg Length', '12m'], ['Away Sessions', '2']].map(([t, v]) => /*#__PURE__*/React.createElement(Card, {
    key: t,
    style: {
      flex: 1,
      padding: '14px 16px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 6
    }
  }, t), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 22,
      fontWeight: 700,
      fontFamily: 'monospace',
      color: 'var(--color-foreground)'
    }
  }, v)))));
}

// ── Activity Screen (inline) ──────────────────────────────────
function ActivityScreen() {
  const {
    catColor,
    Card,
    SectionLabel,
    TimelineStrip
  } = window.UI;
  const m = window.MOCK;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 20,
      height: '100%',
      overflowY: 'auto',
      display: 'flex',
      flexDirection: 'column',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      fontWeight: 600,
      color: 'var(--color-foreground)'
    }
  }, "Thursday, June 12, 2025"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 2,
      padding: 3,
      background: 'rgba(35,35,41,0.8)',
      borderRadius: 7
    }
  }, ['Day', 'Week'].map(v => /*#__PURE__*/React.createElement("button", {
    key: v,
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: v === 'Day' ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
      background: v === 'Day' ? 'var(--color-card)' : 'transparent',
      border: 'none',
      borderRadius: 5,
      padding: '4px 10px',
      cursor: 'pointer'
    }
  }, v)))), /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '14px 16px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Timeline"), /*#__PURE__*/React.createElement(TimelineStrip, {
    blocks: m.timeline,
    dayStart: 8
  })), /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '14px 16px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Activity Log"), [['18:01', 'Notion', 'workspace/docs'], ['17:49', 'VS Code', 'personale/Theme.swift'], ['17:35', 'Chrome', 'github.com/pulls'], ['17:12', 'Slack', '#engineering'], ['16:55', 'VS Code', 'personale/Dashboard.swift'], ['16:30', 'Figma', 'Design System — Components'], ['16:10', 'Arc', 'linear.app/issues'], ['15:45', 'Cursor', 'components/Button.jsx'], ['15:20', 'Slack', '#design'], ['14:58', 'VS Code', 'app-shell.jsx']].map(([t, app, detail]) => /*#__PURE__*/React.createElement("div", {
    key: t + app,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      marginBottom: 7
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 10,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      width: 40
    }
  }, t), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: 'var(--color-foreground)',
      width: 80
    }
  }, app), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 10,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      flex: 1,
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, detail)))));
}

// ── Settings Screen (inline) ──────────────────────────────────
function SettingsScreen() {
  const {
    Card,
    SectionLabel,
    Divider
  } = window.UI;
  const [serverUrl, setServerUrl] = React.useState('http://localhost:8696');
  const [dayStart, setDayStart] = React.useState('8');
  const [dayEnd, setDayEnd] = React.useState('18');
  const [dailyTarget, setDailyTarget] = React.useState('8');
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 20,
      height: '100%',
      overflowY: 'auto',
      display: 'flex',
      flexDirection: 'column',
      gap: 14,
      maxWidth: 640
    }
  }, /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '16px 20px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 14
    }
  }, "Server"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("label", {
    style: {
      fontSize: 11,
      color: 'var(--color-muted-foreground)'
    }
  }, "Server URL"), /*#__PURE__*/React.createElement("input", {
    value: serverUrl,
    onChange: e => setServerUrl(e.target.value),
    style: {
      background: 'var(--color-secondary)',
      border: '1px solid var(--color-border)',
      borderRadius: 6,
      padding: '7px 10px',
      fontSize: 12,
      color: 'var(--color-foreground)',
      fontFamily: 'monospace',
      outline: 'none',
      width: '100%'
    }
  }))), /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '16px 20px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 14
    }
  }, "Work Day"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 20
    }
  }, [['Start hour', dayStart, setDayStart], ['End hour', dayEnd, setDayEnd], ['Daily target (h)', dailyTarget, setDailyTarget]].map(([lbl, val, set]) => /*#__PURE__*/React.createElement("div", {
    key: lbl,
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("label", {
    style: {
      fontSize: 11,
      color: 'var(--color-muted-foreground)',
      display: 'block',
      marginBottom: 6
    }
  }, lbl), /*#__PURE__*/React.createElement("input", {
    type: "number",
    value: val,
    onChange: e => set(e.target.value),
    style: {
      background: 'var(--color-secondary)',
      border: '1px solid var(--color-border)',
      borderRadius: 6,
      padding: '7px 10px',
      fontSize: 12,
      color: 'var(--color-foreground)',
      outline: 'none',
      width: '100%'
    }
  }))))), /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '16px 20px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 14
    }
  }, "Idle Thresholds"), [['Code', '180s'], ['Media', '60s'], ['Communication', '30s'], ['Other', '120s']].map(([cat, val]) => /*#__PURE__*/React.createElement("div", {
    key: cat,
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-foreground)'
    }
  }, cat), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)'
    }
  }, val)))));
}

// ── BottomBar ─────────────────────────────────────────────────
function BottomBar({
  onPageChange
}) {
  const {
    formatTime
  } = window.UI;
  const [focusOn, setFocusOn] = React.useState(true);
  const [secs, setSecs] = React.useState(1174);
  React.useEffect(() => {
    const t = setInterval(() => {
      if (focusOn) setSecs(s => Math.max(0, s - 1));
    }, 1000);
    return () => clearInterval(t);
  }, [focusOn]);
  const progress = secs / 1800;
  const r = 9,
    circ = 2 * Math.PI * r;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 50,
      background: 'var(--color-card)',
      borderTop: '1px solid rgba(43,43,49,0.4)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 16px',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: bareBtn,
    title: "Tracking active"
  }, /*#__PURE__*/React.createElement("svg", {
    width: "12",
    height: "12",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "#2bab7c",
    strokeWidth: "2",
    strokeLinecap: "round"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "10"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M12 8v4l3 3"
  }))), /*#__PURE__*/React.createElement("button", {
    style: bareBtn,
    title: "Continue"
  }, /*#__PURE__*/React.createElement("svg", {
    width: "10",
    height: "10",
    viewBox: "0 0 24 24",
    fill: "#2bab7c",
    stroke: "none"
  }, /*#__PURE__*/React.createElement("polygon", {
    points: "5 3 19 12 5 21 5 3"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: "22",
    height: "22",
    viewBox: "0 0 22 22"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "11",
    r: r,
    fill: "none",
    stroke: "rgba(43,43,49,0.6)",
    strokeWidth: "2"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "11",
    r: r,
    fill: "none",
    stroke: "#00ccb8",
    strokeWidth: "2",
    strokeLinecap: "round",
    strokeDasharray: circ,
    strokeDashoffset: circ * (1 - progress),
    transform: "rotate(-90 11 11)"
  })), /*#__PURE__*/React.createElement("button", {
    onClick: () => onPageChange('pomodoro'),
    style: {
      ...bareBtn,
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      fontWeight: 700,
      fontFamily: 'monospace',
      color: '#00ccb8',
      letterSpacing: '-0.5px'
    }
  }, formatTime(secs))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 7,
      fontWeight: 600,
      letterSpacing: '0.5px',
      color: 'var(--color-muted-foreground)',
      textTransform: 'uppercase'
    }
  }, "Focus time"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 7,
      fontWeight: 600,
      letterSpacing: '0.5px',
      color: 'var(--color-muted-foreground)',
      textTransform: 'uppercase'
    }
  }, "Remaining"))), /*#__PURE__*/React.createElement("button", {
    onClick: () => setFocusOn(f => !f),
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: 'var(--color-foreground)',
      background: 'var(--color-secondary)',
      border: '1px solid rgba(43,43,49,0.6)',
      borderRadius: 6,
      padding: '5px 12px',
      cursor: 'pointer',
      fontFamily: 'inherit'
    }
  }, focusOn ? 'End Focus' : 'Start Focus', " \u02C5")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-muted-foreground)'
    }
  }, "Silence"), /*#__PURE__*/React.createElement("button", {
    style: bareBtn
  }, /*#__PURE__*/React.createElement("svg", {
    width: "13",
    height: "13",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "var(--color-muted-foreground)",
    strokeWidth: "1.75",
    strokeLinecap: "round"
  }, /*#__PURE__*/React.createElement("polygon", {
    points: "11 5 6 9 2 9 2 15 6 15 11 19 11 5"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M15.54 8.46a5 5 0 0 1 0 7.07"
  }))), /*#__PURE__*/React.createElement("button", {
    style: bareBtn
  }, /*#__PURE__*/React.createElement("svg", {
    width: "13",
    height: "13",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "var(--color-muted-foreground)",
    strokeWidth: "1.75",
    strokeLinecap: "round"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"
  })))));
}
const bareBtn = {
  background: 'transparent',
  border: 'none',
  cursor: 'default',
  padding: 4,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  color: 'var(--color-muted-foreground)'
};

// ── App ───────────────────────────────────────────────────────
function App() {
  const [page, setPage] = React.useState('dashboard');
  const pages = {
    dashboard: window.DashboardScreen,
    activity: ActivityScreen,
    review: () => /*#__PURE__*/React.createElement("div", {
      style: {
        padding: 20,
        color: 'var(--color-muted-foreground)',
        fontSize: 13
      }
    }, "Review \u2014 coming soon"),
    pomodoro: window.PomodoroScreen,
    productivity: ProductivityScreen,
    insights: window.InsightsScreen,
    settings: SettingsScreen
  };
  const CurrentPage = pages[page] || pages.dashboard;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: '100%',
      height: '100vh',
      display: 'flex',
      background: 'var(--color-background)',
      minWidth: 1100
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 52,
      background: 'var(--color-card)',
      borderRight: '1px solid rgba(43,43,49,0.6)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      paddingTop: 12,
      paddingBottom: 12,
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 2,
      flex: 1
    }
  }, NAV.map(item => {
    const active = page === item.id;
    return /*#__PURE__*/React.createElement("button", {
      key: item.id,
      title: item.label,
      onClick: () => setPage(item.id),
      style: {
        width: 36,
        height: 36,
        borderRadius: 8,
        border: 'none',
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: active ? 'rgba(123,86,210,0.12)' : 'transparent',
        color: active ? 'var(--color-primary)' : 'var(--color-muted-foreground)',
        transition: 'all 0.12s'
      }
    }, item.icon);
  })), /*#__PURE__*/React.createElement("button", {
    title: "Settings",
    onClick: () => setPage('settings'),
    style: {
      width: 36,
      height: 36,
      borderRadius: 8,
      border: 'none',
      cursor: 'pointer',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: page === 'settings' ? 'rgba(123,86,210,0.12)' : 'transparent',
      color: page === 'settings' ? 'var(--color-primary)' : 'var(--color-muted-foreground)'
    }
  }, I.settings)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 42,
      borderBottom: '1px solid rgba(43,43,49,0.4)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 20px',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 2
    }
  }, ['‹', '›'].map(ch => /*#__PURE__*/React.createElement("button", {
    key: ch,
    style: {
      ...bareBtn,
      width: 28,
      height: 28,
      cursor: 'pointer',
      fontSize: 14,
      color: 'var(--color-muted-foreground)'
    }
  }, ch))), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      fontWeight: 600,
      letterSpacing: '3px',
      color: 'rgba(224,224,224,0.8)'
    }
  }, "PERSONALE"), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 24,
      height: 24,
      borderRadius: '50%',
      background: 'var(--color-primary)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: 9,
      fontWeight: 700,
      color: 'var(--color-primary-foreground)'
    }
  }, "A")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement(CurrentPage, null)), /*#__PURE__*/React.createElement(BottomBar, {
    onPageChange: setPage
  })));
}
ReactDOM.createRoot(document.getElementById('root')).render(/*#__PURE__*/React.createElement(App, null));
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/app-shell.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/dashboard-screen.jsx
try { (() => {
// dashboard-screen.jsx — Personale Dashboard
// Exports: window.DashboardScreen

function DashboardScreen() {
  const {
    formatDuration,
    catColor,
    Card,
    SectionLabel,
    DonutChart,
    BarFill,
    TimelineStrip
  } = window.UI;
  const m = window.MOCK;
  const [dateOffset, setDateOffset] = React.useState(0);
  const HOURS = [8, 10, 12, 14, 16, 18];
  const total = m.totalSeconds;
  const pct = s => total > 0 ? Math.round(s / total * 100) : 0;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      overflowY: 'auto',
      padding: 20,
      display: 'flex',
      flexDirection: 'column',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      fontWeight: 600,
      color: 'var(--color-foreground)'
    }
  }, dateOffset === 0 ? m.date : dateOffset === -1 ? 'Wednesday, June 11, 2025' : 'Tuesday, June 10, 2025'), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 4,
      padding: '3px 8px',
      borderRadius: 999,
      background: 'rgba(0,204,184,0.12)',
      fontSize: 11,
      fontWeight: 500,
      color: 'var(--color-accent)'
    }
  }, "\u2726 ", m.freshStart), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 4,
      padding: '3px 8px',
      borderRadius: 999,
      background: 'rgba(0,204,184,0.12)',
      fontSize: 11,
      fontWeight: 500,
      color: 'var(--color-accent)'
    }
  }, "\u2B25 ", m.streak, "d streak")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      padding: 3,
      background: 'rgba(35,35,41,0.8)',
      borderRadius: 7
    }
  }, ['Day', 'Week'].map(v => /*#__PURE__*/React.createElement("button", {
    key: v,
    onClick: () => {},
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: v === 'Day' ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
      background: v === 'Day' ? 'var(--color-card)' : 'transparent',
      border: 'none',
      borderRadius: 5,
      padding: '4px 10px',
      cursor: 'pointer'
    }
  }, v))), /*#__PURE__*/React.createElement("button", {
    onClick: () => setDateOffset(o => o - 1),
    style: navBtnStyle
  }, "\u2039"), dateOffset < 0 && /*#__PURE__*/React.createElement("button", {
    onClick: () => setDateOffset(0),
    style: {
      ...navBtnStyle,
      fontSize: 11,
      padding: '4px 10px',
      color: 'var(--color-primary)',
      background: 'rgba(123,86,210,0.12)',
      borderRadius: 6
    }
  }, "Today"), /*#__PURE__*/React.createElement("button", {
    onClick: () => setDateOffset(o => Math.min(0, o + 1)),
    style: {
      ...navBtnStyle,
      opacity: dateOffset >= 0 ? 0.3 : 1
    }
  }, "\u203A"))), /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '14px 16px 14px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Timeline"), /*#__PURE__*/React.createElement(TimelineStrip, {
    blocks: m.timeline,
    dayStart: 8
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      marginTop: 6
    }
  }, HOURS.map(h => /*#__PURE__*/React.createElement("span", {
    key: h,
    style: {
      fontSize: 9,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)'
    }
  }, h < 12 ? `${h}AM` : h === 12 ? '12PM' : `${h - 12}PM`)))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14,
      alignItems: 'flex-start'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    style: {
      width: 300,
      padding: '14px 16px 16px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      width: '100%'
    }
  }, "Breakdown"), /*#__PURE__*/React.createElement(DonutChart, {
    segments: m.categories,
    size: 140,
    center: /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: 'center'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 13,
        fontWeight: 700,
        fontFamily: 'monospace',
        color: 'var(--color-foreground)'
      }
    }, formatDuration(total)), /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 9,
        color: 'var(--color-muted-foreground)'
      }
    }, "tracked"))
  })), /*#__PURE__*/React.createElement(Card, {
    style: {
      flex: 1,
      padding: '14px 16px 14px',
      minHeight: 260
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Categories"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 7
    }
  }, m.categories.map(cat => /*#__PURE__*/React.createElement("div", {
    key: cat.category,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      width: 28,
      textAlign: 'right'
    }
  }, cat.percent, "%"), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 40,
      height: 6,
      borderRadius: 2,
      background: cat.color,
      opacity: 0.75
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-foreground)',
      flex: 1
    }
  }, cat.category), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)'
    }
  }, formatDuration(cat.totalSeconds)))))), /*#__PURE__*/React.createElement(Card, {
    style: {
      width: 320,
      padding: '14px 16px 14px',
      minHeight: 260
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Apps"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 7
    }
  }, m.apps.map(app => /*#__PURE__*/React.createElement("div", {
    key: app.appName,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      width: 28,
      textAlign: 'right'
    }
  }, app.percent, "%"), /*#__PURE__*/React.createElement(BarFill, {
    value: app.percent,
    color: "rgba(124,92,252,0.65)",
    height: 6,
    style: {
      width: 40,
      flex: 'none'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-foreground)',
      flex: 1
    }
  }, app.appName), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)'
    }
  }, formatDuration(app.totalSeconds))))))), /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '14px 16px 14px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Goals"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 20
    }
  }, m.goals.map(g => {
    const progress = Math.min(1, g.currentHours / g.targetHours);
    return /*#__PURE__*/React.createElement("div", {
      key: g.category,
      style: {
        flex: 1
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        justifyContent: 'space-between',
        marginBottom: 6
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 5
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        width: 7,
        height: 7,
        borderRadius: '50%',
        background: g.color,
        display: 'inline-block'
      }
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 11,
        color: 'var(--color-foreground)'
      }
    }, g.category)), /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 11,
        fontFamily: 'monospace',
        color: 'var(--color-muted-foreground)'
      }
    }, g.currentHours.toFixed(1), "h / ", g.targetHours, "h")), /*#__PURE__*/React.createElement(BarFill, {
      value: progress * 100,
      color: g.color,
      height: 6
    }));
  }))), /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '14px 0 14px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10,
      paddingLeft: 16
    }
  }, "Today's Sessions"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      overflowX: 'auto',
      paddingLeft: 16,
      paddingRight: 16,
      paddingBottom: 2
    }
  }, m.sessions.map(s => /*#__PURE__*/React.createElement("div", {
    key: s.id,
    style: {
      minWidth: 200,
      padding: 10,
      flexShrink: 0,
      background: 'rgba(35,35,41,0.4)',
      borderRadius: 8,
      border: '1px solid rgba(43,43,49,0.3)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      marginBottom: 4
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8,
      height: 8,
      borderRadius: '50%',
      background: catColor(s.name),
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontWeight: 600,
      color: 'var(--color-foreground)'
    }
  }, s.name)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      marginBottom: 4
    }
  }, s.startTime, " \u2013 ", s.endTime), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      fontWeight: 700,
      fontFamily: 'monospace',
      color: 'var(--color-foreground)',
      marginBottom: 6
    }
  }, formatDuration(s.durationSeconds)), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 1,
      background: 'rgba(43,43,49,0.4)',
      marginBottom: 6
    }
  }), s.apps.slice(0, 3).map(a => /*#__PURE__*/React.createElement("div", {
    key: a.appName,
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      marginBottom: 3
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 10,
      color: 'var(--color-muted-foreground)'
    }
  }, a.appName), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 10,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)'
    }
  }, a.percent, "%"))))))), /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '14px 16px 14px',
      marginBottom: 4
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Websites"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 7
    }
  }, m.websites.map(w => /*#__PURE__*/React.createElement("div", {
    key: w.domain,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      width: 28,
      textAlign: 'right'
    }
  }, pct(w.seconds), "%"), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 7,
      height: 7,
      borderRadius: '50%',
      background: catColor(w.category),
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-foreground)',
      flex: 1
    }
  }, w.domain), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)'
    }
  }, formatDuration(w.seconds)))))));
}
const navBtnStyle = {
  fontSize: 12,
  color: 'var(--color-muted-foreground)',
  background: 'transparent',
  border: 'none',
  cursor: 'pointer',
  width: 28,
  height: 28,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center'
};
window.DashboardScreen = DashboardScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/dashboard-screen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/insights-screen.jsx
try { (() => {
// insights-screen.jsx — Personale Insights
// Exports: window.InsightsScreen

function InsightsScreen() {
  const {
    Card,
    SectionLabel,
    BarFill
  } = window.UI;
  const ins = window.MOCK.insights;
  const [range, setRange] = React.useState('30d');
  const [narrative, setNarrative] = React.useState(null);
  const [generating, setGenerating] = React.useState(false);
  const maxDow = Math.max(...ins.dayOfWeek.map(d => d.avgHours));
  const maxTrend = Math.max(...ins.trend.map(d => d.hours));
  const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const handleGenerate = () => {
    setGenerating(true);
    setTimeout(() => {
      setNarrative({
        summary: "Strong 30-day period with consistent deep-work blocks. Code dominated at 63% — well above your 50% baseline. Wednesday shows peak focus, likely linked to your no-meeting policy.",
        patterns: ["10–12 AM is your peak window: 40% more productive than afternoons.", "Context switches spike on Thursdays — likely sprint review overhead."],
        wins: ["7-day current streak — longest in 2 months.", "Design time up 3% vs prior period."],
        watchouts: ["Browsing crept up on Friday afternoons — consider a distraction block after 3 PM."]
      });
      setGenerating(false);
    }, 2000);
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      overflowY: 'auto',
      padding: 20,
      display: 'flex',
      flexDirection: 'column',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 22,
      fontWeight: 700,
      color: 'var(--color-foreground)'
    }
  }, "Insights"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 2,
      padding: 3,
      background: 'rgba(35,35,41,0.8)',
      borderRadius: 7
    }
  }, ['7d', '30d', '90d'].map(r => /*#__PURE__*/React.createElement("button", {
    key: r,
    onClick: () => setRange(r),
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: range === r ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
      background: range === r ? 'var(--color-card)' : 'transparent',
      border: 'none',
      borderRadius: 5,
      padding: '4px 10px',
      cursor: 'pointer'
    }
  }, r)))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14
    }
  }, [{
    title: 'Productive',
    value: ins.totalProductive,
    caption: `of ${ins.totalTracked} tracked`
  }, {
    title: 'Avg / Day',
    value: ins.avgPerDay,
    caption: `${ins.daysWithData} days with data`
  }, {
    title: 'Switches / Day',
    value: ins.avgSwitches,
    caption: `${ins.totalSwitches} total`
  }, {
    title: 'Best Day',
    value: ins.bestDay.label,
    caption: `${ins.bestDay.hours} avg`
  }, {
    title: 'Peak Hour',
    value: ins.peakHour.label,
    caption: ins.peakHour.hours
  }].map(s => /*#__PURE__*/React.createElement(Card, {
    key: s.title,
    style: {
      flex: 1,
      padding: '14px 14px 12px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 6
    }
  }, s.title), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 20,
      fontWeight: 700,
      fontFamily: 'monospace',
      color: 'var(--color-foreground)',
      marginBottom: 4,
      lineHeight: 1.1
    }
  }, s.value), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      color: 'var(--color-muted-foreground)'
    }
  }, s.caption)))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14,
      alignItems: 'flex-start'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    style: {
      flex: 1,
      padding: '14px 16px 14px',
      overflowX: 'auto'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Productive Hours \xB7 Weekday \xD7 Hour"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 2
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      marginLeft: 26,
      marginBottom: 2,
      gap: 2
    }
  }, Array.from({
    length: 24
  }, (_, h) => /*#__PURE__*/React.createElement("div", {
    key: h,
    style: {
      flex: 1,
      fontSize: 7,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      textAlign: 'center'
    }
  }, h % 6 === 0 ? h : ''))), WEEKDAYS.map((day, row) => /*#__PURE__*/React.createElement("div", {
    key: day,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 24,
      fontSize: 9,
      fontWeight: 500,
      color: 'var(--color-muted-foreground)',
      flexShrink: 0
    }
  }, day), ins.heatmap[row].map((intensity, col) => /*#__PURE__*/React.createElement("div", {
    key: col,
    style: {
      flex: 1,
      height: 14,
      borderRadius: 2,
      background: intensity > 0.01 ? `rgba(124,92,252,${Math.min(0.9, 0.12 + intensity * 0.88)})` : 'rgba(43,43,49,0.3)'
    }
  })))))), /*#__PURE__*/React.createElement(Card, {
    style: {
      width: 280,
      padding: '14px 16px 14px',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Average by Weekday"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 7
    }
  }, ins.dayOfWeek.map(d => /*#__PURE__*/React.createElement("div", {
    key: d.label,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: 'var(--color-foreground)',
      width: 28
    }
  }, d.label), /*#__PURE__*/React.createElement(BarFill, {
    value: d.avgHours / maxDow * 100,
    color: "var(--color-chart-purple)",
    height: 7,
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 10,
      fontFamily: 'monospace',
      color: 'var(--color-muted-foreground)',
      width: 44,
      textAlign: 'right'
    }
  }, d.avgHours.toFixed(1), "h")))))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement(Card, {
    style: {
      flex: 1,
      padding: '14px 16px 14px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 10
    }
  }, "Daily Trend"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-end',
      gap: 2,
      height: 100
    }
  }, ins.trend.map((d, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    title: `${d.hours.toFixed(1)}h`,
    style: {
      flex: 1,
      height: `${Math.max(4, d.hours / maxTrend * 96)}px`,
      background: 'var(--color-chart-purple)',
      borderRadius: '1px 1px 0 0',
      opacity: 0.75 + i / ins.trend.length * 0.25
    }
  })))), /*#__PURE__*/React.createElement(Card, {
    style: {
      width: 220,
      padding: '14px 16px 14px'
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      marginBottom: 12
    }
  }, "Productive Streak"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, [['current', ins.streaks.current], ['longest', ins.streaks.longest]].map(([label, val]) => /*#__PURE__*/React.createElement("div", {
    key: label,
    style: {
      display: 'flex',
      alignItems: 'baseline',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 26,
      fontWeight: 700,
      fontFamily: 'monospace',
      color: 'var(--color-foreground)'
    }
  }, val), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-muted-foreground)'
    }
  }, "days ", label))), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 9,
      color: 'var(--color-muted-foreground)',
      lineHeight: 1.4
    }
  }, "Day counts when you log ", ins.streaks.thresholdHours, "+ productive hrs.")))), /*#__PURE__*/React.createElement(Card, {
    style: {
      padding: '14px 16px 14px',
      marginBottom: 4
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, null, "AI Narrative"), /*#__PURE__*/React.createElement("button", {
    onClick: handleGenerate,
    disabled: generating,
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 5,
      fontSize: 11,
      fontWeight: 500,
      color: 'var(--color-primary-foreground)',
      background: generating ? 'rgba(123,86,210,0.6)' : 'var(--color-primary)',
      border: 'none',
      borderRadius: 6,
      padding: '5px 10px',
      cursor: generating ? 'default' : 'pointer'
    }
  }, generating ? '…' : '✦', " ", narrative ? 'Regenerate' : 'Generate')), narrative ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground)',
      lineHeight: 1.6,
      margin: 0
    }
  }, narrative.summary), [['PATTERNS', narrative.patterns, 'var(--color-chart-purple)'], ['WINS', narrative.wins, 'var(--color-success)'], ['WATCHOUTS', narrative.watchouts, 'var(--color-warning)']].map(([title, items, color]) => items.length > 0 && /*#__PURE__*/React.createElement("div", {
    key: title
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 9,
      fontWeight: 600,
      letterSpacing: '0.8px',
      color,
      marginBottom: 6
    }
  }, title), items.map((item, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: 'flex',
      gap: 6,
      marginBottom: 4
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 4,
      height: 4,
      borderRadius: '50%',
      background: color,
      marginTop: 6,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground)',
      lineHeight: 1.6
    }
  }, item)))))) : /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 11,
      color: 'var(--color-muted-foreground)',
      margin: 0
    }
  }, "Hit Generate for an AI-written recap of this period \u2014 patterns, wins, and watchouts grounded in your data.")));
}
window.InsightsScreen = InsightsScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/insights-screen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/mock-data.jsx
try { (() => {
// mock-data.jsx — Personale UI Kit mock data
// Exports: window.MOCK

const MOCK = {
  date: "Thursday, June 12, 2025",
  streak: 7,
  freshStart: "Fresh start at 8:00 AM",
  totalSeconds: 23520,
  // 6h 32m

  timeline: [{
    start: 8,
    end: 9.5,
    type: "Code",
    label: "VS Code"
  }, {
    start: 9.5,
    end: 10,
    type: "Communication",
    label: "Slack"
  }, {
    start: 10,
    end: 12,
    type: "Code",
    label: "Cursor"
  }, {
    start: 12,
    end: 12.5,
    type: "Browsing",
    label: "Chrome"
  }, {
    start: 13,
    end: 15,
    type: "Code",
    label: "VS Code"
  }, {
    start: 15,
    end: 15.5,
    type: "Design",
    label: "Figma"
  }, {
    start: 15.5,
    end: 16,
    type: "Communication",
    label: "Slack"
  }, {
    start: 16,
    end: 17,
    type: "Writing",
    label: "Notion"
  }],
  categories: [{
    category: "Code",
    percent: 63,
    totalSeconds: 14803,
    color: "#7c5cfc"
  }, {
    category: "Communication",
    percent: 12,
    totalSeconds: 2822,
    color: "#d64d8a"
  }, {
    category: "Design",
    percent: 8,
    totalSeconds: 1882,
    color: "#00ccbf"
  }, {
    category: "Writing",
    percent: 7,
    totalSeconds: 1646,
    color: "#35a882"
  }, {
    category: "Browsing",
    percent: 7,
    totalSeconds: 1646,
    color: "#f5a623"
  }, {
    category: "Other",
    percent: 3,
    totalSeconds: 706,
    color: "#3d4451"
  }],
  apps: [{
    appName: "VS Code",
    totalSeconds: 10800,
    percent: 50
  }, {
    appName: "Cursor",
    totalSeconds: 3042,
    percent: 13
  }, {
    appName: "Slack",
    totalSeconds: 2822,
    percent: 12
  }, {
    appName: "Figma",
    totalSeconds: 1882,
    percent: 8
  }, {
    appName: "Notion",
    totalSeconds: 1646,
    percent: 7
  }, {
    appName: "Chrome",
    totalSeconds: 1176,
    percent: 5
  }, {
    appName: "Terminal",
    totalSeconds: 706,
    percent: 3
  }, {
    appName: "Arc",
    totalSeconds: 470,
    percent: 2
  }],
  sessions: [{
    id: 1,
    name: "Code",
    startTime: "08:00",
    endTime: "09:30",
    durationSeconds: 5400,
    apps: [{
      appName: "VS Code",
      percent: 78
    }, {
      appName: "Terminal",
      percent: 12
    }, {
      appName: "Chrome",
      percent: 10
    }]
  }, {
    id: 2,
    name: "Code",
    startTime: "10:00",
    endTime: "12:00",
    durationSeconds: 7200,
    apps: [{
      appName: "VS Code",
      percent: 82
    }, {
      appName: "Cursor",
      percent: 18
    }]
  }, {
    id: 3,
    name: "Design",
    startTime: "15:00",
    endTime: "15:30",
    durationSeconds: 1800,
    apps: [{
      appName: "Figma",
      percent: 100
    }]
  }, {
    id: 4,
    name: "Writing",
    startTime: "16:00",
    endTime: "17:00",
    durationSeconds: 3600,
    apps: [{
      appName: "Notion",
      percent: 100
    }]
  }],
  websites: [{
    domain: "github.com",
    category: "Code",
    seconds: 3600
  }, {
    domain: "docs.swift.org",
    category: "Code",
    seconds: 1800
  }, {
    domain: "stackoverflow.com",
    category: "Code",
    seconds: 1200
  }, {
    domain: "figma.com",
    category: "Design",
    seconds: 1882
  }, {
    domain: "notion.so",
    category: "Writing",
    seconds: 1646
  }, {
    domain: "linear.app",
    category: "Code",
    seconds: 900
  }, {
    domain: "youtube.com",
    category: "Browsing",
    seconds: 470
  }],
  goals: [{
    category: "Code",
    targetHours: 6,
    currentHours: 4.1,
    color: "#7c5cfc"
  }, {
    category: "Design",
    targetHours: 1,
    currentHours: 0.52,
    color: "#00ccbf"
  }, {
    category: "Writing",
    targetHours: 0.5,
    currentHours: 0.46,
    color: "#35a882"
  }],
  pomodoroSessions: [{
    id: 1,
    goal: "Draft migration spec",
    startTime: "08:00",
    durationSeconds: 1500,
    status: "completed"
  }, {
    id: 2,
    goal: "Review open PRs",
    startTime: "09:30",
    durationSeconds: 1800,
    status: "completed"
  }, {
    id: 3,
    goal: "Debug auth flow",
    startTime: "11:00",
    durationSeconds: 2100,
    status: "completed"
  }, {
    id: 4,
    goal: "Write component docs",
    startTime: "14:00",
    durationSeconds: 1500,
    status: "completed"
  }],
  insights: {
    totalProductive: "4h 12m",
    totalTracked: "6h 32m",
    avgPerDay: "4h 8m",
    daysWithData: 28,
    avgSwitches: "24",
    totalSwitches: 672,
    bestDay: {
      label: "Wednesday",
      hours: "5h 30m"
    },
    peakHour: {
      label: "10:00 AM",
      hours: "1h 20m"
    },
    streaks: {
      current: 7,
      longest: 12,
      thresholdHours: 3
    },
    dayOfWeek: [{
      label: "Mon",
      avgHours: 5.2
    }, {
      label: "Tue",
      avgHours: 6.1
    }, {
      label: "Wed",
      avgHours: 5.8
    }, {
      label: "Thu",
      avgHours: 4.9
    }, {
      label: "Fri",
      avgHours: 3.7
    }, {
      label: "Sat",
      avgHours: 1.2
    }, {
      label: "Sun",
      avgHours: 0.8
    }],
    trend: Array.from({
      length: 28
    }, (_, i) => ({
      label: `${i + 1}`,
      hours: Math.max(0.2, 4 + Math.sin(i * 0.4) * 1.5 + (i % 7 >= 5 ? -2.5 : 0) + (Math.random() - 0.5) * 0.5)
    })),
    heatmap: Array.from({
      length: 7
    }, (_, row) => Array.from({
      length: 24
    }, (_, col) => {
      const isWeekday = row < 5;
      const isPeak = col >= 9 && col <= 12;
      const isWork = col >= 8 && col <= 18;
      if (isWeekday && isPeak) return 0.45 + row * col * 7 % 11 / 20;
      if (isWeekday && isWork) return 0.15 + row * col * 3 % 7 / 20;
      return row * col % 5 / 40;
    }))
  }
};
window.MOCK = MOCK;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/mock-data.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/pomodoro-screen.jsx
try { (() => {
// pomodoro-screen.jsx — Personale Pomodoro Timer
// Exports: window.PomodoroScreen

function PomodoroScreen() {
  const {
    formatTime,
    catColor,
    Card,
    SectionLabel,
    CircularRing,
    Divider
  } = window.UI;
  const m = window.MOCK;
  const [isRunning, setIsRunning] = React.useState(false);
  const [elapsed, setElapsed] = React.useState(0);
  const [target, setTarget] = React.useState(25 * 60);
  const [goal, setGoal] = React.useState('');
  const [tab, setTab] = React.useState('Current Session');
  const [sessions, setSessions] = React.useState(m.pomodoroSessions);
  const [aiInsight, setAiInsight] = React.useState(null);
  const [generating, setGenerating] = React.useState(false);
  const intervalRef = React.useRef(null);
  React.useEffect(() => {
    if (isRunning) {
      intervalRef.current = setInterval(() => setElapsed(e => e + 1), 1000);
    } else {
      clearInterval(intervalRef.current);
    }
    return () => clearInterval(intervalRef.current);
  }, [isRunning]);
  const progress = Math.min(1, elapsed / target);
  const handleStart = () => {
    setElapsed(0);
    setIsRunning(true);
  };
  const handleEnd = () => {
    setIsRunning(false);
    const newSession = {
      id: sessions.length + 1,
      goal: goal || 'Untitled session',
      startTime: '17:00',
      durationSeconds: elapsed,
      status: elapsed >= target ? 'completed' : 'partial'
    };
    setSessions(s => [newSession, ...s]);
    setElapsed(0);
    setGoal('');
  };
  const handleGenerate = () => {
    setGenerating(true);
    setTimeout(() => {
      setAiInsight("Strong deep-work session. You stayed in Code for 78% of the time with minimal context switches. VS Code dominated — likely architecture or feature work given the 90-minute block.");
      setGenerating(false);
    }, 1800);
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 20,
      display: 'flex',
      gap: 14,
      height: '100%',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      padding: '32px 24px',
      gap: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(CircularRing, {
    value: progress,
    size: 240,
    strokeWidth: 10,
    color: "var(--color-chart-cyan)"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 48,
      fontWeight: 700,
      fontFamily: 'monospace',
      color: 'var(--color-foreground)',
      letterSpacing: '-2px',
      lineHeight: 1
    }
  }, formatTime(isRunning ? elapsed : target)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: 'var(--color-muted-foreground)',
      marginTop: 8
    }
  }, isRunning ? 'Focus running' : 'Ready to start')))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      marginTop: 24
    }
  }, !isRunning ? /*#__PURE__*/React.createElement("button", {
    onClick: handleStart,
    style: pomoBtnStyle(true)
  }, "\u25B6  Start") : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("button", {
    onClick: handleEnd,
    style: pomoBtnStyle(true)
  }, "\u25FC  End Focus"), /*#__PURE__*/React.createElement("button", {
    onClick: () => setTarget(t => t + 300),
    style: pomoBtnStyle(false)
  }, "+5 min"), /*#__PURE__*/React.createElement("button", {
    onClick: () => {
      setIsRunning(false);
      setElapsed(0);
    },
    style: pomoBtnStyle(false)
  }, "\u2715 Discard"))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      marginTop: 16
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-muted-foreground)'
    }
  }, "Target:"), [15, 25, 45, 60].map(m => /*#__PURE__*/React.createElement("button", {
    key: m,
    onClick: () => setTarget(m * 60),
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: target === m * 60 ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
      background: target === m * 60 ? 'var(--color-secondary)' : 'transparent',
      border: 'none',
      borderRadius: 4,
      padding: '3px 8px',
      cursor: 'pointer'
    }
  }, m, "m")))), /*#__PURE__*/React.createElement(Card, {
    style: {
      width: 320,
      display: 'flex',
      flexDirection: 'column',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 2,
      padding: '14px 16px 10px'
    }
  }, ['Current Session', 'Timeline'].map(t => /*#__PURE__*/React.createElement("button", {
    key: t,
    onClick: () => setTab(t),
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: tab === t ? 'var(--color-foreground)' : 'var(--color-muted-foreground)',
      background: tab === t ? 'var(--color-secondary)' : 'transparent',
      border: 'none',
      borderRadius: 4,
      padding: '4px 10px',
      cursor: 'pointer'
    }
  }, t))), /*#__PURE__*/React.createElement(Divider, null), tab === 'Current Session' ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 16,
      flex: 1,
      overflow: 'auto',
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, null, "Goal"), /*#__PURE__*/React.createElement("textarea", {
    value: goal,
    onChange: e => setGoal(e.target.value),
    placeholder: "I will [task] so that [outcome]\u2026",
    rows: 3,
    style: {
      background: 'var(--color-secondary)',
      border: '1px solid var(--color-border)',
      borderRadius: 6,
      padding: 10,
      fontSize: 12,
      color: 'var(--color-foreground)',
      fontFamily: 'inherit',
      resize: 'none',
      outline: 'none',
      lineHeight: 1.5
    }
  }), !isRunning && goal.length > 0 && goal.length < 15 && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6,
      padding: '8px 10px',
      background: 'rgba(0,204,184,0.08)',
      borderRadius: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-accent)'
    }
  }, "\u2726"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 10,
      color: 'var(--color-muted-foreground)',
      lineHeight: 1.5
    }
  }, "Tip: write an intention, not just a topic. \"Draft the migration spec\" beats \"work on DB\".")), /*#__PURE__*/React.createElement(Divider, null), /*#__PURE__*/React.createElement(SectionLabel, null, "Session Info"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 6
    }
  }, [['Target', `${target / 60} min`], ['Status', isRunning ? 'Running' : 'Idle'], ...(isRunning ? [['Elapsed', formatTime(elapsed)]] : [])].map(([k, v]) => /*#__PURE__*/React.createElement("div", {
    key: k,
    style: {
      display: 'flex',
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-muted-foreground)'
    }
  }, k), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      fontFamily: 'monospace',
      color: 'var(--color-foreground)'
    }
  }, v))))) : /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: 'auto',
      padding: '12px 16px'
    }
  }, sessions.map((s, i) => /*#__PURE__*/React.createElement("div", {
    key: s.id
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      padding: '8px 0'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 6,
      height: 6,
      borderRadius: '50%',
      background: s.status === 'completed' ? 'var(--color-success)' : 'var(--color-warning)',
      marginTop: 4,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 500,
      color: 'var(--color-foreground)',
      marginBottom: 2
    }
  }, s.goal), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      color: 'var(--color-muted-foreground)',
      marginBottom: 4
    }
  }, s.startTime, " \xB7 ", s.durationSeconds < 3600 ? Math.floor(s.durationSeconds / 60) + 'm' : (s.durationSeconds / 3600).toFixed(1) + 'h'), i === 0 && aiInsight && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      color: 'var(--color-muted-foreground)',
      lineHeight: 1.5,
      marginBottom: 4
    }
  }, aiInsight), i === 0 && /*#__PURE__*/React.createElement("button", {
    onClick: handleGenerate,
    style: {
      fontSize: 10,
      color: 'var(--color-primary)',
      background: 'transparent',
      border: 'none',
      cursor: 'pointer',
      padding: 0
    }
  }, generating ? '…' : aiInsight ? '✦ Regenerate' : '✦ Generate AI insight'))), i < sessions.length - 1 && /*#__PURE__*/React.createElement(Divider, null))))));
}
function pomoBtnStyle(primary) {
  return {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 6,
    fontSize: 12,
    fontWeight: 500,
    fontFamily: 'inherit',
    color: primary ? 'var(--color-primary-foreground)' : 'var(--color-foreground)',
    background: primary ? 'var(--color-primary)' : 'var(--color-secondary)',
    border: primary ? 'none' : '1px solid rgba(43,43,49,0.6)',
    borderRadius: 7,
    padding: '7px 14px',
    cursor: 'pointer'
  };
}
window.PomodoroScreen = PomodoroScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/pomodoro-screen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/ui-components.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
// ui-components.jsx — Shared UI primitives for Personale UI Kit
// Exports: window.UI

const {
  useState,
  useEffect,
  useRef,
  useCallback
} = React;

// ── Utilities ────────────────────────────────────────────────
function formatDuration(secs) {
  if (!secs) return '0m';
  const h = Math.floor(secs / 3600);
  const m = Math.floor(secs % 3600 / 60);
  if (h > 0 && m > 0) return `${h}h ${m}m`;
  if (h > 0) return `${h}h`;
  return `${m}m`;
}
function formatTime(secs) {
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}
const CATEGORY_COLORS = {
  Code: '#7c5cfc',
  Browsing: '#f5a623',
  Communication: '#d64d8a',
  Design: '#00ccbf',
  Writing: '#35a882',
  Media: '#9b85f5',
  Utilities: '#6b7280',
  Reading: '#3b82f6',
  Other: '#3d4451'
};
function catColor(cat) {
  return CATEGORY_COLORS[cat] || CATEGORY_COLORS.Other;
}

// ── Card ─────────────────────────────────────────────────────
function Card({
  children,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      background: 'var(--color-card)',
      borderRadius: '8px',
      border: '1px solid rgba(43,43,49,0.5)',
      ...style
    }
  }, rest), children);
}

// ── SectionLabel ─────────────────────────────────────────────
function SectionLabel({
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: '10px',
      fontWeight: 600,
      letterSpacing: '0.8px',
      textTransform: 'uppercase',
      color: 'var(--color-muted-foreground)',
      ...style
    }
  }, children);
}

// ── DonutChart ───────────────────────────────────────────────
function DonutChart({
  segments,
  size = 130,
  holeRatio = 0.55,
  center
}) {
  const conicParts = [];
  let cum = 0;
  segments.forEach(seg => {
    const deg = seg.percent * 3.6;
    conicParts.push(`${seg.color} ${cum}deg ${cum + deg}deg`);
    cum += deg;
  });
  const holeSize = size * holeRatio;
  const holePad = (size - holeSize) / 2;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: size,
      height: size,
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: size,
      height: size,
      borderRadius: '50%',
      background: `conic-gradient(${conicParts.join(', ')})`,
      transform: 'rotate(-90deg)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: holePad,
      left: holePad,
      width: holeSize,
      height: holeSize,
      borderRadius: '50%',
      background: 'var(--color-card)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, center));
}

// ── CircularRing ─────────────────────────────────────────────
function CircularRing({
  value = 0,
  size = 200,
  strokeWidth = 8,
  color = '#7c5cfc',
  children
}) {
  const r = (size - strokeWidth) / 2;
  const circ = 2 * Math.PI * r;
  const offset = circ * (1 - Math.min(1, Math.max(0, value)));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: size,
      height: size,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    viewBox: `0 0 ${size} ${size}`,
    style: {
      position: 'absolute',
      top: 0,
      left: 0
    }
  }, /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r,
    fill: "none",
    stroke: "rgba(43,43,49,0.6)",
    strokeWidth: strokeWidth
  }), /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r,
    fill: "none",
    stroke: color,
    strokeWidth: strokeWidth,
    strokeLinecap: "round",
    strokeDasharray: circ,
    strokeDashoffset: offset,
    transform: `rotate(-90 ${size / 2} ${size / 2})`,
    style: {
      transition: 'stroke-dashoffset 0.5s ease-out'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 1,
      textAlign: 'center'
    }
  }, children));
}

// ── BarFill ──────────────────────────────────────────────────
function BarFill({
  value,
  color,
  height = 6,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height,
      borderRadius: 2,
      background: 'rgba(43,43,49,0.5)',
      overflow: 'hidden',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: `${Math.min(100, Math.max(0, value))}%`,
      height: '100%',
      background: color,
      borderRadius: 2,
      transition: 'width 0.4s ease'
    }
  }));
}

// ── TimelineStrip ─────────────────────────────────────────────
function TimelineStrip({
  blocks,
  dayStart = 8
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: 36,
      borderRadius: 4,
      background: 'rgba(35,35,41,0.4)',
      overflow: 'hidden'
    }
  }, blocks.map((b, i) => {
    const left = (b.start - dayStart + 24) % 24 / 24 * 100;
    const width = Math.max(0.5, (b.end - b.start) / 24 * 100);
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      title: b.label || b.type,
      style: {
        position: 'absolute',
        top: 0,
        height: '100%',
        left: `${left}%`,
        width: `${width}%`,
        background: catColor(b.type),
        opacity: 0.85,
        borderRadius: 2
      }
    });
  }));
}

// ── Divider ──────────────────────────────────────────────────
function Divider({
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 1,
      background: 'rgba(43,43,49,0.4)',
      ...style
    }
  });
}
window.UI = {
  formatDuration,
  formatTime,
  catColor,
  CATEGORY_COLORS,
  Card,
  SectionLabel,
  DonutChart,
  CircularRing,
  BarFill,
  TimelineStrip,
  Divider
};
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/ui-components.jsx", error: String((e && e.message) || e) }); }

__ds_ns.ProgressBar = __ds_scope.ProgressBar;

__ds_ns.TimelineBar = __ds_scope.TimelineBar;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.CATEGORY_COLORS = __ds_scope.CATEGORY_COLORS;

__ds_ns.CategoryBadge = __ds_scope.CategoryBadge;

__ds_ns.CircularProgress = __ds_scope.CircularProgress;

__ds_ns.SectionTitle = __ds_scope.SectionTitle;

__ds_ns.StatCard = __ds_scope.StatCard;

__ds_ns.TabBar = __ds_scope.TabBar;

})();
