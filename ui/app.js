/* PokeRPGLink bottom-screen UI.
 * Talks to the Android app through window.PokeRPGBridge (see BridgeJs.java):
 *   readState() -> JSON text of PokeRPGLink/state.json, or "" when unchanged
 *   readFile(name) -> text of PokeRPGLink/<name> ("" if missing)
 *   fileTime(name) -> last-modified time in ms (0 if missing)
 *   send(line)  -> drops a command file for the game
 *   root()      -> file:// URL of the game folder (ends with "/")
 *   haptic()    -> short vibration
 */
"use strict";
const B = window.PokeRPGBridge;
const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

/* ---------------- icons (inline SVG, no network) ---------------- */
const I = {
  sun: '<svg viewBox="0 0 24 24" fill="#f3b23c"><circle cx="12" cy="12" r="5"/><g stroke="#f3b23c" stroke-width="2.2" stroke-linecap="round"><path d="M12 1.5v3M12 19.5v3M1.5 12h3M19.5 12h3M4.6 4.6l2.1 2.1M17.3 17.3l2.1 2.1M4.6 19.4l2.1-2.1M17.3 6.7l2.1-2.1"/></g></svg>',
  moon: '<svg viewBox="0 0 24 24" fill="#b9b2ff"><path d="M20 15.3A8.5 8.5 0 0 1 8.7 4a8.5 8.5 0 1 0 11.3 11.3z"/></svg>',
  dawn: '<svg viewBox="0 0 24 24"><path d="M5 17a7 7 0 0 1 14 0z" fill="#ff9d5c"/><path d="M2 20h20" stroke="#ff9d5c" stroke-width="2.2" stroke-linecap="round"/><path d="M12 3v4M5 7l2 2M19 7l-2 2" stroke="#ff9d5c" stroke-width="2" stroke-linecap="round"/></svg>',
  dusk: '<svg viewBox="0 0 24 24"><path d="M5 17a7 7 0 0 1 14 0z" fill="#e2709a"/><path d="M2 20h20" stroke="#e2709a" stroke-width="2.2" stroke-linecap="round"/></svg>',
  ball: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#fff"/><path d="M2 12a10 10 0 0 1 20 0z" fill="#e0533f"/><path d="M2 12h20" stroke="#1a1530" stroke-width="2"/><circle cx="12" cy="12" r="3.2" fill="#fff" stroke="#1a1530" stroke-width="2"/></svg>',
  area: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20c2-5 3-9 3-9s1 4 3 9M11 20c2-6 4-12 4-12s2 6 4 12M2 20h20"/></svg>',
  party: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M3 12h6M15 12h6"/><circle cx="12" cy="12" r="3"/></svg>',
  bag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M5 8h14l-1 12H6z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/><path d="M9 13h6"/></svg>',
  map: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2z"/><path d="M9 4v14M15 6v14"/></svg>',
  dex: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><rect x="4" y="3" width="16" height="18" rx="2"/><circle cx="9" cy="8" r="2.2"/><path d="M8 14h8M8 17h5"/></svg>',
  save: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M5 3h11l3 3v15H5z"/><path d="M8 3v6h7V3M8 21v-7h8v7"/></svg>',
  pad: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z" opacity=".9"/></svg>',
  gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1" stroke-linecap="round"/></svg>',
  play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5.5v13a1 1 0 0 0 1.5.86l10.6-6.5a1 1 0 0 0 0-1.72L9.5 4.64A1 1 0 0 0 8 5.5z"/></svg>',
  hide: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M5 12h14"/></svg>',
  close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  up: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 6l7 9H5z"/></svg>',
  down: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 18l7-9H5z"/></svg>',
  left: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 12l9-7v14z"/></svg>',
  right: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M18 12l-9-7v14z"/></svg>',
  rain: '<svg viewBox="0 0 24 24" fill="none" stroke="#8fb6ff" stroke-width="2" stroke-linecap="round"><path d="M7 15a4 4 0 1 1 1-7.9A5 5 0 0 1 18 9a3 3 0 0 1-1 6z"/><path d="M9 18l-1 3M13 18l-1 3M17 18l-1 3"/></svg>',
  field: '<svg viewBox="0 0 24 24" fill="none" stroke="#d6c4ff" stroke-width="2" stroke-linejoin="round"><path d="M12 2l3 7 7 3-7 3-3 7-3-7-7-3 7-3z"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="#9fd8ff" stroke-width="2" stroke-linejoin="round"><path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/></svg>',
};
const periodIcon = (p) => ({ morning: I.dawn, day: I.sun, evening: I.dusk, night: I.moon }[p] || I.sun);
const periodName = (p) => ({ morning: "Morning", day: "Day", evening: "Evening", night: "Night" }[p] || "Day");

/* ---------------- state ---------------- */
let S = null;               // latest game state
let root = "";
let ui = { tab: "area", btab: "fight", pocket: null, dexType: null, dexFilter: "all", mapZoom: 1, special: false };
let dex = null, dexTime = 0, townmap = null, townTime = 0, lastDexReq = 0;
let sheet = null;           // {kind, ...}
let seenToasts = new Set();
let lastRender = "";
let lastStateAt = 0;
let scrollMemo = {};

// One battle action at a time: after choosing a move / switch / item / ball / run, further
// battle taps are ignored until the game asks for the next choice (the mod reports "busy").
const FINAL = /^(bmove|bitem|bball|bswitch|bcmd 3)\b/;
let sentAt = 0;
function battleLocked() { return !!(S && S.mode === "battle" && (S.busy || Date.now() - sentAt < 1200)); }
function send(line) {
  if (/^b(move|item|ball|switch|cmd)\b/.test(line)) {
    if (battleLocked()) return;
    if (FINAL.test(line)) { sentAt = Date.now(); setTimeout(() => render(true), 1250); }
  }
  try { B.send(line); if (settings.haptics !== false && B.haptic) B.haptic(); } catch (e) { console.log("send", line); }
}
const IMG = {};
function img(path) {
  if (!path) return "";
  if (path.startsWith("data:") || /^[a-z]+:/i.test(path) || path.startsWith("skins/")) return path;
  if (B.image) {
    if (!(path in IMG)) { try { IMG[path] = B.image(path); } catch (e) { IMG[path] = ""; } }
    if (IMG[path]) return IMG[path];
    if (path.startsWith("PokeRPGLink/cache/")) delete IMG[path];   // still being drawn by the game: ask again later
  }
  return root + encodeURI(path).replace(/#/g, "%23");
}
// icon for anything with {icon, species, dex}; falls back to a file-name search in the game folder
const FOUND = {};
const MISS = {};
function cachedIcon(species) {
  // icons the game draws into PokeRPGLink/cache in the background (Pokédex)
  const c = "PokeRPGLink/cache/icon_" + species + "_0.png";
  if (IMG[c]) return c;
  if (!B.image || MISS[c] > Date.now() - 3000) return null;
  let d = ""; try { d = B.image(c); } catch (e) {}
  if (d) { IMG[c] = d; return c; }
  MISS[c] = Date.now();
  return null;
}
function iconPath(o) {
  if (!o) return null;
  if (o.icon) return o.icon;
  if (o.species) { const c = cachedIcon(o.species); if (c) return c; }
  if (!B.findIcon || !o.species) return null;
  const k = o.species + "|" + (o.dex || 0);
  if (!(k in FOUND)) { try { FOUND[k] = B.findIcon(o.species, o.dex || 0) || null; } catch (e) { FOUND[k] = null; } }
  return FOUND[k];
}
const icoOf = (o, label, cls = "") => ico(iconPath(o), label, cls);

function ico(path, label, cls = "") {
  const fb = esc((label || "?").slice(0, 1));
  if (!path) return `<div class="ico ${cls}"><div class="fallback">${fb}</div></div>`;
  return `<div class="ico ${cls}"><img src="${img(path)}" alt="" onerror="this.outerHTML='<div class=fallback>${fb}</div>'"></div>`;
}
const typeChip = (t, name) => `<span class="type t-${esc(t)}">${esc(name || t)}</span>`;
const TYPE_NAMES = {};
const types = (o) => (o.types || []).map((t, i) => {
  const n = (o.typeNames || [])[i];
  if (n) TYPE_NAMES[t] = n;
  return typeChip(t, n || TYPE_NAMES[t] || pretty(t));
}).join(" ");
const statusChip = (s) => (s ? `<span class="status s-${esc(s)}">${esc({ SLEEP: "SLP", POISON: "PSN", BURN: "BRN", PARALYSIS: "PAR", FROZEN: "FRZ", FROSTBITE: "FRB", TOXIC: "TOX", NUMB: "NMB", DIZZY: "DZY", LEECHED: "LCH", WATERLOG: "WTR" }[s] || s.slice(0, 3))}</span>` : "");
function hpBar(hp, max) {
  const p = max > 0 ? Math.max(0, Math.min(100, (100 * hp) / max)) : 0;
  return `<div class="hp ${p <= 20 ? "low" : p <= 50 ? "mid" : ""}"><i style="width:${p}%"></i></div>`;
}
// Shadow Pokémon: heart gauge as 5 pips (fewer lit = closer to purification)
const heartGauge = (sh) => !sh ? "" : `<span class="heart" title="Heart gauge ${sh.stage}/${sh.max}">${Array.from({ length: sh.max }, (_, i) => `<i class="${i < sh.stage ? "on" : ""}"></i>`).join("")}</span>`;
const shadowChip = (x) => (x && x.shadow ? `<span class="chip shadowchip">Shadow</span>${heartGauge(x.shadow)}` : "");
// Rejuvenation bosses have shields; Tectonic Avatars have health bars and several moves per turn
const bossChip = (x) => (x && x.boss ? `<span class="chip bosschip">${I.shield}${esc(x.boss.label || "Boss")}${x.boss.shields ? ` · ${x.boss.shields} shield${x.boss.shields > 1 ? "s" : ""}` : ""}${x.boss.bars ? ` · ${x.boss.bars} bar${x.boss.bars > 1 ? "s" : ""}` : ""}${x.boss.actions ? ` · ${x.boss.actions} moves/turn` : ""}</span>` : "");
const STAGE_LAB = { atk: "Atk", def: "Def", spa: "SpA", spd: "SpD", spe: "Spe", acc: "Acc", eva: "Eva" };
const stageChips = (st) => Object.entries(st || {}).map(([k, v]) => `<span class="chip ${v > 0 ? "up" : "down"}">${STAGE_LAB[k] || k} ${v > 0 ? "+" + v : v}</span>`).join("");
const pretty = (id) => String(id).replace(/([a-z])([A-Z])/g, "$1 $2").replace(/_/g, " ").toLowerCase().replace(/^\w|\s\w/g, (c) => c.toUpperCase());
const WEATHER = { RAINDANCE: "Rain", SUNNYDAY: "Harsh sun", SANDSTORM: "Sandstorm", HAIL: "Hail", SNOW: "Snow", SHADOWSKY: "Shadow sky", STRONGWINDS: "Strong winds", HEAVYRAIN: "Heavy rain", HARSHSUN: "Extreme sun" };

/* ---------------- polling ---------------- */
try { if (B.resetState) B.resetState(); } catch (e) {}   // a reload (skin change) needs the state again
function poll() {
  try {
    const t = B.readState();
    if (t && B.fileTime && Date.now() - B.fileTime("state.json") > 6000 && !S) {
      // first state after opening the panel is old: the game isn't running
      S = JSON.parse(t); S._stale = true; render(true); return;
    }
    if (t) {
      const prevGame = S && S.game ? S.game.title : null;
      const prevState = S;
      S = JSON.parse(t);
      // events fire after the new screen is drawn so skins can animate the fresh elements
      setTimeout(() => diffEvents(prevState, S), 0);
      emit("state", S);
      if (S.game && S.game.title !== prevGame) {   // a different game started: reload its folder and data
        try { root = B.root(); } catch (e) {}
        dex = null; townmap = null; dexTime = 0; townTime = 0;
        document.title = S.game.title;
        if (applyGameLook()) return;   // this game uses another skin: the panel reloads with it
      }
      lastStateAt = Date.now();
      handleToasts();
      render();
    } else if (S && Date.now() - lastStateAt > 4000) {
      const mt = B.fileTime ? B.fileTime("state.json") : Date.now();
      if (Date.now() - mt > 6000 && !S._stale) { S._stale = true; render(true); }
    }
    if (S && S._stale) {
      // the game was closed (or the panel just reopened on an old save of the screen):
      // show the waiting screen with Play, and pick the game back up as soon as it writes again
      const mt = B.fileTime ? B.fileTime("state.json") : 0;
      if (mt && Date.now() - mt < 3000) { S._stale = false; try { B.resetState && B.resetState(); } catch (e) {} }
    }
  } catch (e) { console.log("poll error", e); }
}

function handleToasts() {
  for (const t of S.toasts || []) {
    if (seenToasts.has(t.id)) continue;
    seenToasts.add(t.id);
    if (Date.now() - lastStateAt > 1000 && seenToasts.size === 1) continue;
    const el = document.createElement("div");
    el.className = "toast " + (t.kind || "");
    el.textContent = t.text;
    $("#toasts").appendChild(el);
    emit("toast", { text: t.text, kind: t.kind }); emit("event", "toast", { text: t.text, kind: t.kind });
    setTimeout(() => el.remove(), 2600);
  }
}

/* ---------------- skins & plugins ----------------
 * A skin is a folder with skin.json + optional skin.css + optional skin.js.
 * skin.js talks to the panel through window.PokeRPGLink (documented in SKINS.md). */
const PLUG = { tabs: [], sections: {}, barButtons: [], listeners: { state: [], render: [], battle: [] } };
let settings = { skin: "default", scale: 1, haptics: true, effects: true, volume: 1, typePack: "auto", dimIdle: false };
function loadSettings() {
  try { const t = B.getSetting && B.getSetting("settings"); if (t) settings = { ...settings, ...JSON.parse(t) }; } catch (e) {}
  try { const t = localStorage.getItem("pokerpglink.settings"); if (t && !(B.getSetting)) settings = { ...settings, ...JSON.parse(t) }; } catch (e) {}
}
// Each game remembers its own skin and type icons. The first time a game connects it
// keeps whatever the panel is using; picking a skin while it's running updates it.
function gameKey() { return S && S.game && S.game.title ? String(S.game.title) : null; }
function rememberLook() {
  // a pick made while no game is connected still counts: the next game to connect keeps it
  const k = gameKey();
  if (!k) { settings.lastPick = { skin: settings.skin, typePack: settings.typePack || "auto", t: Date.now() }; return; }
  settings.perGame = settings.perGame || {};
  settings.perGame[k] = { skin: settings.skin, typePack: settings.typePack || "auto", t: Date.now() };
}
function applyGameLook() {
  const k = gameKey();
  if (!k) return false;
  const look = (settings.perGame || {})[k];
  const pick = settings.lastPick;
  if (!look || (pick && pick.t > (look.t || 0))) {
    settings.perGame = settings.perGame || {};
    settings.perGame[k] = { skin: settings.skin, typePack: settings.typePack || "auto", t: Date.now() };
    delete settings.lastPick;   // only the next game to connect adopts a pick made without one
    saveSettings();
    return false;
  }
  const skinChanged = look.skin && look.skin !== settings.skin;
  const packChanged = (look.typePack || "auto") !== (settings.typePack || "auto");
  if (!skinChanged && !packChanged) return false;
  settings.skin = look.skin || settings.skin;
  settings.typePack = look.typePack || "auto";
  saveSettings();
  if (skinChanged) { location.reload(); return true; }
  return false;
}

function saveSettings() {
  const t = JSON.stringify(settings);
  try { if (B.setSetting) B.setSetting("settings", t); else localStorage.setItem("pokerpglink.settings", t); } catch (e) {}
}
function listSkins() {
  try { return JSON.parse(B.listSkins()); } catch (e) { return [{ id: "default", name: "Default", builtin: true }]; }
}
function emit(ev, ...args) {
  for (const fn of PLUG.listeners[ev] || []) { try { fn(...args); } catch (e) { console.log("plugin error", ev, e); } }
}
let skinBase = "";
function pluginSections(view) {
  return (PLUG.sections[view] || []).map((f) => { try { return f(S) || ""; } catch (e) { return ""; } }).join("");
}
window.PokeRPGLink = {
  apiVersion: 1,
  /** latest game state (see STATE.md) */
  get state() { return S; },
  /** send a raw command to the game, e.g. PokeRPGLink.send("btn A") */
  send: (line) => send(line),
  /** listen: "state" (every new state), "render" (view, mainElement), "battle" (battle state when one is shown) */
  on(ev, fn) { (PLUG.listeners[ev] || (PLUG.listeners[ev] = [])).push(fn); },
  /** add an out-of-battle tab: {id, label, icon: "<svg…>", render: (state) => html} */
  addTab(tab) { PLUG.tabs.push(tab); render(true); },
  /** add html above a view's content: view = "area" | "party" | "bag" | "map" | "dex" | "save" | "battle" | your tab id */
  addSection(view, fn) { (PLUG.sections[view] || (PLUG.sections[view] = [])).push(fn); render(true); },
  /** add a button to the top bar: {id, label, icon, onClick} */
  addBarButton(btn) { PLUG.barButtons.push(btn); render(true); },
  /** show a bottom sheet with your own html (buttons inside can use data-plugin-click="name") */
  openSheet(title, html) { openSheet({ kind: "plugin", title, html }); },
  closeSheet: () => closeSheet(),
  toast(text, kind) { const el = document.createElement("div"); el.className = "toast " + (kind || ""); el.textContent = text; $("#toasts").appendChild(el); setTimeout(() => el.remove(), 2600); },
  /** handle clicks on elements with data-plugin-click="name" */
  onClick(name, fn) { PLUG.clicks = PLUG.clicks || {}; PLUG.clicks[name] = fn; },
  /** helpers that render like the built-in UI */
  ui: { esc, icon: (path, label, shadow) => ico(path, label, shadow ? "shadow" : ""), typeChip: (t) => typeChip(t, TYPE_NAMES[t] || pretty(t)), hpBar, statusChip, imageUrl: (p) => img(p), icons: I },
  settings: () => ({ ...settings }),
  /** play a sound file: a path inside your skin folder (see skinFile) or any URL */
  playSound,
  /** quick synth bleep, no audio file needed: beep(freq, ms, wave, volume, delayMs) */
  beep,
  /** Web Animations helper: animate(elementOrSelector, keyframes, msOrOptions) */
  animate,
  /** URL of a file in your skin's folder, e.g. skinFile("sounds/hit.ogg") */
  skinFile: (name) => skinBase + name,
  /** find the on-screen element for a battler slot (0–3), a move slot, or a party slot */
  find(kind, i) {
    const sel = { battler: `[data-fighter="${i}"]`, move: `.moves [data-move="${i}"]`, party: `[data-mon="${i}"], [data-switch="${i}"]` }[kind];
    return sel ? document.querySelector(sel) : null;
  },
};

function loadSkin() {
  const sk = listSkins().find((x) => x.id === settings.skin);
  document.body.dataset.skin = sk ? sk.id : "default";
  if (!sk) return;
  if (sk.css) { const l = document.createElement("link"); l.rel = "stylesheet"; l.href = sk.css; document.head.appendChild(l); }
  const any = sk.js || sk.css;
  if (any) skinBase = any.replace(/[?#].*$/, "").replace(/[^/]*$/, "");
  if (sk.js) { const sc = document.createElement("script"); sc.src = sk.js; document.body.appendChild(sc); }
}
// type icon packs from <storage>/PokeRPGLink/typeicons/<pack>/FIRE.png …
let TYPE_PACKS = null;
function typePacks() {
  if (TYPE_PACKS) return TYPE_PACKS;
  try { TYPE_PACKS = JSON.parse((B.listTypePacks && B.listTypePacks()) || "[]"); } catch (e) { TYPE_PACKS = []; }
  return TYPE_PACKS;
}
const builtinTypeIcon = window.typeIcon;
// "auto" = the pack the current skin asks for (skin.json "typeIcons": ["Dark icons", …]) if installed
function activePack() {
  const tp = settings.typePack || "auto";
  if (tp === "builtin") return null;
  if (tp !== "auto") return typePacks().find((x) => x.id === tp) || null;
  const sk = listSkins().find((x) => x.id === settings.skin);
  const want = ((sk && sk.typeIcons) || []).map((n) => String(n).toLowerCase());
  for (const w of want) { const p = typePacks().find((x) => x.id.toLowerCase() === w || x.name.toLowerCase() === w); if (p) return p; }
  return null;
}
function packIcon(t) {
  const p = activePack();
  const u = p && p.icons[String(t || "").toUpperCase()];
  return u ? `<img class="tglyph timg" src="${u}" alt="">` : null;
}
window.typeIcon = (t) => packIcon(t) || builtinTypeIcon(t);

function applySettings() {
  document.body.style.zoom = settings.scale || 1;
}

/* ---------------- game events (for animation / sound skins) ---------------- */
function diffEvents(prev, cur) {
  if (!prev || !cur) return;
  const ev = (name, data) => { emit(name, data || {}); emit("event", name, data || {}); };
  const pb = prev.battle, cb = cur.battle;
  if (!pb && cb) ev("battleStart", { trainer: cb.trainer, double: cb.double });
  if (pb && !cb) ev("battleEnd", {});
  if (pb && cb) {
    if (cb.turn !== pb.turn) ev("turn", { turn: cb.turn + 1 });
    if (cb.menu !== pb.menu) ev("menu", { menu: cb.menu, was: pb.menu });
    const before = Object.fromEntries((pb.battlers || []).map((x) => [x.index, x]));
    for (const x of cb.battlers || []) {
      const o = before[x.index];
      if (!o || o.species !== x.species) { ev("sendOut", { index: x.index, own: x.own, name: x.name }); continue; }
      const oh = x.own ? o.hp : o.hpPct, nh = x.own ? x.hp : x.hpPct, max = x.own ? x.maxhp : 100;
      if (nh < oh) ev("damage", { index: x.index, own: x.own, name: x.name, from: oh, to: nh, fraction: (oh - nh) / (max || 1) });
      if (nh > oh) ev("heal", { index: x.index, own: x.own, name: x.name, from: oh, to: nh });
      if (x.status !== o.status && x.status) ev("status", { index: x.index, own: x.own, status: x.status });
      for (const k of new Set([...Object.keys(o.stages || {}), ...Object.keys(x.stages || {})])) {
        const d = ((x.stages || {})[k] || 0) - ((o.stages || {})[k] || 0);
        if (d) ev("statChange", { index: x.index, own: x.own, stat: k, change: d });
      }
      if (o.boss && x.boss && x.boss.shields < o.boss.shields) ev("shieldBreak", { index: x.index, left: x.boss.shields });
    }
    for (const o of pb.battlers || []) if (!(cb.battlers || []).some((x) => x.index === o.index)) ev("faint", { index: o.index, own: o.own, name: o.name });
    const lastId = ((pb.log || []).slice(-1)[0] || {}).id || 0;
    for (const l of cb.log || []) if (l.id > lastId) ev("message", { text: l.text });
    if ((cb.weather || {}).id !== (pb.weather || {}).id) ev("weather", { id: cb.weather && cb.weather.id, name: cb.weather && cb.weather.name });
    if ((cb.field || {}).id !== (pb.field || {}).id) ev("field", { id: cb.field && cb.field.id, name: cb.field && cb.field.name });
  }
  const pp = prev.player || {}, cp = cur.player || {};
  if (cp.owned > pp.owned) ev("caught", { owned: cp.owned });
  if (cp.badges > pp.badges) ev("badge", { badges: cp.badges });
  const lv = Object.fromEntries((prev.party || []).map((p) => [p.name + "|" + p.species, p.level]));
  for (const p of cur.party || []) { const o = lv[p.name + "|" + p.species]; if (o && p.level > o) ev("levelUp", { slot: p.slot, name: p.name, level: p.level }); }
  if (prev.map && cur.map && prev.map.id !== cur.map.id) ev("mapChange", { id: cur.map.id, name: cur.map.name });
  if (prev.map && cur.map && prev.map.period !== cur.map.period) ev("timeOfDay", { period: cur.map.period });
}

/* ---------------- sounds & animation helpers ---------------- */
let audioCtx = null;
const soundCache = {};
function playSound(url, opts = {}) {
  if (settings.effects === false || !url) return;
  try {
    const a = (soundCache[url] || (soundCache[url] = new Audio(url))).cloneNode();
    a.volume = Math.max(0, Math.min(1, (opts.volume ?? 0.8) * (settings.volume ?? 1)));
    a.play().catch(() => {});
  } catch (e) {}
}
// tiny synth so skins can make sounds without shipping audio files
function beep(freq = 660, ms = 70, type = "square", vol = 0.08, when = 0) {
  if (settings.effects === false) return;
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    const t = audioCtx.currentTime + when / 1000;
    const o = audioCtx.createOscillator(), g = audioCtx.createGain();
    o.type = type; o.frequency.setValueAtTime(freq, t);
    g.gain.setValueAtTime(vol * (settings.volume ?? 1), t); g.gain.exponentialRampToValueAtTime(0.0001, t + ms / 1000);
    o.connect(g).connect(audioCtx.destination); o.start(t); o.stop(t + ms / 1000 + 0.02);
  } catch (e) {}
}
function animate(target, keyframes, opts) {
  if (settings.effects === false || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  const els = typeof target === "string" ? document.querySelectorAll(target) : target ? [target] : [];
  els.forEach((el) => { try { el.animate(keyframes, typeof opts === "number" ? { duration: opts } : opts || { duration: 300 }); } catch (e) {} });
}

/* ---------------- OLED care: dim a little after 15 s without a touch ---------------- */
const DIM_AFTER_MS = 15000;
let dimTimer = null;
function wake() {
  document.body.classList.remove("idle-dim");
  clearTimeout(dimTimer);
  if (settings.dimIdle) dimTimer = setTimeout(() => document.body.classList.add("idle-dim"), DIM_AFTER_MS);
}
document.addEventListener("pointerdown", wake, true);

/* ---------------- render ---------------- */
function render(force) {
  if (!S || S._stale) return renderOffline();
  const inBattle = S.mode === "battle" && S.battle;
  const key = JSON.stringify([S.frame && 0, S, ui, sheet && sheet.kind, inBattle]);
  if (!force && key === lastRender) return;
  lastRender = key;
  const main = $("#main");
  const view = inBattle ? "b-" + ui.btab : ui.tab;
  scrollMemo[ui._view] = main.scrollTop;
  renderBar(inBattle);
  renderTabs(inBattle);
  if (S.mode === "title") main.innerHTML = `<div class="offline"><h1>Load your save</h1><p>The game is on the title screen. Once you're in the world, this screen fills in.</p></div>`;
  else if (inBattle) main.innerHTML = renderBattle();
  else {
    const pt = PLUG.tabs.find((t) => t.id === ui.tab);
    let body;
    try { body = pt ? pt.render(S) || "" : ({ area: renderArea, party: renderParty, bag: renderBag, map: renderMap, dex: renderDex, save: renderSave }[ui.tab] || renderArea)(); }
    catch (e) { body = `<div class="empty">This tab hit an error: ${esc(e.message)}</div>`; }
    main.innerHTML = pluginSections(ui.tab) + body;
  }
  if (inBattle) main.insertAdjacentHTML("afterbegin", pluginSections("battle"));
  document.body.dataset.view = view;
  document.body.classList.toggle("battle-busy", inBattle && battleLocked());
  document.body.dataset.mode = S.mode;
  document.body.dataset.double = inBattle && (S.battle.double || S.battle.battlers.filter((x) => !x.own).length > 1) ? "1" : "0";
  emit("render", view, main);
  if (inBattle) emit("battle", S.battle);
  if (ui._view === view) main.scrollTop = scrollMemo[view] || 0; else main.scrollTop = scrollMemo[view] || 0;
  ui._view = view;
  if (inBattle && S.battle.targeting && (!sheet || sheet.kind !== "gametarget")) sheet = { kind: "gametarget" };
  if (sheet) renderSheet();
  if (ui.tab === "map" && !inBattle) afterMap();
}

// game apps (Kirin, JoiPlay…) and set-up games, from the Android side; empty in a browser preview
let launchCache = null;
function launchInfo() {
  if (launchCache && Date.now() - launchCache.t < 10000) return launchCache;
  let rts = [], games = [];
  try { rts = JSON.parse(B.runtimes ? B.runtimes() : "[]"); } catch (e) {}
  try { games = JSON.parse(B.games ? B.games() : "[]"); } catch (e) {}
  launchCache = { rts, games, t: Date.now() };
  return launchCache;
}

function renderOffline() {
  $("#bar").innerHTML = `<div class="place">PokeRPGLink</div><button class="padbtn" data-act="settings" aria-label="Panel settings">${I.gear}</button><span class="dot"></span>`;
  $("#tabs").innerHTML = "";
  const { rts, games } = launchInfo();
  const names = games.map((g) => g.title);
  const what = names.length === 1 ? esc(names[0]) : "your game";
  let h = `<div class="offline"><div class="offline-in"><h1>Waiting for the game</h1>`;
  if (rts.length) {
    h += `<button class="playbtn" data-act="play" data-pkg="${esc(rts[0].id)}">${I.play || "▶"}<span>Play<small>opens ${esc(rts[0].label)} on the top screen</small></span></button>`;
    if (rts.length > 1) h += `<div class="playalt">${rts.slice(1).map((r) => `<button data-act="play" data-pkg="${esc(r.id)}">Use ${esc(r.label)}</button>`).join("")}</div>`;
    h += `<p>Then pick ${what} in ${esc(rts[0].label)}. The panel fills in as soon as your save loads.</p>`;
  } else {
    h += `<p>Start ${what} on the top screen. The panel fills in as soon as your save loads.</p>`;
  }
  if (games.some((g) => g.needsSetup)) h += `<p class="warn">The mod needs a quick update — open setup once.</p>`;
  if (B.openSetup) h += `<button class="setupbtn" data-act="setup">PokeRPGLink setup</button>`;
  h += `<p class="byline">PokeRPGLink · by Leymo</p></div></div>`;
  const html = h;
  if ($("#main").innerHTML !== html) $("#main").innerHTML = html;
}

function renderBar(inBattle) {
  const live = !S._stale;
  let h = "";
  if (inBattle) {
    const b = S.battle;
    h = `<div class="place">${b.trainer ? "Trainer battle" : "Wild battle"} <span class="sub">· turn ${b.turn + 1}</span></div>`;
  } else if (S.map) {
    h = `<div class="place">${esc(S.map.name || "Unknown area")}</div><span class="period">${periodIcon(S.map.period)}${periodName(S.map.period)}</span>`;
  } else h = `<div class="place">PokeRPGLink</div>`;
  h += PLUG.barButtons.map((b) => `<button class="padbtn" data-plugbar="${esc(b.id)}" aria-label="${esc(b.label || b.id)}">${b.icon || esc((b.label || "?").slice(0, 2))}</button>`).join("");
  h += `<button class="padbtn" data-act="settings" aria-label="Panel settings">${I.gear}</button><button class="padbtn" data-act="pad" aria-label="Buttons">${I.pad}</button>${B.setCollapsed ? `<button class="padbtn" data-act="hide" aria-label="Hide panel">${I.hide}</button>` : ""}${!live && B.play ? `<button class="padbtn" data-act="play" aria-label="Open the game app on the top screen">${I.play || "▶"}</button>` : ""}<span class="dot ${live ? "on" : ""}" title="${live ? "Connected" : "Game not responding"}"></span>`;
  $("#bar").innerHTML = h;
}

function renderTabs(inBattle) {
  const tabs = $("#tabs");
  if (inBattle) {
    const b = S.battle;
    tabs.className = "battle";
    // labels come from the game's own menu, so "Call" (vs Shadow Pokémon) or "Cancel" show up as they do on screen
    const L = (b.commands && b.commands.length === 4) ? b.commands : ["Fight", "Bag", "Pokémon", "Run"];
    const fourthOff = /^run$/i.test(L[3]) && !b.canRun;
    tabs.innerHTML = `
      <button class="b-fight" data-bt="fight" aria-current="${ui.btab === "fight"}">${esc(L[0])}</button>
      <button class="b-bag" data-bt="bag" aria-current="${ui.btab === "bag"}" ${b.noBag ? "disabled" : ""}>${esc(L[1])}</button>
      <button class="b-mon" data-bt="mon" aria-current="${ui.btab === "mon"}">${esc(L[2])}</button>
      <button class="b-run ${/call/i.test(L[3]) ? "b-call" : ""}" data-bcmd="3" ${fourthOff ? "disabled" : ""}>${esc(L[3])}</button>`;
    return;
  }
  tabs.className = "";
  const T = [["area", "Area", I.area], ["party", "Pokémon", I.party], ["bag", "Bag", I.bag], ["map", "Map", I.map], ["dex", "Pokédex", I.dex], ["save", "Save", I.save]];
  for (const t of PLUG.tabs) T.push([t.id, t.label, t.icon || I.dex]);
  tabs.innerHTML = T.map(([k, n, svg]) => `<button data-tab="${esc(k)}" aria-current="${ui.tab === k}">${svg}${esc(n)}</button>`).join("");
}

/* ---------- Area: wild Pokémon here ---------- */
const KIND = { grass: "Grass", cave: "Cave", surf: "Surfing", rocksmash: "Rock Smash", oldrod: "Old Rod", goodrod: "Good Rod", superrod: "Super Rod", headbutt: "Headbutt", bugcontest: "Bug Contest" };
function renderArea() {
  const m = S.map;
  if (!m) return `<div class="empty">No map data yet.</div>`;
  const groups = m.encounters || [];
  if (!groups.length) return `<div class="empty">No wild Pokémon live here.<br>Head into grass, caves or water to see who's around.</div>`;
  // merge time-of-day variants of the same method into one grid
  const byKind = {};
  for (const g of groups) {
    const k = byKind[g.kind] || (byKind[g.kind] = { kind: g.kind, mons: {} });
    for (const e of g.list) {
      const cur = k.mons[e.species] || (k.mons[e.species] = { ...e, times: new Set(), chance: 0, min: e.min, max: e.max });
      cur.times.add(g.time);
      cur.chance = Math.max(cur.chance, e.chance);
      cur.min = Math.min(cur.min ?? e.min, e.min ?? cur.min);
      cur.max = Math.max(cur.max ?? 0, e.max ?? 0);
    }
  }
  const now = m.period === "evening" ? "night" : m.period;
  let caughtAll = 0, total = 0;
  let h = `<div class="legend"><span>${I.ball} caught</span><span>${I.dawn} morning</span><span>${I.sun} day</span><span>${I.moon} night</span><span class="muted">no icon = any time</span></div>`;
  for (const k of Object.values(byKind)) {
    const mons = Object.values(k.mons).sort((a, b) => b.chance - a.chance);
    const owned = mons.filter((x) => x.owned).length;
    caughtAll += owned; total += mons.length;
    h += `<h2>${esc(KIND[k.kind] || pretty(k.kind))}<span class="count">${owned}/${mons.length} caught</span></h2><div class="grid">`;
    for (const e of mons) {
      const anyTime = e.times.has("any");
      const timed = anyTime ? [] : [...e.times];
      const availableNow = anyTime || e.times.has(now) || (now === "day" && e.times.has("morning") && m.period === "morning");
      const state = e.owned ? "owned" : e.seen ? "seen" : "unseen";
      const name = e.seen || e.owned ? e.name : "???";
      const whenIcons = timed.map((t) => ({ morning: I.dawn, day: I.sun, night: I.moon }[t] || "")).join("");
      const lv = e.min != null ? (e.min === e.max ? `Lv ${e.min}` : `Lv ${e.min}–${e.max}`) : "";
      h += `<button class="tile ${state} ${availableNow ? "" : "off"}" data-wild="${esc(e.species)}">
        ${e.owned ? `<span class="ball">${I.ball}</span>` : ""}
        <span class="when">${whenIcons}</span>
        ${icoOf(e, name, e.owned ? "" : "shadow")}
        <span class="nm">${esc(name)}</span>
        <span class="meta num">${lv}${e.chance ? ` · ${e.chance}%` : ""}</span></button>`;
    }
    h += `</div>`;
  }
  return h;
}

/* ---------- Battle ---------- */
function fighterCard(b, compact) {
  const pct = b.own ? `${b.hp}/${b.maxhp}` : `${b.hpPct}%`;
  const tags = [bossChip(b), shadowChip(b), types(b), statusChip(b.status), statusChip(b.status2), stageChips(b.stages), (b.effects || []).map((e) => `<span class="chip">${esc(pretty(e))}</span>`).join(""),
    (b.otherEffects || []).length ? `<span class="chip">+${b.otherEffects.length} more</span>` : ""].join("");
  return `<button class="fighter ${b.own ? "own" : "foe"} ${b.shadow ? "is-shadow" : ""}" data-fighter="${b.index}">
    ${icoOf(b, b.speciesName)}
    <div class="top"><b>${esc(b.name)}</b><span class="lv">Lv${b.level}</span>${!b.own && b.owned ? `<span style="width:13px;height:13px;display:inline-block">${I.ball}</span>` : ""}<span class="pct num">${pct}</span></div>
    ${hpBar(b.hp, b.maxhp)}
    <div class="tags">${tags}</div></button>`;
}

// Compact card for double battles: name, HP, status, types; boosts/effects collapse to a count.
function miniCard(b, active) {
  const extra = Object.keys(b.stages || {}).length + (b.effects || []).length + (b.otherEffects || []).length;
  const pct = b.own ? `${b.hp}/${b.maxhp}` : `${b.hpPct}%`;
  return `<button class="mini ${b.own ? "own" : "foe"} ${active ? "active" : ""} ${b.shadow ? "is-shadow" : ""}" data-fighter="${b.index}">
    <div class="r1">${icoOf(b, b.speciesName)}<b>${esc(b.name)}</b><span class="lv">${b.level}</span></div>
    ${hpBar(b.hp, b.maxhp)}
    <div class="r2"><span class="pct num">${pct}</span>${b.boss ? `<span class="chip bosschip">${I.shield}${b.boss.shields || b.boss.bars || ""}</span>` : ""}${b.shadow ? `<span class="chip shadowchip">S</span>` : ""}${statusChip(b.status)}${statusChip(b.status2)}${extra ? `<span class="chip">+${extra}</span>` : ""}${active ? `<span class="chip choosing">choosing</span>` : ""}</div></button>`;
}
// Battle slots as they sit on screen: foes on top (3 left, 1 right), your side below (0 left, 2 right)
const SLOT_POS = { 3: "L", 1: "R", 0: "L", 2: "R" };
function fieldGrid(b, cardFn) {
  const at = (i) => b.battlers.find((x) => x.index === i);
  const cell = (i) => (at(i) ? cardFn(at(i)) : `<div class="mini empty-slot"></div>`);
  return `<div class="field2">${cell(3)}${cell(1)}${cell(0)}${cell(2)}</div>`;
}

// "Super effective" etc. against the foe(s) — what the move would do right now
function effWord(mv, foes) {
  if (mv.cat === "status") return "Status";
  const vs = (mv.vs || []).filter((v) => v.foe !== false && v.mult != null);
  if (!vs.length) return "";
  const w = (m) => (m === 0 ? "No effect" : m > 1 ? "Super effective" : m < 1 ? "Not very effective" : "Effective");
  if (vs.length === 1 || vs.every((v) => v.mult === vs[0].mult)) return w(vs[0].mult);
  return vs.map((v) => `${SLOT_POS[v.index] || ""} ${v.mult === 0 ? "✕" : v.mult > 1 ? "▲" : v.mult < 1 ? "▼" : "•"}`).join("  ");
}
function effClass(mv) {
  const vs = (mv.vs || []).filter((v) => v.foe !== false && v.mult != null);
  if (mv.cat === "status" || !vs.length) return "e-status";
  const best = Math.max(...vs.map((v) => v.mult));
  return best === 0 ? "e-none" : best > 1 ? "e-super" : best < 1 ? "e-weak" : "e-normal";
}

// Power change from field, ability, item, weather, stat stages… (▲×1.5)
function powTag(mv) {
  let extra = mv.fieldChange ? ` <b class="pw">⇄ ${esc(mv.fieldChange)}</b>` : "";
  if (mv.cat === "status") return (mv.fieldStatus ? ` <b class="pw up">▲ field</b>` : "") + extra;
  return powTagDmg(mv) + extra;
}
function powTagDmg(mv) {
  const p = mv.field === 0 ? 0 : mv.power != null ? mv.power : mv.field || 1;
  if (p === 1) return "";
  if (p === 0) return ` <b class="pw down">fails here</b>`;
  return ` <b class="pw ${p > 1 ? "up" : "down"}">${p > 1 ? "▲" : "▼"}×${p}</b>`;
}

function effBadges(mv, foes) {
  let h = "";
  if (mv.field === 0) h += `<i class="fx">fails</i>`;
  else if (mv.power != null && mv.power !== 1) h += `<i class="fx ${mv.power > 1 ? "up" : "down"}">${mv.power > 1 ? "▲" : "▼"}×${mv.power}</i>`;
  else if (mv.power == null && mv.field && mv.field !== 1) h += `<i class="fx">field ×${mv.field}</i>`;
  if (mv.fieldType) h += `<i class="fx">+${esc(mv.fieldType)}</i>`;
  if (mv.fieldStatus) h += `<i class="fx up">▲ field</i>`;
  if (mv.fieldChange) h += `<i class="fx">⇄ ${esc(mv.fieldChange)}</i>`;
  for (const v of mv.vs || []) {
    if (v.mult == null) continue;
    const label = v.mult === 0 ? "×0" : v.mult >= 2 ? "×" + v.mult : v.mult < 1 ? "×" + (v.mult === 0.5 ? "½" : v.mult === 0.25 ? "¼" : v.mult) : "";
    if (!label) continue;
    const cls = v.mult === 0 ? "imm" : v.mult > 1 ? "se" : "nve";
    if (v.foe === false) continue;     // ally effectiveness only matters in the target picker
    const who = foes.length > 1 ? SLOT_POS[v.index] + " " : "";
    h += `<i class="${cls}">${esc(who)}${label}</i>`;
  }
  return h;
}

function renderBattle() {
  const b = S.battle;
  const foes = b.battlers.filter((x) => !x.own);
  const own = b.battlers.filter((x) => x.own);
  let h = `<div class="bstrip">`;
  if (b.weather) h += `<button data-info="weather">${I.rain}${esc(b.weather.name || WEATHER[b.weather.id] || pretty(b.weather.id))}${b.weather.turns > 0 ? ` · ${b.weather.turns}` : ""}</button>`;
  if (b.field && b.field.isField && b.field.name) h += `<button class="fieldchip" data-info="field">${I.field}${esc(b.field.name)}${b.field.duration > 0 ? ` · ${b.field.duration}` : ""}</button>`;
  for (const g of b.global || []) h += `<button data-info="global">${esc(pretty(g.id))}${g.turns ? ` · ${g.turns}` : ""}</button>`;
  const SIDE_CHIPS = /^(Reflect|LightScreen|AuroraVeil|Tailwind|Safeguard|Mist|LuckyChant|Spikes|ToxicSpikes|StealthRock|StickyWeb|Steelsurge|Volcalith|AreniteWall|Rainbow|SeaOfFire|Swamp|CraftyShield|WideGuard|QuickGuard|MatBlock)$/;
  const sideTag = (s, who) => Object.entries(s || {}).filter(([k]) => b.sidesAll || SIDE_CHIPS.test(k)).map(([k, v]) => `<button data-info="sides">${I.shield}${who} ${esc(pretty(k))}${typeof v === "number" && v > 1 ? ` ${v}` : ""}</button>`).join("");
  h += sideTag(b.sides[0], "Your") + sideTag(b.sides[1], "Foe");
  h += `</div>`;

  // quick Poké Ball (wild battles): last ball you threw, or a ball you actually own
  const qb = b.balls && b.balls.quick;
  const ballBtn = !b.trainer && !b.noBag && qb ? `<button class="qball" data-ball="${esc(qb.id)}" data-hold="balls" aria-label="Throw ${esc(qb.name)}">
      ${qb.icon ? `<img src="${img(qb.icon)}" alt="" onerror="this.outerHTML=I.ball">` : I.ball}<span class="qn num">${qb.qty}</span></button>` : "";
  const last = (b.log || []).slice(-1)[0];
  const logBtn = last ? `<button class="logline" data-act="log"><span>${esc(last.text)}</span><span class="muted">Log</span></button>` : `<span class="logline spacer"></span>`;
  if (last || ballBtn) h += `<div class="logrow">${logBtn}${ballBtn}</div>`;
  if (ui.btab === "mon") return h + renderSwitch(b);
  if (ui.btab === "bag") return h + renderBag(true);

  const doubles = b.double || foes.length > 1 || own.length > 1;
  if (doubles) {
    h += fieldGrid(b, (x) => miniCard(x, x.own && x.index === b.activeIndex && (b.menu === "command" || b.menu === "fight")));
  } else {
    h += `<div class="foes-row">${foes.map((f) => fighterCard(f)).join("")}</div>`;
    const me = own.find((x) => x.index === b.activeIndex) || own[0];
    if (me) h += fighterCard(me);
  }
  if (b.moves && b.moves.length) {
    h += `<div class="moves">`;
    for (const mv of b.moves) {
      const nopp = mv.pp === 0;
      h += `<button class="move t-${esc(mv.type)} ${nopp ? "nopp" : ""} ${effClass(mv)}" data-move="${mv.slot}">
        <span class="ticon ${packIcon(mv.type) ? "img" : ""}">${typeIcon(mv.type)}</span>
        <span class="eff">${effBadges(mv, foes)}</span>
        <span class="mn">${esc(mv.name)}</span>
        <span class="meff">${esc(effWord(mv, foes))}${powTag(mv)}</span>
        <span class="ml">${esc(mv.typeName || mv.type)}${mv.baseType ? ` (was ${esc(mv.baseTypeName || mv.baseType)})` : ""} · ${mv.cat === "status" ? "Status" : (mv.pow || "—") + (mv.stab ? " STAB" : "")}<span class="pp num">${mv.pp}/${mv.maxpp}</span></span>
        <span class="ppbig num"><b>${mv.pp}</b>/${mv.maxpp}</span></button>`;
    }
    h += `</div>`;
    const sp = b.specials || {};
    const can = sp.mega ? "Mega Evolve" : sp.z ? "Z-Move" : sp.ultra ? "Ultra Burst" : null;
    if (can) h += `<div class="specials"><button data-act="special" aria-pressed="${ui.special}">${can}${ui.special ? " on" : ""}</button></div>`;
    const locked = battleLocked();
    h += `<div class="waiting">${locked ? "Waiting for the turn…" : b.menu === "command" || b.menu === "fight" ? "Tap a move to use it · long-press for details" : "Waiting for the battle…"}</div>`;
  }
  return h;
}

function renderSwitch(b) {
  let h = `<h2>Switch to</h2>`;
  for (const p of b.party || []) {
    const fainted = p.hp <= 0 && !p.egg;
    h += `<button class="row-btn prow ${p.inBattle ? "inbattle" : ""} ${fainted ? "fainted" : ""}" data-switch="${p.slot}" ${p.inBattle || fainted || p.egg ? "disabled" : ""}>
      ${icoOf(p, p.name)}
      <div class="grow"><div class="l1"><b>${esc(p.name)}</b>${statusChip(p.status)}<span class="num">Lv${p.level ?? ""} · ${p.hp ?? ""}/${p.maxhp ?? ""}</span></div>
      ${p.egg ? "" : hpBar(p.hp, p.maxhp)}<div>${types(p)}</div></div></button>`;
  }
  return h + `<p class="hint">Tap a Pokémon to switch it in. In-battle ones are outlined in green.</p>`;
}

/* ---------- Party ---------- */
function renderParty() {
  const party = S.party || [];
  if (!party.length) return `<div class="empty">Your party is empty.</div>`;
  let h = "";
  for (const p of party) {
    h += `<button class="row-btn prow ${p.hp <= 0 && !p.egg ? "fainted" : ""} ${p.shadow ? "is-shadow" : ""}" data-mon="${p.slot}">
      ${icoOf(p, p.name)}
      <div class="grow"><div class="l1"><b>${esc(p.name)}</b>${shadowChip(p)}${statusChip(p.status)}${p.item && p.item.icon ? `<img class="itemmark" src="${img(p.item.icon)}" alt="" onerror="this.remove()">` : ""}<span class="num">${p.egg ? "" : `Lv${p.level} · ${p.hp}/${p.maxhp}`}</span></div>
      ${p.egg ? "" : hpBar(p.hp, p.maxhp)}<div>${types(p)}</div></div></button>`;
  }
  return h + `<p class="hint">Tap a Pokémon for its summary, moves and held item.</p>`;
}

/* ---------- Bag ---------- */
function renderBag(inBattle) {
  let pockets = (S.bag || []).filter((p) => p.items.length);
  if (inBattle) pockets = pockets.map((p) => ({ ...p, items: p.items.filter((i) => i.battle) })).filter((p) => p.items.length);
  if (!pockets.length) return `<div class="empty">${inBattle ? "Nothing in your bag can be used in battle." : "Your bag is empty."}</div>`;
  if (!ui.pocket || !pockets.find((p) => p.pocket === ui.pocket)) ui.pocket = pockets[0].pocket;
  const cur = pockets.find((p) => p.pocket === ui.pocket);
  let h = `<div class="pockets">${pockets.map((p) => `<button data-pocket="${p.pocket}" aria-current="${p.pocket === ui.pocket}">${esc(p.name)}</button>`).join("")}</div>`;
  for (const it of cur.items) {
    const usable = inBattle ? it.battle : it.field;
    h += `<button class="row-btn irow ${usable ? "" : "nouse"}" data-item="${esc(it.id)}"><span class="iimg">${it.icon ? `<img src="${img(it.icon)}" alt="" onerror="this.remove()">` : ""}</span><b>${esc(it.name)}</b><span class="q num">×${it.qty}</span></button>`;
  }
  if (inBattle) h += `<button class="row-btn gamebag" data-bcmd="1">Open the game's bag on the top screen</button>`;
  return h;
}

/* ---------- Map ---------- */
function renderMap() {
  const mt = B.fileTime ? B.fileTime("map.json") : 1;
  if (!townmap || mt !== townTime) {
    const t = B.readFile("map.json");
    if (t) { try { townmap = JSON.parse(t); townTime = mt; } catch (e) {} }
  }
  if (!townmap) { send("req map"); return `<div class="empty">Loading the town map…</div>`; }
  const pl = townmap.player;
  const region = (pl && townmap.regions.find((r) => r.id === pl[0])) || townmap.regions[0];
  if (!region || !region.image) return `<div class="empty">The map image wasn't found in the game folder.</div>`;
  const sq = townmap.square || 16;
  const pts = townmap.points.filter((p) => p.fly && townmap.regions.find((r) => r.id === p.region && r.image === region.image));
  const off = region.offset ?? 8;   // where a square's centre sits inside the map image
  let dots = pts.map((p) => `<button class="mpt fly ${p.visited ? "" : "locked"}" style="left:${p.x * sq + off}px;top:${p.y * sq + off}px" data-fly="${p.x},${p.y},${p.region}" aria-label="${esc(p.name)}"></button>`).join("");
  if (pl) dots += `<span class="mpt me" style="left:${pl[1] * sq + off}px;top:${pl[2] * sq + off}px"></span>`;
  return `<div class="mapview"><div class="zoom"><span class="where">${esc(S.map ? S.map.name : "")} · tap a ring to fly</span><button data-zoom="-1">−</button><button data-zoom="1">+</button></div>
    <div class="mapbox" id="mapbox"><div class="mapinner" id="mapinner" style="transform:scale(${ui.mapZoom})"><img src="${img(region.image)}" alt="" onerror="this.closest('.mapbox').innerHTML='<div class=empty>Map image missing</div>'">${dots}</div></div></div>`;
}
function afterMap() {
  const box = $("#mapbox"), inner = $("#mapinner");
  if (!box || !inner || box.dataset.centered) return;
  const im = inner.querySelector("img");
  const center = () => {
    inner.style.width = im.naturalWidth + "px"; inner.style.height = im.naturalHeight + "px";
    const me = inner.querySelector(".me");
    if (me) { box.scrollLeft = me.offsetLeft * ui.mapZoom - box.clientWidth / 2; box.scrollTop = me.offsetTop * ui.mapZoom - box.clientHeight / 2; }
    box.dataset.centered = 1;
  };
  if (im && im.complete) center(); else if (im) im.onload = center;
}

/* ---------- Pokédex ---------- */
function loadDex() {
  const mt = B.fileTime ? B.fileTime("dex.json") : 1;
  if (!dex || mt !== dexTime) {
    const t = B.readFile("dex.json");
    if (t) { try { dex = JSON.parse(t); dexTime = mt; (dex.types || []).forEach((x) => (TYPE_NAMES[x.id] = x.name)); } catch (e) {} }
  }
  // ask the game for a fresh export when it's missing or our caught/seen counts are behind
  const p = S.player || {};
  const stale = dex && p.owned != null && (dex.species.filter((s) => s.owned).length !== p.owned || dex.species.filter((s) => s.seen).length !== p.seen);
  if ((!dex || stale) && Date.now() - lastDexReq > 5000) { lastDexReq = Date.now(); send("req dex"); }
}
function renderDex() {
  loadDex();
  if (!dex) return `<div class="empty">Opening the Pokédex…<br><span class="muted sm">The first time, the game can pause for a moment while it gathers every Pokémon.</span></div>`;
  // Same list as the game's own Pokédex: it stops at the last species you've seen
  const inDex = dex.lastSeen != null ? dex.species.filter((s) => s.dex > 0 && s.dex <= dex.lastSeen) : dex.species;
  let list = inDex.filter((s) => (ui.dexFilter === "all" || (ui.dexFilter === "seen" ? s.seen : s.owned)));
  if (ui.dexType) list = list.filter((s) => s.seen && s.types.includes(ui.dexType));
  const num = (v) => (typeof v === "number" ? v : null);
  const owned = num(dex.gameOwned) ?? dex.species.filter((s) => s.owned).length, seen = num(dex.gameSeen) ?? dex.species.filter((s) => s.seen).length;
  const allTypes = (dex.types || []).filter((t) => !["QMARKS", "SHADOW"].includes(t.id));
  let h = `<div class="pockets typefilter"><button data-dext="" aria-current="${!ui.dexType}">Any type</button>${allTypes.map((t) => `<button class="t-${esc(t.id)}" data-dext="${esc(t.id)}" aria-current="${ui.dexType === t.id}">${esc(t.name)}</button>`).join("")}</div>
    <div class="seg">${[["all", "All"], ["seen", `Seen ${seen}`], ["owned", `Caught ${owned}`]].map(([k, n]) => `<button data-dexf="${k}" aria-current="${ui.dexFilter === k}">${n}</button>`).join("")}</div>`;
  for (const s of list.slice(0, 400)) {
    h += `<button class="row-btn dexrow ${s.owned ? "owned" : ""}" data-dex="${esc(s.species)}"><span class="no num">${String(s.dex).padStart(3, "0")}</span>${icoOf(s, s.name, s.owned ? "" : "shadow")}<b>${esc(s.seen ? s.name : "???")}</b>${s.seen ? types(s) : ""}</button>`;
  }
  if (!list.length) h += `<div class="empty">Nothing here yet. Try another filter.</div>`;
  if (list.length > 400) h += `<p class="hint">Showing 400 of ${list.length}. Pick a type to narrow it down.</p>`;
  return h;
}

/* ---------- Save ---------- */
function renderSave() {
  const p = S.player || {};
  return `<div class="savecard"><div class="big">${esc(p.name)}</div>${S.game ? `<div class="muted">${esc(S.game.title)} ${esc(S.game.version || "")}</div>` : ""}
    <dl class="kv"><dt>Location</dt><dd>${esc(S.map ? S.map.name : "")}</dd><dt>Badges</dt><dd class="num">${p.badges}</dd><dt>Pokédex</dt><dd class="num">${p.owned ?? "?"} caught · ${p.seen ?? "?"} seen</dd><dt>Money</dt><dd class="num">$${(p.money || 0).toLocaleString()}</dd></dl>
    <button class="savebtn" data-act="save-ask">Save the game</button></div>
    ${(S.watch || []).length ? `<h2>Game info</h2><dl class="kv watch">${S.watch.map((w) => `<dt>${esc(w.label)}</dt><dd class="num">${w.value === true ? "Yes" : w.value === false ? "No" : esc(w.value ?? "—")}</dd>`).join("")}</dl>` : ""}
    <h2>Open in game</h2>
    <div class="quick"><button data-act="openparty">Party screen</button><button data-act="openbag">Bag screen</button><button data-act="opendex">Pokédex</button><button data-act="openmap">Town map</button></div>
    <p class="hint">These open the game's own screens on the top display.</p>`;
}

/* ---------------- sheets ---------------- */
function openSheet(s) { sheet = s; renderSheet(); }
function closeSheet() { sheet = null; $("#sheet-wrap").hidden = true; }
function head(iconHtml, title, sub) {
  return `<div class="sh-head">${iconHtml || ""}<div><h3>${title}</h3>${sub ? `<div>${sub}</div>` : ""}</div><button class="close" data-act="close" aria-label="Close">${I.close}</button></div>`;
}
function statTable(p) {
  const nat = p.nature || {};
  const map = { atk: "Atk", def: "Def", spa: "SpA", spd: "SpD", spe: "Spe" };
  let h = `<div class="stats">`;
  for (const k of ["hp", "atk", "def", "spa", "spd", "spe"]) {
    const v = (p.stats || {})[k] ?? 0, base = (p.base || {})[k] ?? 0;
    const cls = nat.up === map[k] && nat.up !== nat.down ? "up" : nat.down === map[k] && nat.up !== nat.down ? "down" : "";
    h += `<span class="lab ${cls}">${k === "hp" ? "HP" : map[k]}</span><span class="num">${v}</span><span class="bar"><i style="width:${Math.min(100, base / 1.6)}%"></i></span><span class="iv num">${p.ivs ? `${p.ivs[k]} / ${p.evs ? p.evs[k] : 0}` : base}</span>`;
  }
  if (!p.ivs) return h + `</div>`;
  return h + `</div><p class="hint">Bar = base stat. Right column = IV / EV.${nat.up && nat.up !== nat.down ? ` ${esc(nat.name)}: +${nat.up} −${nat.down}.` : ""}</p>`;
}

function renderSheet() {
  const wrap = $("#sheet-wrap"), el = $("#sheet");
  let h = "";
  const s = sheet;
  if (s.kind === "mon") {
    const p = (S.party || []).find((x) => x.slot === s.slot);
    if (!p) return closeSheet();
    const seg = s.seg || "summary";
    h = head(icoOf(p, p.name), esc(p.name) + (p.gender ? ` <span class="muted">${p.gender === "F" ? "♀" : "♂"}</span>` : ""), `${p.speciesName !== p.name ? esc(p.speciesName) + " · " : ""}Lv${p.level} ${types(p)}`);
    h += `<div class="seg">${[["summary", "Summary"], ["stats", "Stats"], ["moves", "Moves"]].map(([k, n]) => `<button data-seg="${k}" aria-current="${seg === k}">${n}</button>`).join("")}</div>`;
    if (seg === "summary") {
      h += hpBar(p.hp, p.maxhp) + `<dl class="kv"><dt>HP</dt><dd class="num">${p.hp}/${p.maxhp} ${statusChip(p.status)}</dd>
        ${p.shadow ? `<dt>Shadow</dt><dd>${heartGauge(p.shadow)} <span class="muted">heart gauge — empty it to purify</span></dd>` : ""}
        <dt>Ability</dt><dd>${esc(p.ability ? p.ability.name : "—")}</dd>
        <dt>Nature</dt><dd>${esc(p.nature ? p.nature.name : "—")}</dd>
        <dt>Item</dt><dd>${esc(p.item ? p.item.name : "None")}</dd>
        ${p.exp ? `<dt>Next Lv</dt><dd class="num">${Math.max(0, p.exp.need - p.exp.now)} exp</dd>` : ""}
        ${p.happiness != null ? `<dt>Friendship</dt><dd class="num">${p.happiness}</dd>` : ""}</dl>`;
      if (p.ability && p.ability.desc) h += `<p class="prose"><b>${esc(p.ability.name)}:</b> ${esc(p.ability.desc)}</p>`;
      if (p.item && p.item.desc) h += `<p class="prose"><b>${esc(p.item.name)}:</b> ${esc(p.item.desc)}</p>`;
      h += `<div class="actions"><button data-act="give">${p.item ? "Change item" : "Give item"}</button>${p.item ? `<button data-act="take">Take ${esc(p.item.name)}</button>` : ""}</div>`;
      h += `<div class="actions"><button data-act="mvup" ${p.slot === 0 ? "disabled" : ""}>Move up in party</button><button data-act="mvdown" ${p.slot >= S.party.length - 1 ? "disabled" : ""}>Move down</button></div>`;
    } else if (seg === "stats") {
      h += statTable(p);
    } else {
      h += `<div class="mlist">${p.moves.map((m) => `<button class="mrow t-${esc(m.type)} ${s.pick === m.slot ? "sel" : ""}" data-mslot="${m.slot}"><b>${esc(m.name)}</b><span class="num">${m.pp}/${m.maxpp} PP</span><span class="d">${esc(m.typeName || m.type)} · ${m.cat === "status" ? "Status" : `${pretty(m.cat)} · ${m.pow || "—"} pow`} · ${m.acc ? m.acc + "% acc" : "never misses"}${m.pri ? ` · priority ${m.pri > 0 ? "+" : ""}${m.pri}` : ""}<br>${esc(m.desc)}</span></button>`).join("")}</div>
        <p class="hint">${s.pick != null ? "Now tap the move to swap with." : "Tap two moves to swap their order."}</p>`;
    }
  } else if (s.kind === "give") {
    const p = (S.party || []).find((x) => x.slot === s.slot);
    const items = (S.bag || []).flatMap((pk) => pk.items.filter((i) => !i.important && !i.key && !i.mail).map((i) => ({ ...i, pocket: pk.name })));
    h = head("", `Give to ${esc(p ? p.name : "")}`);
    h += items.length ? items.map((it) => `<button class="row-btn irow" data-giveitem="${esc(it.id)}"><span class="iimg">${it.icon ? `<img src="${img(it.icon)}" alt="" onerror="this.remove()">` : ""}</span><b>${esc(it.name)}</b><span class="q num">×${it.qty}</span></button>`).join("") : `<div class="empty">No items that can be held.</div>`;
  } else if (s.kind === "item") {
    const it = (S.bag || []).flatMap((p) => p.items).find((i) => i.id === s.id);
    if (!it) return closeSheet();
    h = head(it.icon ? `<span class="iimg" style="width:40px"><img src="${img(it.icon)}" alt="" style="max-width:40px" onerror="this.remove()"></span>` : "", esc(it.name), `×${it.qty}`);
    const inB = S.mode === "battle" && S.battle;
    const kind = inB ? it.battle : it.field;
    const useBtn = kind ? `<button class="primary" data-act="useitem">${kind === "ball" ? "Throw" : "Use"}</button>` : "";
    const giveBtn = !inB && !it.important && !it.key && !it.mail ? `<button data-act="giveto">Give to…</button>` : "";
    h += `<p class="prose">${esc(it.desc)}</p>${useBtn || giveBtn ? `<div class="actions">${useBtn}${giveBtn}</div>` : ""}
      ${kind ? "" : `<p class="hint">${inB ? "This item can't be used in battle." : "This item can't be used from here."}</p>`}
      ${kind === "field" ? `<p class="hint">This item is used on the top screen.</p>` : ""}`;
  } else if (s.kind === "useon") {
    const inB = S.mode === "battle" && S.battle;
    const it = (S.bag || []).flatMap((p) => p.items).find((i) => i.id === s.id);
    const party = inB ? (S.battle.party || []) : (S.party || []);
    if (!it) return closeSheet();
    if (s.slot != null) {   // second step for PP items: pick the move
      const p = party.find((x) => x.slot === s.slot);
      h = head("", `${esc(it.name)} — which move?`);
      h += `<div class="mlist">${(p.moves || []).map((m) => `<button class="mrow t-${esc(m.type)}" data-useonmove="${m.slot}"><b>${esc(m.name)}</b><span class="num">${m.pp}/${m.maxpp} PP</span></button>`).join("")}</div>`;
    } else {
      h = head("", `Use ${esc(it.name)} on…`, `×${it.qty}`);
      h += party.filter((p) => !p.egg).map((p) => `<button class="row-btn prow ${p.hp <= 0 ? "fainted" : ""}" data-useon="${p.slot}">${icoOf(p, p.name)}
        <div class="grow"><div class="l1"><b>${esc(p.name)}</b>${statusChip(p.status)}<span class="num">Lv${p.level} · ${p.hp}/${p.maxhp}</span></div>${hpBar(p.hp, p.maxhp)}</div></button>`).join("");
    }
  } else if (s.kind === "balls") {
    const b = S.battle;
    const all = (b && b.balls && b.balls.all) || [];
    h = head("", "Throw which ball?");
    h += all.length ? all.map((x) => `<button class="row-btn irow" data-ball="${esc(x.id)}"><span class="iimg">${x.icon ? `<img src="${img(x.icon)}" alt="" onerror="this.remove()">` : I.ball}</span><b>${esc(x.name)}</b><span class="q num">×${x.qty}</span></button>`).join("")
      : `<div class="empty">You don't have any Poké Balls.</div>`;
    h += `<p class="hint">The ball button remembers the last ball you threw. If you run out, it switches to the ball you have most of.</p>`;
  } else if (s.kind === "giveto") {
    h = head("", "Give to which Pokémon?");
    h += (S.party || []).filter((p) => !p.egg).map((p) => `<button class="row-btn prow" data-givetarget="${p.slot}">${icoOf(p, p.name)}<div class="grow"><div class="l1"><b>${esc(p.name)}</b><span class="num">${p.item ? "holds " + esc(p.item.name) : "no item"}</span></div></div></button>`).join("");
  } else if (s.kind === "wild") {
    const e = findWild(s.id);
    if (!e) return closeSheet();
    const known = e.seen || e.owned;
    h = head(icoOf(e, e.name, e.owned ? "" : "shadow"), known ? esc(e.name) : "???", e.owned ? "Caught" : e.seen ? "Seen, not caught" : "Not seen yet");
    h += `<dl class="kv"><dt>Types</dt><dd>${known ? types(e) : "?"}</dd><dt>Levels</dt><dd class="num">${e.min}–${e.max}</dd><dt>Found by</dt><dd>${esc(e.where.join(", "))}</dd></dl>`;
  } else if (s.kind === "dex") {
    const d = dex && dex.species.find((x) => x.species === s.id);
    if (!d) return closeSheet();
    if (!d.seen) { h = head(icoOf(d, "?", "shadow"), "???", `No. ${String(d.dex).padStart(3, "0")}`) + `<div class="empty">You haven't seen this Pokémon yet.</div>`; }
    else {
      h = head(icoOf(d, d.name, d.owned ? "" : "shadow"), esc(d.name), `No. ${String(d.dex).padStart(3, "0")} · ${esc(d.kind)} Pokémon ${types(d)}`);
      if (d.entry) h += `<p class="prose">${esc(d.entry)}</p>`;
      h += statTable({ stats: d.base, base: d.base });
      h += `<dl class="kv"><dt>Abilities</dt><dd>${d.abilities.map((a) => esc(a.name)).join(", ")}</dd>${d.evos && d.evos.length ? `<dt>Evolves to</dt><dd>${d.evos.map(esc).join(", ")}</dd>` : ""}<dt>Found in</dt><dd>${d.where.length ? d.where.map(esc).join("<br>") : "Not found in the wild"}</dd></dl>`;
    }
  } else if (s.kind === "fighter") {
    const b = S.battle && S.battle.battlers.find((x) => x.index === s.index);
    if (!b) return closeSheet();
    h = head(icoOf(b, b.speciesName), esc(b.name), `${esc(b.speciesName)} · Lv${b.level} ${types(b)}`);
    if (b.boss || b.shadow) h += `<div class="bstrip">${bossChip(b)}${shadowChip(b)}</div>`;
    if (b.shadow && !b.own) h += `<p class="prose">A Shadow Pokémon. Choose <b>Call</b> to snap it out of hyper mode; catch it to purify it later.</p>`;
    h += `<dl class="kv"><dt>HP</dt><dd class="num">${b.own ? `${b.hp}/${b.maxhp}` : b.hpPct + "%"} ${statusChip(b.status)}</dd><dt>Ability</dt><dd>${esc(b.ability ? b.ability.name : "?")}</dd>${b.item ? `<dt>Item</dt><dd>${esc(b.item.name)}</dd>` : ""}<dt>Boosts</dt><dd>${stageChips(b.stages) || "None"}</dd><dt>Effects</dt><dd>${(b.effects || []).map(pretty).join(", ") || "None"}</dd>${(b.otherEffects || []).length ? `<dt>Also</dt><dd>${b.otherEffects.map(pretty).join(", ")}</dd>` : ""}</dl>`;
    if (b.ability && b.ability.desc) h += `<p class="prose">${esc(b.ability.desc)}</p>`;
    if (b.base) h += `<h2>Base stats</h2>` + statTable({ stats: b.base, base: b.base });
    if (b.own && b.stats) h += `<h2>Current stats</h2><dl class="kv">${Object.entries(b.stats).map(([k, v]) => `<dt>${STAGE_LAB[k]}</dt><dd class="num">${v}</dd>`).join("")}</dl>`;
  } else if (s.kind === "battleinfo") {
    const b = S.battle;
    if (!b) return closeSheet();
    h = head("", "Battlefield");
    if (b.weather) h += `<h2>${I.rain} Weather</h2><p class="prose">${esc(b.weather.name || WEATHER[b.weather.id] || pretty(b.weather.id))}${b.weather.turns > 0 ? ` — ${b.weather.turns} turns left` : " — lasts until replaced"}.</p>`;
    if (b.field && b.field.name) {
      const f = b.field.info || {};
      h += `<h2>${I.field} ${esc(b.field.name)}</h2>`;
      if (b.field.message) h += `<p class="prose">${esc(b.field.message)}</p>`;
      if (f.boosts && f.boosts.length) h += `<p class="prose"><b>Type boosts:</b> ${esc(f.boosts.join(", "))}</p>`;
      if (f.moves && f.moves.length) h += `<p class="prose"><b>Moves changed:</b> ${f.moves.map(esc).join("; ")}</p>`;
      if (f.changes && f.changes.length) h += `<p class="prose"><b>Field changes:</b> ${f.changes.map(esc).join("; ")}</p>`;
      if (f.typeAdds && f.typeAdds.length) h += `<p class="prose"><b>Moves gain a type:</b> ${f.typeAdds.map(esc).join("; ")}</p>`;
      if (f.accuracy && f.accuracy.length) h += `<p class="prose"><b>Accuracy:</b> ${f.accuracy.map(esc).join("; ")}</p>`;
      if (b.field.under) h += `<p class="prose">Temporary — ${b.field.duration} turns left, then back to ${esc(b.field.under)}.</p>`;
      if (f.mimicry || f.naturePower) h += `<p class="prose">${f.mimicry ? `Mimicry → ${esc(f.mimicry)}. ` : ""}${f.naturePower ? `Nature Power → ${esc(f.naturePower)}.` : ""}</p>`;
    }
    if ((b.global || []).length) h += `<h2>Whole field</h2><p class="prose">${b.global.map((g) => esc(pretty(g.id)) + (g.turns ? ` (${g.turns})` : "")).join(", ")}</p>`;
    for (const [i, who] of [[0, "Your side"], [1, "Foe's side"]]) {
      const e = Object.entries(b.sides[i] || {}).filter(([k]) => !/(Fainted|Count|Counter|Moves|Used|Turn)$/.test(k));
      if (e.length) h += `<h2>${I.shield} ${who}</h2><p class="prose">${e.map(([k, v]) => esc(pretty(k)) + (typeof v === "number" && v > 1 ? ` ${v}` : "")).join(", ")}</p>`;
    }
  } else if (s.kind === "move") {
    const mv = S.battle && S.battle.moves.find((m) => m.slot === s.slot);
    if (!mv) return closeSheet();
    h = head("", esc(mv.name), `${typeChip(mv.type, mv.typeName)} ${pretty(mv.cat)}`);
    h += `<dl class="kv"><dt>Power</dt><dd class="num">${mv.pow || "—"}</dd><dt>Accuracy</dt><dd class="num">${mv.fieldAcc ? `${mv.fieldAcc}% on this field` : mv.acc ? mv.acc + "%" : "—"}</dd>${mv.baseType ? `<dt>Type</dt><dd>${esc(mv.typeName || mv.type)} here — normally ${esc(mv.baseTypeName || mv.baseType)}${mv.typeWhy ? ` (${esc(mv.typeWhy)})` : ""}</dd>` : ""}${mv.fieldType ? `<dt>Field</dt><dd>Also ${esc(mv.fieldType)}-type here</dd>` : ""}${mv.fieldChange ? `<dt>Field</dt><dd>Changes the field to ${esc(mv.fieldChange)} — that hit gets ×1.3</dd>` : ""}${mv.fieldBuilds ? `<dt>Field</dt><dd>Counts toward changing the field</dd>` : ""}${mv.fieldStatus ? `<dt>Field</dt><dd>Stronger effect on this field</dd>` : ""}${(mv.boosts || []).length ? `<dt>Boosts</dt><dd>${mv.boosts.map((x) => `${esc(x.label)} ×${x.mult}`).join(", ")}${mv.boosts.length > 1 ? ` → ×${mv.power}` : ""}</dd>` : ""}<dt>PP</dt><dd class="num">${mv.pp}/${mv.maxpp}</dd>${mv.pri ? `<dt>Priority</dt><dd>${mv.pri}</dd>` : ""}</dl>${mv.fieldMsg ? `<p class="prose"><i>“${esc(mv.fieldMsg)}”</i></p>` : ""}<p class="prose">${esc(mv.desc)}</p>
      <div class="actions"><button class="primary" data-move="${mv.slot}">Use ${esc(mv.name)}</button></div>`;
  } else if (s.kind === "target" || s.kind === "gametarget") {
    const b = S.battle;
    if (!b) return closeSheet();
    const mv = s.kind === "target" ? b.moves.find((m) => m.slot === s.slot) : null;
    const valid = s.kind === "target" ? (mv ? mv.pick : []) : (b.targeting ? b.targeting.valid : []);
    if (!valid || (s.kind === "gametarget" && !b.targeting)) return closeSheet();
    h = head("", mv ? `${esc(mv.name)} — pick a target` : "Pick a target", mv ? `${typeChip(mv.type, mv.typeName)} ${mv.cat === "status" ? "Status" : mv.pow + " power"}` : "");
    const card = (x) => {
      const ok = valid.includes(x.index);
      const v = mv && (mv.vs || []).find((q) => q.index === x.index);
      let eff = "";
      if (v && v.mult != null) eff = v.mult === 0 ? `<i class="imm">no effect</i>` : v.mult > 1 ? `<i class="se">×${v.mult}</i>` : v.mult < 1 ? `<i class="nve">×${v.mult === 0.5 ? "½" : v.mult === 0.25 ? "¼" : v.mult}</i>` : "";
      const who = x.own ? (x.index === (mv ? b.activeIndex : b.targeting.for) ? "You" : "Ally") : "Foe";
      const attr = s.kind === "target" ? `data-move="${s.slot}" data-target="${x.index}"` : `data-gametarget="${x.index}"`;
      return `<button class="tgt ${x.own ? "own" : "foe"}" ${attr} ${ok ? "" : "disabled"}>
        <span class="who">${who}</span>${icoOf(x, x.speciesName)}<b>${esc(x.name)}</b>${hpBar(x.hp, x.maxhp)}<span class="eff">${eff}</span></button>`;
    };
    h += fieldGrid(b, card).replace('class="field2"', 'class="field2 pick"');
    h += `<p class="hint">Foes on top, your side below — laid out like the battlefield.</p>`;
  } else if (s.kind === "log") {
    const b = S.battle;
    if (!b) return closeSheet();
    h = head("", "Battle log") + `<ol class="blog">${(b.log || []).slice().reverse().map((l) => `<li>${esc(l.text)}</li>`).join("")}</ol>
      <p class="hint">Everything the battle has said this fight, newest first — including mechanics special to this game.</p>`;
  } else if (s.kind === "plugin") {
    h = head("", esc(s.title || "")) + (s.html || "");
  } else if (s.kind === "settings") {
    const skins = listSkins();
    h = head("", "Panel settings");
    h += `<h2>Skin</h2>` + skins.map((k) => `<button class="row-btn skinrow" data-skin="${esc(k.id)}" aria-pressed="${settings.skin === k.id}"><span class="radio"></span><span class="grow"><b>${esc(k.name)}</b><span class="muted"> ${k.author ? "by " + esc(k.author) : ""}${k.builtin ? "" : " · installed"}</span>${k.description ? `<br><span class="muted sm">${esc(k.description)}</span>` : ""}</span></button>`).join("");
    const gk = gameKey();
    if (gk) h += `<p class="hint">Skin and type icons are remembered for each game — this one is saved for <b>${esc(gk)}</b>.</p>`;
    h += `<p class="hint">Add skins by copying a skin folder into <b>PokeRPGLink/skins/</b> on your device storage.</p>`;
    const packs = typePacks();
    h += `<h2>Type icons</h2><div class="seg">${[["auto", "Match skin"], ["builtin", "Built-in"], ...packs.map((p) => [p.id, p.name])].map(([v, n]) => `<button data-typepack="${esc(v)}" aria-current="${(settings.typePack || "auto") === v}">${esc(n)}</button>`).join("")}</div>
      <p class="hint">Icon packs go in <b>PokeRPGLink/typeicons/&lt;pack&gt;/</b> — one PNG per type (FIRE.png, WATER.png…).</p>`;
    h += `<h2>Size</h2><div class="seg">${[[0.9, "Small"], [1, "Normal"], [1.15, "Large"]].map(([v, n]) => `<button data-scale="${v}" aria-current="${(settings.scale || 1) === v}">${n}</button>`).join("")}</div>`;
    h += `<h2>Skin animations &amp; sounds</h2><div class="seg"><button data-effects="1" aria-current="${settings.effects !== false}">On</button><button data-effects="0" aria-current="${settings.effects === false}">Off</button></div>`;
    h += `<h2>Volume</h2><div class="seg">${[[0.4, "Quiet"], [0.7, "Medium"], [1, "Loud"]].map(([v, n]) => `<button data-volume="${v}" aria-current="${(settings.volume ?? 1) === v}">${n}</button>`).join("")}</div>`;
    h += `<h2>Dim when idle</h2><div class="seg"><button data-dimidle="1" aria-current="${!!settings.dimIdle}">On</button><button data-dimidle="0" aria-current="${!settings.dimIdle}">Off</button></div>
      <p class="hint">Dims the panel slightly after 15 seconds without a touch, to protect the OLED screen. Still easy to read; any touch brings it back.</p>`;
    h += `<h2>Vibration</h2><div class="seg"><button data-haptics="1" aria-current="${settings.haptics !== false}">On</button><button data-haptics="0" aria-current="${settings.haptics === false}">Off</button></div>`;
    if (S && !S._stale) {
      const di = S.diag || {};
      let iconMsg = "no Pokémon in your party yet";
      if ((S.party || []).length) iconMsg = !di.icon ? "the game didn't give an icon (see PokeRPGLink/log.txt in the game folder)" : img(di.icon).startsWith("data:") ? "working" : "can't read " + di.icon;
      h += `<h2>About</h2><p class="hint">Mod version ${esc(S.v || "?")} · ${esc((S.game && S.game.title) || "")}<br>Pokémon icons: ${esc(iconMsg)}${di.jobs ? ` · drawing ${di.jobs} more in the background` : ""}</p>`;
    }
    if (B.openSetup) {
      const { rts } = launchInfo();
      h += `<h2>Game &amp; setup</h2><div class="actions">${rts.length ? `<button data-act="play" data-pkg="${esc(rts[0].id)}">Open ${esc(rts[0].label)} on top</button>` : ""}<button data-act="setup">PokeRPGLink setup</button></div>`;
      h += `<p class="hint byline">PokeRPGLink · by Leymo</p>`;
    }
  } else if (s.kind === "confirm") {
    h = head("", esc(s.title)) + (s.text ? `<p class="prose">${esc(s.text)}</p>` : "") + `<div class="actions"><button data-act="close">Cancel</button><button class="primary" data-confirm="1">${esc(s.ok)}</button></div>`;
  }
  el.innerHTML = h;
  wrap.hidden = false;
}

function findWild(id) {
  const out = { where: [] };
  let found = null;
  for (const g of (S.map && S.map.encounters) || []) for (const e of g.list) if (e.species === id) {
    found = found || { ...e, min: e.min, max: e.max };
    found.min = Math.min(found.min, e.min); found.max = Math.max(found.max, e.max);
    out.where.push(`${KIND[g.kind] || pretty(g.kind)}${g.time !== "any" ? " (" + g.time + ")" : ""}`);
  }
  return found && { ...found, where: [...new Set(out.where)] };
}

/* ---------------- virtual pad ---------------- */
function renderPad() {
  $("#pad").innerHTML = `
    <span></span><button data-btn="UP">${I.up}</button><span></span><span></span><button class="ab b" data-btn="B">B</button><button class="ab a" data-btn="A">A</button>
    <button data-btn="LEFT">${I.left}</button><span></span><button data-btn="RIGHT">${I.right}</button><span></span><button data-btn="X">X</button><button data-btn="Y">Y</button>
    <span></span><button data-btn="DOWN">${I.down}</button><span></span><span></span><button data-btn="L">L</button><button data-btn="R">R</button>`;
}

/* ---------------- events ---------------- */
let pressTimer = null, longFired = false;
document.addEventListener("pointerdown", (ev) => {
  const mv = ev.target.closest("[data-move]");
  longFired = false;
  if (mv && !$("#sheet-wrap").contains(mv)) {
    pressTimer = setTimeout(() => { longFired = true; openSheet({ kind: "move", slot: +mv.dataset.move }); }, 450);
  }
  const hold = ev.target.closest("[data-hold]");
  if (hold && !mv) pressTimer = setTimeout(() => { longFired = true; openSheet({ kind: hold.dataset.hold }); }, 450);
});
document.addEventListener("pointerup", () => clearTimeout(pressTimer));
document.addEventListener("pointercancel", () => clearTimeout(pressTimer));

document.addEventListener("click", (ev) => {
  const t = ev.target.closest("button, #sheet-scrim");
  if (!t) return;
  const d = t.dataset;
  if (t.id === "sheet-scrim") return closeSheet();
  if (d.tab) { ui.tab = d.tab; closeSheet(); return render(true); }
  if (d.plugbar) { const b = PLUG.barButtons.find((x) => x.id === d.plugbar); try { b && b.onClick && b.onClick(); } catch (e) {} return; }
  if (d.pluginClick && PLUG.clicks && PLUG.clicks[d.pluginClick]) { try { PLUG.clicks[d.pluginClick](t, S); } catch (e) {} return; }
  if (d.skin) { if (settings.skin !== d.skin) { settings.skin = d.skin; rememberLook(); saveSettings(); location.reload(); } return; }
  if (d.scale) { settings.scale = +d.scale; saveSettings(); applySettings(); return renderSheet(); }
  if (d.dimidle) { settings.dimIdle = d.dimidle === "1"; saveSettings(); wake(); return renderSheet(); }
  if (d.typepack) { settings.typePack = d.typepack; rememberLook(); saveSettings(); render(true); return renderSheet(); }
  if (d.effects) { settings.effects = d.effects === "1"; saveSettings(); return renderSheet(); }
  if (d.volume) { settings.volume = +d.volume; saveSettings(); beep(880, 60); return renderSheet(); }
  if (d.haptics) { settings.haptics = d.haptics === "1"; saveSettings(); return renderSheet(); }
  if (d.bt) { ui.btab = d.bt; return render(true); }
  if (d.bcmd) { send("bcmd " + d.bcmd); return; }
  if (d.move != null) {
    if (longFired) return;
    const mv = S.battle && S.battle.moves.find((m) => m.slot === +d.move);
    const sp = (sheet && sheet.kind === "target" ? sheet.special : ui.special) ? " special" : "";
    // single-target move in a double battle: ask who to hit before sending
    if (mv && mv.pick && mv.pick.length > 1 && !d.target) return openSheet({ kind: "target", slot: mv.slot, special: ui.special });
    send("bmove " + d.move + sp + (d.target ? " t=" + d.target : ""));
    ui.special = false; closeSheet(); return render(true);
  }
  if (d.gametarget != null) { send("btarget " + d.gametarget); return closeSheet(); }
  if (d.switch != null) { send("bswitch " + d.switch); ui.btab = "fight"; return render(true); }
  if (d.fighter != null) return openSheet({ kind: "fighter", index: +d.fighter });
  if (d.info) return openSheet({ kind: "battleinfo" });
  if (d.mon != null) return openSheet({ kind: "mon", slot: +d.mon, seg: "summary" });
  if (d.seg) { sheet.seg = d.seg; sheet.pick = null; return renderSheet(); }
  if (d.mslot != null) {
    const i = +d.mslot;
    if (sheet.pick == null) sheet.pick = i;
    else { if (sheet.pick !== i) send(`swapmove ${sheet.slot} ${sheet.pick} ${i}`); sheet.pick = null; }
    return renderSheet();
  }
  if (d.pocket) { ui.pocket = +d.pocket; return render(true); }
  if (d.item) return openSheet({ kind: "item", id: d.item });
  if (d.giveitem) { send(`giveitem ${sheet.slot} ${d.giveitem}`); return openSheet({ kind: "mon", slot: sheet.slot, seg: "summary" }); }
  if (d.givetarget != null) { send(`giveitem ${d.givetarget} ${sheet.id}`); return closeSheet(); }
  if (d.wild) return openSheet({ kind: "wild", id: d.wild });
  if (d.useon != null) {
    const inB = S.mode === "battle" && S.battle;
    if (sheet.needsMove) { sheet.slot = +d.useon; return renderSheet(); }
    if (inB) { send(`bitem ${sheet.id} ${d.useon}`); ui.btab = "fight"; closeSheet(); return render(true); }
    send(`useon ${sheet.id} ${d.useon}`); return closeSheet();
  }
  if (d.useonmove != null) {
    const inB = S.mode === "battle" && S.battle;
    send(`${inB ? "bitem" : "useon"} ${sheet.id} ${sheet.slot} ${d.useonmove}`);
    if (inB) ui.btab = "fight";
    closeSheet(); return render(true);
  }
  if (d.ball) {
    if (longFired) return;
    send(`bball ${d.ball}`); closeSheet(); return;
  }
  if (d.dex) return openSheet({ kind: "dex", id: d.dex });
  if (d.dexf) { ui.dexFilter = d.dexf; return render(true); }
  if (d.dext != null) { ui.dexType = d.dext || null; return render(true); }
  if (d.zoom) { ui.mapZoom = Math.max(0.5, Math.min(3, ui.mapZoom + 0.5 * +d.zoom)); const inner = $("#mapinner"); if (inner) inner.style.transform = `scale(${ui.mapZoom})`; return; }
  if (d.fly) {
    const [x, y, r] = d.fly.split(",").map(Number);
    const p = townmap.points.find((q) => q.x === x && q.y === y && q.region === r);
    if (!p.visited) return openSheet({ kind: "confirm", title: p.name, text: "You haven't been here yet, so you can't fly there.", ok: "OK", cmd: null });
    return openSheet({ kind: "confirm", title: `Fly to ${p.name}?`, text: p.poi ? p.poi : "", ok: "Fly", cmd: `fly ${x} ${y} ${r}` });
  }
  if (d.btn) { send("btn " + d.btn); return; }
  if (d.confirm) { if (sheet.cmd) send(sheet.cmd); return closeSheet(); }
  switch (d.act) {
    case "close": return closeSheet();
    case "settings": return openSheet({ kind: "settings" });
    case "play": try { B.play(d.pkg || ""); } catch (e) {} return;
    case "setup": try { B.openSetup(); } catch (e) {} return;
    case "log": return openSheet({ kind: "log" });
    case "hide": try { B.setCollapsed(true); } catch (e) {} return;
    case "pad": { const p = $("#pad"); p.hidden = !p.hidden; if (!p.hidden) renderPad(); return; }
    case "special": ui.special = !ui.special; return render(true);
    case "save-ask":
      if (S.features && S.features.saveAsks) { send("save"); return PokeRPGLink.toast("Confirm on the top screen"); }
      return openSheet({ kind: "confirm", title: "Save the game?", text: "This overwrites your current save, the same as saving from the menu.", ok: "Save", cmd: "save" });
    case "openparty": case "openbag": case "opendex": case "openmap": return send(d.act);
    case "give": return openSheet({ kind: "give", slot: sheet.slot });
    case "take": send(`takeitem ${sheet.slot}`); return;
    case "mvup": send(`swapparty ${sheet.slot} ${sheet.slot - 1}`); sheet.slot -= 1; return;
    case "mvdown": send(`swapparty ${sheet.slot} ${sheet.slot + 1}`); sheet.slot += 1; return;
    case "useitem": {
      const inB = S.mode === "battle" && S.battle;
      const it = (S.bag || []).flatMap((p) => p.items).find((i) => i.id === sheet.id);
      const kind = it && (inB ? it.battle : it.field);
      if (kind === "pokemon" || kind === "move") return openSheet({ kind: "useon", id: sheet.id, needsMove: kind === "move" });
      if (inB) { send(`bitem ${sheet.id}`); ui.btab = "fight"; closeSheet(); return render(true); }
      send(`useitem ${sheet.id}`); return closeSheet();
    }
    case "giveto": return openSheet({ kind: "giveto", id: sheet.id });
  }
});
/* ---------------- boot ---------------- */
try { root = B.root(); } catch (e) { root = ""; }
loadSettings();
applySettings();
wake();
loadSkin();
{ const h = location.hash.slice(1).split("&")[0].split("-"); if (["area", "party", "bag", "map", "dex", "save"].includes(h[1] || h[0])) ui.tab = h[1] || h[0]; if ((h[0] === "battle" || h[0] === "double") && ["mon", "bag"].includes(h[1])) ui.btab = h[1]; }
render(true);
send("ping");
setInterval(poll, 150);
poll();
