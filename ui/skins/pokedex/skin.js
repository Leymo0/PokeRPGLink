// Pokédex — springy buttons, chirpy handheld sounds, and a few lively touches:
// the FIGHT burst pops when it's your turn, panels bob in when a battle starts,
// and caught Pokémon get a little sparkle.
(function () {
  const T = window.PokeRPGLink;
  const still = () => !T.settings || T.settings().effects === false || matchMedia("(prefers-reduced-motion: reduce)").matches;
  const sync = () => document.body.classList.toggle("x-still", still());
  sync();
  T.on("render", sync);

  const go = () => window.PokeRPGPress({
    squash: .9, overshoot: 1.08,
    sound(el, small) {
      if (small) return T.beep(1568, 30, "square", 0.035);
      if (el.matches(".b-fight")) { T.beep(523, 50, "square", 0.05); T.beep(784, 50, "square", 0.05, 45); T.beep(1047, 90, "square", 0.05, 90); return; }
      T.beep(988, 40, "square", 0.045); T.beep(1319, 60, "square", 0.04, 35);
    },
  });
  if (window.PokeRPGPress) go();
  else {
    const s = document.createElement("script");
    s.src = (document.currentScript.src || "").replace(/[^/]*\/[^/]*$/, "") + "_shared/press.js";
    s.onload = go;
    document.body.appendChild(s);
  }

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
    T.beep(1047, 70, "square", 0.05); T.beep(1319, 70, "square", 0.05, 80); T.beep(1568, 140, "square", 0.05, 160);
  });
})();
