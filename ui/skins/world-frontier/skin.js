// World Frontier — tints the panel with the facility you're in, adds a streak ribbon
// in battle, and celebrates streaks, symbols, the Ace and inverse battles.
// Every sound is synthesised with PokeRPGLink.beep(), so the skin ships no audio files.
(function () {
  const T = window.PokeRPGLink;
  const esc = T.ui.esc;

  // ---- facility colour: body[data-facility] drives --fc in skin.css
  const facilityOf = (s) => (s && ((s.battle && s.battle.frontier && s.battle.frontier.id) || (s.frontier && s.frontier.facility && s.frontier.facility.id))) || "";
  const tint = () => {
    const id = facilityOf(T.state);
    if (document.body.dataset.facility !== id) document.body.dataset.facility = id;
  };
  T.on("state", tint);
  T.on("render", tint);
  tint();
  // the streak ribbon sits in the chip row (in place of the facility chip) so the moves keep their room
  T.on("battle", () => {
    const r = document.querySelector("#main > .wf-ribbon"), strip = document.querySelector("#main .bstrip");
    if (r && strip) strip.prepend(r);
  });

  // ---- sounds: little brass-ish fanfares from triangle + square blips
  const C5 = 523, E5 = 659, G5 = 784, C6 = 1047, A4 = 440, D5 = 587;
  const fanfare = (notes, step = 110, vol = 0.07) => notes.forEach((f, i) => { T.beep(f, step * 1.4, "triangle", vol, i * step); T.beep(f / 2, step, "square", vol * 0.25, i * step); });
  const streakUp = () => fanfare([C5, E5, G5, C6], 95);
  const symbolGet = () => { fanfare([G5, G5, G5, E5, G5, C6], 120, 0.08); };
  const aceSting = () => { [110, 98, 82].forEach((f, i) => T.beep(f, 260, "sawtooth", 0.06, i * 240)); fanfare([A4, D5, A4 * 2], 160, 0.06); };
  const flipSound = () => { for (let i = 0; i < 6; i++) T.beep(400 + (i % 2 ? 300 : 0), 40, "square", 0.04, i * 45); };

  // ---- banner overlay (one at a time: a streak and a symbol often arrive together)
  const queue = [];
  let showing = false;
  function banner(big, small, cls = "") {
    queue.push([big, small, cls]);
    if (!showing) next();
  }
  function next() {
    const job = queue.shift();
    if (!job) { showing = false; return; }
    showing = true;
    const [big, small, cls] = job;
    const el = document.createElement("div");
    el.className = "wf-banner " + cls;
    el.innerHTML = `<span class="big">${esc(big)}</span>${small ? `<span class="small">${esc(small)}</span>` : ""}`;
    document.body.appendChild(el);
    T.animate(el, [{ transform: "translate(-50%,-50%) scale(.6)", opacity: 0 }, { transform: "translate(-50%,-50%) scale(1.06)", opacity: 1, offset: .25 },
      { transform: "translate(-50%,-50%) scale(1)", opacity: 1, offset: .8 }, { transform: "translate(-50%,-56%) scale(1)", opacity: 0 }], { duration: 1700, easing: "ease-out" });
    setTimeout(() => { el.remove(); next(); }, T.settings().effects === false ? 1200 : 1750);
  }

  // ---- watch the run: streak up, symbol earned
  const snap = (f) => (f ? { streak: f.streak, symbols: (f.symbols || []).slice() } : null);
  let prev = snap(T.state && T.state.frontier);   // the panel may already have a state when the skin loads
  T.on("state", (s) => {
    const f = s && s.frontier;
    if (prev && f) {
      if (f.streak != null && prev.streak != null && f.streak > prev.streak) {
        streakUp();
        const ace = f.facility && f.facility.ace;
        banner(`Streak ${f.streak}`, ace && f.streak + 1 === ace ? "Next up: the Ace!" : ace && f.streak < ace ? `${ace - f.streak - 1} more to the Ace` : "Keep it going!");
      }
      if ((f.symbols || []).length > (prev.symbols || []).length) {
        const got = (f.symbols || []).find((x) => !(prev.symbols || []).includes(x));
        banner("Symbol earned!", got || "");
        setTimeout(symbolGet, 1750);
      }
    }
    prev = snap(f);
  });

  // ---- battle start: Ace and inverse announcements
  T.on("battleStart", () => {
    const b = T.state && T.state.battle;
    if (!b) return;
    if (b.frontier && b.frontier.ace) { aceSting(); banner("ACE BATTLE", `${b.frontier.name} · battle ${b.frontier.battle}`); }
    else if (b.inverse) {
      flipSound(); banner("Inverse battle", "Type matchups are flipped", "inverse");
      setTimeout(() => T.animate(".moves .move", [{ transform: "rotateX(0)" }, { transform: "rotateX(90deg)" }, { transform: "rotateX(0)" }], { duration: 520, easing: "ease-in-out" }), 200);
    }
  });

  // ---- streak ribbon above the battle
  T.addSection("battle", (s) => {
    const f = s.frontier, b = s.battle;
    if (!f || !b || !b.frontier) return "";
    const ace = f.facility && f.facility.ace;
    const n = b.frontier.battle;
    if (b.frontier.ace) return `<div class="wf-ribbon ace">${T.ui.icons.trophy || ""}<span>The Ace — win for the symbol</span><b class="num">#${esc(n)}</b></div>`;
    const pct = ace && n ? Math.min(100, Math.round((100 * (n - 1)) / ace)) : null;
    return `<div class="wf-ribbon"><span>Battle <b class="num">${esc(n ?? "?")}</b></span>${f.streak != null ? `<span>Streak <b class="num">${esc(f.streak)}</b></span>` : ""}${pct != null && n < ace ? `<span class="bar"><i style="width:${pct}%"></i></span><span class="muted">Ace in ${ace - n}</span>` : ""}</div>`;
  });

  // ---- springy buttons with a soft gold "tick"
  const go = () => window.PokeRPGPress({
    squash: .95, overshoot: 1.04,
    sound(el, small) {
      if (small) return T.beep(1568, 30, "sine", 0.04);
      T.beep(784, 40, "triangle", 0.05); T.beep(1175, 55, "sine", 0.04, 25);
    },
  });
  if (window.PokeRPGPress) return go();
  const sc = document.createElement("script");
  sc.src = document.currentScript.src.replace(/[^/]*\/[^/]*$/, "") + "_shared/press.js";
  sc.onload = go;
  document.body.appendChild(sc);
})();
