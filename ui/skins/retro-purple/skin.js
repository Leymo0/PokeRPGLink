// Retro Purple — synthy blips.
(function () {
  const go = () => window.PokeRPGPress({
    squash: .94, overshoot: 1.05,
    sound(el, small) {
      const T = window.PokeRPGLink;
      if (small) return T.beep(1320, 35, "sine", 0.05);
      T.beep(660, 45, "sawtooth", 0.035); T.beep(990, 60, "sine", 0.06, 30);
    },
  });
  if (window.PokeRPGPress) return go();
  const s = document.createElement("script");
  s.src = document.currentScript.src.replace(/[^/]*\/[^/]*$/, "") + "_shared/press.js";
  s.onload = go;
  document.body.appendChild(s);
})();
