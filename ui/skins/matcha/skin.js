// Matcha — soft wooden knocks.
(function () {
  const go = () => window.PokeRPGPress({
    squash: .95, overshoot: 1.03, springMs: 280,
    sound(el, small) {
      const T = window.PokeRPGLink;
      T.beep(small ? 520 : 330, 55, "triangle", 0.09);
      T.beep(small ? 780 : 495, 40, "sine", 0.04, 12);
    },
  });
  if (window.PokeRPGPress) return go();
  const s = document.createElement("script");
  s.src = document.currentScript.src.replace(/[^/]*\/[^/]*$/, "") + "_shared/press.js";
  s.onload = go;
  document.body.appendChild(s);
})();
