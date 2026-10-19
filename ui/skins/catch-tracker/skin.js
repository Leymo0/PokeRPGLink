// Catch Tracker — an example PokeRPGLink plugin. Copy this folder to start your own.
// The full API is in SKINS.md.
(function () {
  const T = window.PokeRPGLink;
  const { esc, icon } = T.ui;

  // every wild Pokémon in the current area, de-duplicated
  function areaMons(state) {
    const seen = {};
    for (const g of (state.map && state.map.encounters) || []) {
      for (const e of g.list) {
        const cur = seen[e.species] || (seen[e.species] = { ...e, times: [] });
        cur.times.push(g.time);
      }
    }
    return Object.values(seen);
  }

  // 1. a progress bar on top of the Area tab
  T.addSection("area", (state) => {
    const mons = areaMons(state);
    if (!mons.length) return "";
    const got = mons.filter((m) => m.owned).length;
    const pct = Math.round((100 * got) / mons.length);
    return `<div class="ct-bar"><span>${got === mons.length ? "Area complete!" : `${got} of ${mons.length} caught here`}</span>
      <div class="ct-track"><i style="width:${pct}%"></i></div></div>`;
  });

  // 2. a banner in wild battles telling you if the foe is new
  T.addSection("battle", (state) => {
    const b = state.battle;
    if (!b || b.trainer) return "";
    const foe = b.battlers.find((x) => !x.own);
    if (!foe) return "";
    return foe.owned
      ? `<div class="ct-banner old">Already caught ${esc(foe.speciesName)}</div>`
      : `<div class="ct-banner new">New! ${esc(foe.speciesName)} isn't in your collection yet</div>`;
  });

  // 3. a whole tab: what you still need from this area, and when it shows up
  T.addTab({
    id: "tocatch",
    label: "To catch",
    icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><circle cx="12" cy="12" r="3" fill="currentColor"/></svg>',
    render(state) {
      const need = areaMons(state).filter((m) => !m.owned);
      if (!need.length) return `<div class="empty">Nothing left to catch here.</div>`;
      return `<h2>Still to catch in ${esc(state.map.name)}</h2>` + need.map((m) =>
        `<div class="row-btn">${icon(m.icon, m.name, true)}<b style="flex:1">${esc(m.seen ? m.name : "???")}</b>
         <span class="muted">${[...new Set(m.times)].map((t) => (t === "any" ? "any time" : t)).join(", ")}</span></div>`).join("");
    },
  });
})();
