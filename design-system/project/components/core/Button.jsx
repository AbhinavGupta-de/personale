import React from 'react';

/**
 * Primary action button. Three visual variants matching Personale's interaction patterns.
 */
export function Button({
  children,
  variant = 'primary',
  size = 'md',
  icon,
  disabled = false,
  onClick,
  style,
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
    opacity: disabled ? 0.5 : pressed ? 0.7 : hovered ? 0.85 : 1,
  };

  const variantMap = {
    primary: {
      background: 'var(--color-primary)',
      color: 'var(--color-primary-foreground)',
      border: '1px solid transparent',
    },
    secondary: {
      background: 'var(--color-secondary)',
      color: 'var(--color-foreground)',
      border: '1px solid rgba(43,43,49,0.6)',
    },
    ghost: {
      background: 'transparent',
      color: 'var(--color-foreground)',
      border: '1px solid transparent',
    },
    destructive: {
      background: 'rgba(220,40,40,0.15)',
      color: 'var(--color-destructive)',
      border: '1px solid rgba(220,40,40,0.25)',
    },
  };

  const sizeMap = {
    sm: { fontSize: '11px', padding: '5px 10px', height: '26px' },
    md: { fontSize: '12px', padding: '6px 14px', height: '30px' },
    lg: { fontSize: '13px', padding: '8px 18px', height: '36px' },
  };

  return (
    <button
      style={{ ...base, ...variantMap[variant], ...sizeMap[size], ...style }}
      disabled={disabled}
      onClick={disabled ? undefined : onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => { setHovered(false); setPressed(false); }}
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
    >
      {icon && <span style={{ display: 'flex', alignItems: 'center' }}>{icon}</span>}
      {children}
    </button>
  );
}
