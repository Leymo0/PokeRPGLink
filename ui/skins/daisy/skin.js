// Daisy — bouncy buttons and a crisp click on every tap.
// Shared by Daisy, Daisy White and Daisy OLED (they load this file).
(function () {
  const T = window.PokeRPGLink;
  // sounds live next to this script, whichever variant loaded it
  const here = (document.currentScript && document.currentScript.src) || "";
  const base = here.replace(/[^/]*$/, "");
  const CLICK = base + "click.mp3", TICK = base + "tick.mp3";
  const BUTTONS = ".move, #tabs button, .tile, .row-btn, .tgt, .qball, .bstrip button, .logline, .savebtn, .actions button, .seg button, .pockets button, .mini, .fighter, .padbtn, #pad button, .close";

  let pressed = null;
  document.addEventListener("pointerdown", (ev) => {
    const el = ev.target.closest(BUTTONS);
    if (!el || el.disabled) return;
    pressed = el;
    T.animate(el, [{ transform: "scale(1)" }, { transform: "scale(.93)" }], { duration: 90, fill: "forwards", easing: "ease-out" });
    const small = el.matches("#tabs:not(.battle) button, .seg button, .pockets button, .padbtn");
    T.playSound(small ? TICK : CLICK, { volume: small ? 0.5 : 0.75 });
  }, true);

  const release = () => {
    if (!pressed) return;
    const el = pressed;
    pressed = null;
    // spring back with a little overshoot
    T.animate(el, [{ transform: "scale(.93)" }, { transform: "scale(1.06)" }, { transform: "scale(.98)" }, { transform: "scale(1)" }],
      { duration: 320, easing: "cubic-bezier(.3,1.6,.5,1)" });
  };
  document.addEventListener("pointerup", release, true);
  document.addEventListener("pointercancel", release, true);

  // the battle menu pops in when it's your turn
  T.on("menu", (e) => {
    if (e.menu !== "command") return;
    T.animate(".moves .move", [{ transform: "translateY(8px) scale(.96)", opacity: .4 }, { transform: "none", opacity: 1 }],
      { duration: 260, easing: "cubic-bezier(.3,1.5,.5,1)" });
  });
})();
