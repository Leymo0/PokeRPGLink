// Super Retro — square-wave chiptune blips.
(function () {
  const go = () => window.PokeRPGPress({
    squash: .92, overshoot: 1.04, springMs: 240,
    sound(el, small) {
      const T = window.PokeRPGLink;
      if (small) return T.beep(1568, 30, "square", 0.04);
      T.beep(988, 40, "square", 0.05); T.beep(1319, 60, "square", 0.05, 40);
    },
  });
  if (window.PokeRPGPress) return go();
  const s = document.createElement("script");
  s.src = document.currentScript.src.replace(/[^/]*\/[^/]*$/, "") + "_shared/press.js";
  s.onload = go;
  document.body.appendChild(s);
})();
