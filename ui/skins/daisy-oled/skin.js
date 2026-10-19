// Uses the shared Daisy script (sounds + bounce) from the Daisy folder.
(function () {
  const s = document.createElement("script");
  s.src = (document.currentScript.src || "").replace(/[^/]*\/[^/]*$/, "") + "daisy/skin.js";
  document.body.appendChild(s);
})();
