// ds-base.js — Personale Design System loader for templates
// To use in a consuming project, update the `base` path to point
// to where the DS bundle lives relative to this file.
// e.g. if this template is at _ds/personale-app/, use base = '../..'
(() => {
  const base = '../..';

  // Inject global CSS tokens
  for (const p of ['styles.css']) {
    const l = document.createElement('link');
    l.rel = 'stylesheet';
    l.href = base + '/' + p;
    document.head.appendChild(l);
  }

  // Inject the compiled component bundle
  const s = document.createElement('script');
  s.src = base + '/_ds_bundle.js';
  s.onerror = () => console.error(
    'ds-base.js: failed to load ' + s.src +
    ' — if this is a consuming project, point the `base` variable in ds-base.js ' +
    'at the _ds/<folder> tree relative to this page.'
  );
  document.head.appendChild(s);
})();
