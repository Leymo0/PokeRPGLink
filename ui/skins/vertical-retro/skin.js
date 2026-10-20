// Same sounds and animations as retro-snes.
(function () {
  const s = document.createElement("script");
  s.src = (document.currentScript.src || "").replace(/[^/]*\/[^/]*$/, "") + "retro-snes/skin.js";
  document.body.appendChild(s);
})();
