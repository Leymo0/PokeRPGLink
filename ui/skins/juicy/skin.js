// Juicy Battles — an example of reacting to game events with animation and sound.
// Every sound here is synthesised with PokeRPGLink.beep(), so the skin ships no audio files.
// To use your own sounds instead, put them in this folder and call:
//   PokeRPGLink.playSound(PokeRPGLink.skinFile("hit.ogg"))
(function () {
  const T = window.PokeRPGLink;
  const card = (i) => T.find("battler", i);

  // floating text over a battler card ("-34%", "Atk ↑")
  function float(i, text, color) {
    const el = card(i);
    if (!el) return;
    const r = el.getBoundingClientRect();
    const f = document.createElement("div");
    f.className = "juicy-float";
    f.textContent = text;
    f.style.color = color;
    f.style.left = r.left + r.width / 2 - 30 + "px";
    f.style.top = r.top + 6 + "px";
    document.body.appendChild(f);
    T.animate(f, [{ transform: "translateY(0)", opacity: 1 }, { transform: "translateY(-28px)", opacity: 0 }], 900);
    setTimeout(() => f.remove(), 950);
  }

  T.on("damage", (e) => {
    const big = e.fraction > 0.4;
    T.animate(card(e.index), [
      { transform: "translateX(0)" }, { transform: `translateX(${big ? -9 : -5}px)` },
      { transform: `translateX(${big ? 9 : 5}px)` }, { transform: "translateX(0)" }], big ? 320 : 220);
    T.animate(card(e.index), [{ filter: "brightness(2.2) saturate(0)" }, { filter: "none" }], 260);
    T.beep(big ? 140 : 220, 90, "square", 0.09);
    T.beep(big ? 90 : 160, 120, "square", 0.07, 70);
    float(e.index, e.own ? `-${e.from - e.to}` : `-${e.from - e.to}%`, "#ff8a7a");
  });

  T.on("heal", (e) => {
    T.animate(card(e.index), [{ boxShadow: "0 0 0 0 #5bd08a" }, { boxShadow: "0 0 0 6px #5bd08a00" }], 500);
    [523, 659, 784].forEach((f, n) => T.beep(f, 90, "triangle", 0.06, n * 70));
    float(e.index, `+${e.to - e.from}${e.own ? "" : "%"}`, "#8ff0b0");
  });

  T.on("faint", () => {
    [392, 330, 262, 196].forEach((f, n) => T.beep(f, 140, "sawtooth", 0.05, n * 110));
  });

  T.on("statChange", (e) => {
    const up = e.change > 0;
    float(e.index, `${e.stat} ${up ? "↑" : "↓"}${Math.abs(e.change) > 1 ? Math.abs(e.change) : ""}`, up ? "#9ff0b8" : "#ffb0a8");
    (up ? [440, 554, 659] : [659, 554, 440]).forEach((f, n) => T.beep(f, 60, "square", 0.04, n * 45));
  });

  T.on("shieldBreak", (e) => {
    T.animate(card(e.index), [{ transform: "scale(1)" }, { transform: "scale(1.06) rotate(-1deg)" }, { transform: "scale(1)" }], 300);
    T.beep(1200, 50, "square", 0.08); T.beep(300, 200, "sawtooth", 0.06, 40);
  });

  T.on("caught", () => {
    [523, 659, 784, 1047].forEach((f, n) => T.beep(f, 120, "square", 0.06, n * 100));
    T.toast("Gotcha! New Pokémon caught", "ok");
  });

  T.on("levelUp", (e) => {
    [392, 523, 659, 784, 1047].forEach((f, n) => T.beep(f, 80, "triangle", 0.06, n * 70));
    T.toast(`${e.name} grew to Lv ${e.level}!`, "ok");
  });

  // a soft tick when the battle is waiting for your choice
  T.on("menu", (e) => { if (e.menu === "command") T.beep(988, 40, "sine", 0.05); });

  // tiny clicks on touch
  document.addEventListener("pointerdown", (ev) => {
    if (ev.target.closest(".move, #tabs button, .tgt")) T.beep(1400, 18, "square", 0.025);
  });
})();
