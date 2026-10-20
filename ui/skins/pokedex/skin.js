// Pokédex — springy buttons, quiet digital blips, and a few lively touches:
// FIGHT goes "psh!",
// the FIGHT burst pops when it's your turn, panels bob in when a battle starts,
// and caught Pokémon get a little jingle.
(function () {
  const T = window.PokeRPGLink;
  const still = () => !T.settings || T.settings().effects === false || matchMedia("(prefers-reduced-motion: reduce)").matches;
  const sync = () => document.body.classList.toggle("x-still", still());
  sync();
  T.on("render", sync);

  /* ---- sounds: everything is kept quiet ---- */
  const VOL = 0.4;                                   // whole skin, on top of the app's volume
  const blip = (f, ms, v, at) => T.beep(f, ms, "square", v * VOL, at || 0);
  let ctx = null;
  function psh(loud) {                               // soft burst of filtered noise, not a beep
    const s = T.settings ? T.settings() : {};
    if (s.effects === false) return;
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      const len = Math.floor(ctx.sampleRate * 0.22);
      const buf = ctx.createBuffer(1, len, ctx.sampleRate), d = buf.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.2);
      const src = ctx.createBufferSource(); src.buffer = buf;
      const bp = ctx.createBiquadFilter(); bp.type = "bandpass"; bp.Q.value = 0.8;
      const t = ctx.currentTime;
      bp.frequency.setValueAtTime(3200, t); bp.frequency.exponentialRampToValueAtTime(900, t + 0.2);
      const g = ctx.createGain(); g.gain.setValueAtTime((loud || 0.09) * VOL * (s.volume ?? 1), t);
      src.connect(bp).connect(g).connect(ctx.destination); src.start(t);
    } catch (e) {}
  }

  const go = () => window.PokeRPGPress({
    squash: .9, overshoot: 1.08,
    sound(el, small) {
      if (el.matches("#tabs.battle .b-fight")) return psh(0.1);
      if (small) return blip(2093, 18, 0.03);
      blip(1568, 22, 0.03); blip(2349, 30, 0.025, 28);  // tiny two-step digital chirp
    },
  });
  if (window.PokeRPGPress) go();
  else {
    const s = document.createElement("script");
    s.src = (document.currentScript.src || "").replace(/[^/]*\/[^/]*$/, "") + "_shared/press.js";
    s.onload = go;
    document.body.appendChild(s);
  }

  /* ---- menu page: a quick press-and-pop you can actually see, then the next page opens ---- */
  let pass = null;
  window.addEventListener("click", (ev) => {
    const el = ev.target.closest && ev.target.closest("#tabs.battle button[data-bt]");
    if (!el || el.disabled || el === pass || document.body.dataset.view !== "b-menu" || still()) return;
    ev.stopPropagation(); ev.preventDefault();
    T.animate(el, [{ transform: "scale(.9)" }, { transform: "scale(1.08)" }, { transform: "scale(1)" }], { duration: 160, easing: "ease-out" });
    const bt = el.dataset.bt;                        // the bar may re-render meanwhile: find the button again
    setTimeout(() => {
      const now = document.querySelector(`#tabs.battle button[data-bt="${bt}"]`);
      if (!now || now.disabled) return;
      pass = now; now.click(); pass = null;
    }, 160);
  }, true);

  T.on("menu", (e) => {
    if (still() || e.menu !== "command") return;
    T.animate("#tabs.battle .b-fight", [{ transform: "scale(.6) rotate(-12deg)" }, { transform: "scale(1.12) rotate(4deg)" }, { transform: "none" }], { duration: 420, easing: "cubic-bezier(.3,1.5,.5,1)" });
  });
  T.on("battleStart", () => {
    if (still()) return;
    T.animate(".fighter, .mini", [{ transform: "translateY(-14px)", opacity: 0 }, { transform: "none", opacity: 1 }], { duration: 380, easing: "cubic-bezier(.3,1.4,.5,1)" });
  });
  T.on("caught", () => {
    if (still()) return;
    blip(1047, 60, 0.035); blip(1319, 60, 0.035, 70); blip(1568, 120, 0.035, 140);
  });
})();
