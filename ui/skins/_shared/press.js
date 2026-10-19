// Shared by built-in skins: springy press animation + a sound on every tap.
// Use from a skin.js:  PokeRPGPress({ sound(el, small) { … }, squash: .93, overshoot: 1.06 })
(function () {
  if (window.PokeRPGPress) return;
  const BUTTONS = ".move, #tabs button, .tile, .row-btn, .tgt, .qball, .bstrip button, .logline, .savebtn, .actions button, .seg button, .pockets button, .mini, .fighter, .padbtn, #pad button, .close";
  window.PokeRPGPress = function (opt = {}) {
    const T = window.PokeRPGLink;
    const squash = opt.squash || 0.93, over = opt.overshoot || 1.06;
    let pressed = null;
    document.addEventListener("pointerdown", (ev) => {
      const el = ev.target.closest(BUTTONS);
      if (!el || el.disabled) return;
      pressed = el;
      T.animate(el, [{ transform: "scale(1)" }, { transform: `scale(${squash})` }], { duration: 90, fill: "forwards", easing: "ease-out" });
      if (opt.sound) opt.sound(el, el.matches("#tabs:not(.battle) button, .seg button, .pockets button, .padbtn"));
    }, true);
    const release = () => {
      if (!pressed) return;
      const el = pressed;
      pressed = null;
      T.animate(el, [{ transform: `scale(${squash})` }, { transform: `scale(${over})` }, { transform: "scale(.99)" }, { transform: "scale(1)" }],
        { duration: opt.springMs || 320, easing: "cubic-bezier(.3,1.6,.5,1)" });
    };
    document.addEventListener("pointerup", release, true);
    document.addEventListener("pointercancel", release, true);
    T.on("menu", (e) => {
      if (e.menu !== "command") return;
      T.animate(".moves .move", [{ transform: "translateY(8px) scale(.96)", opacity: .4 }, { transform: "none", opacity: 1 }],
        { duration: 260, easing: "cubic-bezier(.3,1.5,.5,1)" });
    });
  };
  // load helper for skin.js files: PokeRPGPress.load(document.currentScript, cb)
  window.PokeRPGPressLoad = function (cb) { cb(); };
})();
