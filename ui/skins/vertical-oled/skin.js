// Same sounds and animations as daisy-oled.
(function () {
  const s = document.createElement("script");
  s.src = (document.currentScript.src || "").replace(/[^/]*\/[^/]*$/, "") + "daisy-oled/skin.js";
  document.body.appendChild(s);
})();
