/* Original, simple type glyphs (white on the type colour). Used by move buttons and skins:
 * window.TYPE_ICONS.FIRE -> "<svg …>" */
(function () {
  const g = (d, extra = "") => `<svg viewBox="0 0 24 24" class="tglyph" aria-hidden="true">${d}${extra}</svg>`;
  const F = 'fill="#fff"', S = 'fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"';
  window.TYPE_ICONS = {
    NORMAL:   g(`<circle cx="12" cy="12" r="7.5" ${S}/><circle cx="12" cy="12" r="2.6" ${F}/>`),
    FIRE:     g(`<path ${F} d="M12 2.5c1 3.6 5.8 5.6 5.8 11 0 3.6-2.6 6.5-5.8 6.5s-5.8-2.9-5.8-6.5c0-2.6 1.3-4.3 2.6-5.3-.1 1.9.6 3.2 1.8 3.8C9.8 9.4 10.6 5.6 12 2.5z"/>`),
    WATER:    g(`<path ${F} d="M12 2.8c3.4 4.7 6 8.2 6 11.4A6 6 0 0 1 6 14.2C6 11 8.6 7.5 12 2.8z"/>`),
    GRASS:    g(`<path ${F} d="M19.5 4.5C10 4.6 5 9.4 5 15.2c0 1.5.4 2.8 1 3.9l-1.8 1.7 1.3 1.3 1.8-1.8c1 .6 2.3.9 3.6.9 6 0 8.9-6.3 8.6-16.3zM8.6 17.3c2-3.9 4.8-6.6 8-8.2-2.4 2.2-4.7 5-6.6 9z"/>`),
    ELECTRIC: g(`<path ${F} d="M13.6 2 5 13.4h5.6L9.4 22l9.6-12.2h-5.8z"/>`),
    ICE:      g(`<path ${S} d="M12 2.8v18.4M4 7.4l16 9.2M4 16.6l16-9.2M9.6 4.4 12 6.6l2.4-2.2M9.6 19.6 12 17.4l2.4 2.2"/>`),
    FIGHTING: g(`<path ${F} d="M7 9.2a2.2 2.2 0 0 1 4.4 0V8a2.2 2.2 0 0 1 4.4 0v1a2 2 0 0 1 3.9.6v4.6c0 4-3 6.8-6.9 6.8H11c-3.4 0-6-2.6-6-5.8v-3.4a2 2 0 0 1 2-1.9z"/>`),
    POISON:   g(`<circle cx="12" cy="9.5" r="6.3" ${F}/><circle cx="7.4" cy="18.3" r="2.6" ${F}/><circle cx="15.8" cy="19" r="2" ${F}/>`),
    GROUND:   g(`<path ${F} d="M2.5 19.5 9 7.5l4 7 2.6-4 5.9 9z"/>`),
    FLYING:   g(`<path ${F} d="M3 13.6c3.5.4 6.3-.6 8.6-3.2 2.6-2.9 5.5-5 9.4-5.4-1.3 2.6-3 4.4-5 5.6 1.6.2 3 0 4.4-.6-1.7 2.8-4.3 4.2-7.4 4.4 1.2.6 2.5.8 4 .6-2.6 3.5-7.7 4.4-12.4 1.4z"/>`),
    PSYCHIC:  g(`<path ${S} d="M12 12.4c0-1 .9-1.7 1.8-1.4 1.5.5 1.6 2.6.5 3.6-1.8 1.6-4.8.8-5.5-1.6-.9-3.2 1.7-6 5-5.8 4.1.3 6.2 4.8 4.4 8.4-2.2 4.4-8.4 5.2-11.7 1.6"/>`),
    BUG:      g(`<ellipse cx="12" cy="13.6" rx="5.4" ry="6.6" ${F}/><path ${S} d="M9.4 5.8 7.6 3.4M14.6 5.8l1.8-2.4M12 7.6v12.4"/>`, `<path d="M12 8v12" stroke="#000" stroke-opacity=".25" stroke-width="1.6"/>`),
    ROCK:     g(`<path ${F} d="M8 3.6h7.6l5.4 6-2.6 9.8H6.4L3 10.2z"/><path d="M8 3.6 10.6 10l-7.6.2M10.6 10l7.8 9.4M15.6 3.6 10.6 10l10.4-.4" fill="none" stroke="#000" stroke-opacity=".22" stroke-width="1.3"/>`),
    GHOST:    g(`<path ${F} d="M12 2.8a7 7 0 0 0-7 7v11l2.4-1.8 2.3 1.8 2.3-1.8 2.3 1.8 2.3-1.8 2.4 1.8v-11a7 7 0 0 0-7-7z"/><circle cx="9.4" cy="10.4" r="1.6" fill="#000" fill-opacity=".35"/><circle cx="14.6" cy="10.4" r="1.6" fill="#000" fill-opacity=".35"/>`),
    DRAGON:   g(`<path ${F} d="M20.6 3.4c-5.6.6-10.4 3.4-12.6 8.1-1.4 3-1.2 6.2.4 9.2.2-2.3 1-4.2 2.4-5.6-.2 2 .1 3.8 1 5.4 1.4-3.6 3.6-6 6.8-7.3-1.9-.1-3.5.3-4.8 1.1 1.8-3.8 4.2-7 6.8-10.9z"/>`),
    DARK:     g(`<path ${F} d="M15.6 3a9 9 0 1 0 5.4 14.8A8.4 8.4 0 0 1 15.6 3z"/>`),
    STEEL:    g(`<path ${F} d="M12 2.6 20.2 7.3v9.4L12 21.4l-8.2-4.7V7.3z"/><circle cx="12" cy="12" r="3.4" fill="#000" fill-opacity=".3"/>`),
    FAIRY:    g(`<path ${F} d="M12 2.4c.8 4.4 2.4 6.6 6.8 7.6-4.4 1-6 3.2-6.8 7.6-.8-4.4-2.4-6.6-6.8-7.6 4.4-1 6-3.2 6.8-7.6z"/><path ${F} d="M18.4 14.6c.4 2.2 1.2 3.2 3.2 3.6-2 .5-2.8 1.5-3.2 3.6-.4-2.1-1.2-3.1-3.2-3.6 2-.4 2.8-1.4 3.2-3.6z"/>`),
    SHADOW:   g(`<circle cx="12" cy="12" r="8" ${F} fill-opacity=".9"/><circle cx="12" cy="12" r="3.6" fill="#000" fill-opacity=".5"/>`),
    QMARKS:   g(`<path ${S} d="M8.8 8.6a3.3 3.3 0 1 1 4.8 3c-1 .6-1.6 1.3-1.6 2.6v.6"/><circle cx="12" cy="18.4" r="1.4" ${F}/>`),
  };
  window.typeIcon = (t) => window.TYPE_ICONS[String(t || "").toUpperCase()] || window.TYPE_ICONS.QMARKS;
})();
