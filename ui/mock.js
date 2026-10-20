/* Browser preview only: fakes the Android bridge with sample Rejuvenation data.
 * Ignored inside the app (the real window.PokeRPGBridge exists there).
 * Open index.html#battle, #map, #party, #dex ... to preview screens. */
(function () {
  if (window.PokeRPGBridge) return;
  const mon = (slot, species, name, lv, hp, maxhp, types, typeNames, extra = {}) => ({
    slot, species, speciesName: extra.speciesName || name, name, level: lv, hp, maxhp, types, typeNames, status: extra.status || null,
    ability: extra.ability || { name: "Static", desc: "Contact with the Pokémon may cause paralysis." },
    nature: extra.nature || { name: "Timid", up: "Spe", down: "Atk" }, item: extra.item || null,
    stats: { hp: maxhp, atk: 31, def: 30, spa: 44, spd: 36, spe: 58 }, base: { hp: 35, atk: 55, def: 40, spa: 50, spd: 50, spe: 90 },
    ivs: { hp: 31, atk: 12, def: 25, spa: 31, spd: 20, spe: 31 }, evs: { hp: 0, atk: 0, def: 0, spa: 40, spd: 0, spe: 44 },
    moves: extra.moves || [
      { slot: 0, name: "Thunderbolt", type: "ELECTRIC", typeName: "Electric", cat: "special", pow: 90, acc: 100, pp: 12, maxpp: 15, desc: "A strong electric blast. May paralyze the target." },
      { slot: 1, name: "Quick Attack", type: "NORMAL", typeName: "Normal", cat: "physical", pow: 40, acc: 100, pp: 30, maxpp: 30, pri: 1, desc: "Always strikes first." },
      { slot: 2, name: "Thunder Wave", type: "ELECTRIC", typeName: "Electric", cat: "status", pow: 0, acc: 90, pp: 18, maxpp: 20, desc: "Paralyzes the target." },
      { slot: 3, name: "Iron Tail", type: "STEEL", typeName: "Steel", cat: "physical", pow: 100, acc: 75, pp: 15, maxpp: 15, desc: "May lower the target's Defense." }],
    exp: { now: 340, need: 600 }, happiness: 140, gender: extra.gender || "M", icon: null,
  });
  const party = [
    mon(0, "PIKACHU", "Volt", 24, 41, 58, ["ELECTRIC"], ["Electric"], { item: { name: "Light Ball", desc: "Doubles Pikachu's Attack and Sp. Atk." }, speciesName: "Pikachu" }),
    mon(1, "LITWICK", "Litwick", 22, 12, 49, ["GHOST", "FIRE"], ["Ghost", "Fire"], { status: "BURN", ability: { name: "Flash Fire", desc: "Powers up Fire moves if hit by one." } }),
    mon(2, "NOIBAT", "Noibat", 21, 50, 50, ["FLYING", "DRAGON"], ["Flying", "Dragon"], { item: { name: "Oran Berry", desc: "Restores 10 HP." } }),
    mon(3, "SKRELP", "Skrelp", 20, 0, 47, ["POISON", "WATER"], ["Poison", "Water"]),
  ];
  const enc = (sp, name, chance, min, max, seen, owned, types) => ({ species: sp, name, chance, min, max, seen, owned, types, icon: null });
  const mapState = {
    v: "1.0.0", mode: "map", toasts: [], game: { title: "Pokemon Rejuvenation", version: "14.0.24", family: "rejuvenation" }, player: { name: "Leymo", money: 24310, badges: 3, seen: 61, owned: 38 },
    map: { id: 25, name: "Goldenwood Forest", period: "night", outdoor: true, pos: [0, 22, 26],
      encounters: [
        { kind: "grass", time: "any", list: [enc("SEWADDLE", "Sewaddle", 25, 18, 21, true, true, ["BUG", "GRASS"]), enc("PIDOVE", "Pidove", 20, 18, 20, true, false, ["NORMAL", "FLYING"]), enc("FOONGUS", "Foongus", 15, 19, 21, false, false, ["GRASS", "POISON"])] },
        { kind: "grass", time: "day", list: [enc("COMBEE", "Combee", 10, 18, 20, true, false, ["BUG", "FLYING"]), enc("PETILIL", "Petilil", 5, 19, 19, false, false, ["GRASS"])] },
        { kind: "grass", time: "night", list: [enc("HOOTHOOT", "Hoothoot", 20, 18, 21, true, true, ["NORMAL", "FLYING"]), enc("SPINARAK", "Spinarak", 10, 18, 20, false, false, ["BUG", "POISON"]), enc("ZORUA", "Zorua", 2, 20, 20, false, false, ["DARK"])] },
        { kind: "surf", time: "any", list: [enc("BASCULIN", "Basculin", 60, 20, 25, true, true, ["WATER"]), enc("SURSKIT", "Surskit", 40, 20, 22, true, false, ["BUG", "WATER"])] },
        { kind: "superrod", time: "any", list: [enc("FEEBAS", "Feebas", 5, 25, 25, false, false, ["WATER"])] },
      ] },
    party,
    bag: [
      { pocket: 1, name: "Items", items: [{ id: "REPEL", name: "Repel", qty: 4, desc: "Prevents weak wild Pokémon from appearing for 100 steps." }, { id: "ESCAPEROPE", name: "Escape Rope", qty: 1, desc: "Escape from caves." }] },
      { pocket: 2, name: "Medicine", items: [{ id: "POTION", name: "Potion", qty: 6, desc: "Restores 20 HP." }, { id: "SUPERPOTION", name: "Super Potion", qty: 2, desc: "Restores 60 HP." }, { id: "BURNHEAL", name: "Burn Heal", qty: 1, desc: "Heals a burn." }, { id: "REVIVE", name: "Revive", qty: 2, desc: "Revives a fainted Pokémon with half HP." }] },
      { pocket: 3, name: "Poké Balls", items: [{ id: "POKEBALL", name: "Poké Ball", qty: 11, desc: "A device for catching wild Pokémon." }, { id: "DUSKBALL", name: "Dusk Ball", qty: 3, desc: "Works well at night and in caves." }] },
      { pocket: 8, name: "Key Items", items: [{ id: "BICYCLE", name: "Bicycle", qty: 1, desc: "A folding bike.", key: true, important: true }] },
    ],
    battle: null,
  };
  // item kinds for the panel bag
  const K = { REPEL: [null, "field"], ESCAPEROPE: [null, "field"], POTION: ["pokemon", "pokemon"], SUPERPOTION: ["pokemon", "pokemon"], BURNHEAL: ["pokemon", "pokemon"], REVIVE: ["pokemon", "pokemon"], POKEBALL: ["ball", null], DUSKBALL: ["ball", null], BICYCLE: [null, "field"] };
  mapState.bag.forEach((p) => p.items.forEach((i) => { [i.battle, i.field] = K[i.id] || [null, null]; }));
  mapState.bag.splice(2, 0, { pocket: 7, name: "Battle Items", items: [{ id: "XATTACK", name: "X Attack", qty: 2, desc: "Raises Attack.", battle: "battler", field: null }] });
  const battleState = JSON.parse(JSON.stringify(mapState));
  battleState.mode = "battle";
  battleState.battle = {
    turn: 2, menu: "command", activeIndex: 0, double: false, trainer: false, canRun: true,
    weather: { id: "RAINDANCE", turns: 3 },
    field: { id: "ELECTERRAIN", name: "Electric Terrain", message: "The field is hyper-charged!", isField: true, duration: 0,
      info: { boosts: ["Electric ×1.5"], moves: ["Explosion, Self-Destruct, Hurricane, Surf ×1.5", "Magnet Bomb ×2.0"], changes: ["Mud Sport, Tectonic Rage → no field"], mimicry: "Electric", naturePower: "Thunderbolt" } },
    global: [], sides: [{ Reflect: 4 }, { Spikes: 1 }],
    battlers: [
      { index: 1, own: false, species: "GRIMER", name: "Grimer", speciesName: "Grimer", level: 23, hp: 31, maxhp: 62, hpPct: 50, status: "PARALYSIS", types: ["POISON"], typeNames: ["Poison"], ability: { name: "Stench", desc: "May cause the target to flinch." }, stages: { atk: 1 }, effects: ["Confusion"], owned: true, base: { hp: 80, atk: 80, def: 50, spa: 40, spd: 50, spe: 25 } },
      { index: 0, own: true, species: "PIKACHU", name: "Volt", speciesName: "Pikachu", level: 24, hp: 41, maxhp: 58, status: null, types: ["ELECTRIC"], typeNames: ["Electric"], ability: { name: "Static", desc: "Contact may paralyze." }, stages: { spe: -1 }, effects: [], item: { name: "Light Ball" }, stats: { atk: 31, def: 30, spa: 44, spd: 36, spe: 58 } },
    ],
    moves: [
      { slot: 0, name: "Thunderbolt", type: "ELECTRIC", typeName: "Electric", cat: "special", pow: 90, acc: 100, pp: 12, maxpp: 15, stab: true, field: 1.5, boosts: [{ label: "Electric Terrain", mult: 1.5 }], power: 1.5, fieldMsg: "The electric current is strong!", vs: [{ index: 1, mult: 1 }], desc: "A strong electric blast." },
      { slot: 1, name: "Quick Attack", type: "ELECTRIC", typeName: "Electric", baseType: "NORMAL", baseTypeName: "Normal", typeWhy: "Galvanize", cat: "physical", pow: 40, acc: 100, pp: 30, maxpp: 30, pri: 1, field: 1.5, boosts: [{ label: "Electric Terrain", mult: 1.5 }, { label: "Galvanize", mult: 1.3 }], power: 1.95, vs: [{ index: 1, mult: 1 }], desc: "Always strikes first." },
      { slot: 2, name: "Thunder Wave", type: "ELECTRIC", typeName: "Electric", cat: "status", pow: 0, acc: 90, pp: 18, maxpp: 20, field: 1, fieldStatus: true, vs: [{ index: 1, mult: null }], desc: "Paralyzes the target." },
      { slot: 3, name: "Iron Tail", type: "STEEL", typeName: "Steel", cat: "physical", pow: 100, acc: 75, pp: 0, maxpp: 15, field: 1, fieldChange: "Factory", vs: [{ index: 1, mult: 0 }], desc: "May lower Defense." },
    ],
    specials: { mega: false }, party: party.map((p, i) => ({ ...p, inBattle: i === 0 })),
    balls: { quick: { id: "DUSKBALL", name: "Dusk Ball", qty: 3, icon: null, last: true }, all: [{ id: "DUSKBALL", name: "Dusk Ball", qty: 3 }, { id: "POKEBALL", name: "Poké Ball", qty: 11 }] },
  };
  const dex = { types: ["NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE", "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC", "BUG", "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY"].map((t) => ({ id: t, name: t[0] + t.slice(1).toLowerCase() })),
    species: [
      { species: "BULBASAUR", name: "Bulbasaur", dex: 1, types: ["GRASS", "POISON"], seen: false, owned: false, base: {}, abilities: [], where: [] },
      { species: "PIKACHU", name: "Pikachu", dex: 25, types: ["ELECTRIC"], seen: true, owned: true, kind: "Mouse", entry: "It stores electricity in its cheeks.", base: { hp: 35, atk: 55, def: 40, spa: 50, spd: 50, spe: 90 }, abilities: [{ name: "Static" }, { name: "Lightning Rod" }], evos: ["Raichu"], where: ["Gearen Park · grass"] },
      { species: "GRIMER", name: "Grimer", dex: 88, types: ["POISON"], seen: true, owned: false, kind: "Sludge", entry: "Made of hardened sludge.", base: { hp: 80, atk: 80, def: 50, spa: 40, spd: 50, spe: 25 }, abilities: [{ name: "Stench" }], evos: ["Muk"], where: ["Abandoned Sewers · cave"] },
      { species: "HOOTHOOT", name: "Hoothoot", dex: 163, types: ["NORMAL", "FLYING"], seen: true, owned: true, kind: "Owl", entry: "It hoots at the same time every day.", base: { hp: 60, atk: 30, def: 30, spa: 36, spd: 56, spe: 50 }, abilities: [{ name: "Insomnia" }], evos: ["Noctowl"], where: ["Goldenwood Forest · grass (night)"] },
      { species: "SEWADDLE", name: "Sewaddle", dex: 540, types: ["BUG", "GRASS"], seen: true, owned: true, kind: "Sewing", entry: "Makes clothes from leaves.", base: { hp: 45, atk: 53, def: 70, spa: 40, spd: 60, spe: 42 }, abilities: [{ name: "Swarm" }], evos: ["Swadloon"], where: ["Goldenwood Forest · grass"] },
      { species: "ZORUA", name: "Zorua", dex: 570, types: ["DARK"], seen: false, owned: false, base: {}, abilities: [], where: [] },
      { species: "LITWICK", name: "Litwick", dex: 607, types: ["GHOST", "FIRE"], seen: true, owned: true, kind: "Candle", entry: "Its flame burns life energy.", base: { hp: 50, atk: 30, def: 55, spa: 65, spd: 55, spe: 20 }, abilities: [{ name: "Flash Fire" }], evos: ["Lampent"], where: [] },
    ] };
  const mapSvg = "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="480" height="352"><rect width="480" height="352" fill="#2c5d8a"/><path d="M60 60 L300 40 L420 120 L380 300 L120 320 L40 200 Z" fill="#6aa35c"/><path d="M150 120 L260 110 L300 200 L180 240 Z" fill="#8bbf6e"/></svg>');
  const townmap = { square: 16, style: "scroll", player: [0, 22, 14],
    regions: [{ id: 0, name: "Aevium", image: mapSvg, offset: 8 }],
    points: [{ x: 22, y: 14, name: "Goldenwood Forest", region: 0, fly: false, visited: false },
             { x: 10, y: 8, name: "Gearen City", poi: "Gearen Laboratory", region: 0, fly: true, visited: true },
             { x: 16, y: 18, name: "Akuwa Town", region: 0, fly: true, visited: true },
             { x: 7, y: 15, name: "Terajuma Island", region: 0, fly: true, visited: false }] };
  const dbl = JSON.parse(JSON.stringify(battleState));
  dbl.battle.double = true;
  dbl.battle.field = null; dbl.battle.sides = [{}, { StealthRock: 1 }];
  dbl.battle.battlers = [
    { index: 1, own: false, name: "Grimer", speciesName: "Grimer", level: 23, hp: 31, maxhp: 62, hpPct: 50, status: "PARALYSIS", types: ["POISON"], typeNames: ["Poison"], ability: { name: "Stench" }, stages: { atk: 1 }, effects: ["Confusion"] },
    { index: 3, own: false, name: "Pidove", speciesName: "Pidove", level: 22, hp: 50, maxhp: 50, hpPct: 100, types: ["NORMAL", "FLYING"], typeNames: ["Normal", "Flying"], ability: { name: "Big Pecks" }, stages: {}, effects: [] },
    { index: 0, own: true, name: "Volt", speciesName: "Pikachu", level: 24, hp: 41, maxhp: 58, types: ["ELECTRIC"], typeNames: ["Electric"], ability: { name: "Static" }, stages: { spe: -1 }, effects: [] },
    { index: 2, own: true, name: "Litwick", speciesName: "Litwick", level: 22, hp: 12, maxhp: 49, status: "BURN", types: ["GHOST", "FIRE"], typeNames: ["Ghost", "Fire"], ability: { name: "Flash Fire" }, stages: {}, effects: [] },
  ];
  dbl.battle.moves = dbl.battle.moves.map((m) => ({ ...m, field: 1,
    pick: m.slot === 2 || m.slot === 3 || m.slot === 1 ? [1, 2, 3] : null,
    vs: [{ index: 1, foe: true, mult: m.cat === "status" ? null : m.type === "STEEL" ? 0 : 1 }, { index: 3, foe: true, mult: m.cat === "status" ? null : m.type === "ELECTRIC" ? 2 : 1 }, { index: 2, foe: false, mult: m.cat === "status" ? null : m.type === "ELECTRIC" ? 1 : 1 }] }));
  dbl.battle.moves[0].pick = null; dbl.battle.moves[0].target = "AllNonUsers";
  battleState.battle.log = [{ id: 1, text: "Leader Kaya sent out Grimer!" }, { id: 2, text: "The field is hyper-charged!" }, { id: 3, text: "Grimer's Stench made the air foul!" }];
  battleState.battle.battlers[0].otherEffects = ["MagicCoat", "Rage"];
  mapState.watch = [{ label: "Karma", value: 12 }, { label: "Rift Energy", value: 3 }, { label: "Got the Bicycle", value: true }];
  const shadow = JSON.parse(JSON.stringify(battleState));
  shadow.battle.commands = ["Fight", "Bag", "Pokémon", "Call"];
  shadow.battle.trainer = true;
  Object.assign(shadow.battle.battlers[0], { name: "Grimer", shadow: { stage: 4, max: 5 }, boss: { shields: 2 } });
  shadow.battle.moves[1].fieldType = "Electric";
  shadow.battle.field.info.typeAdds = ["Surf, Muddy Water also Electric"];
  const scenes = { map: mapState, battle: battleState, double: dbl, shadow };
  let served = null;
  window.PokeRPGBridge = {
    readState() { const h0 = location.hash.slice(1).split(/[-&]/)[0]; if (h0 === "offline") return ""; const k = scenes[h0] ? h0 : "map"; if (served === k) return ""; served = k; return JSON.stringify(scenes[k]); },
    readFile(n) { return n === "dex.json" ? JSON.stringify(dex) : n === "map.json" ? JSON.stringify(townmap) : ""; },
    fileTime() { return Date.now() - 500; },
    send(l) { console.log("send:", l); },
    root() { return ""; },
    haptic() {},
    listSkins() {
      return JSON.stringify([{ id: "default", name: "Default", author: "Leymo", builtin: true },
        { id: "classic-ds", name: "Classic DS", author: "Leymo", description: "Light, Gen 4 touch-screen look.", builtin: true, css: "skins/classic-ds/skin.css" },
        { id: "oled-black", name: "OLED Black", author: "Leymo", description: "True black background.", builtin: true, css: "skins/oled-black/skin.css" },
        { id: "catch-tracker", name: "Catch Tracker", author: "Leymo", description: "Example plugin.", builtin: true, css: "skins/catch-tracker/skin.css", js: "skins/catch-tracker/skin.js" },
        { id: "daisy", name: "Daisy", author: "Leymo", builtin: true, typeIcons: ["White icons"], css: "skins/daisy/skin.css", js: "skins/daisy/skin.js" },
        { id: "daisy-white", name: "Daisy White", author: "Leymo", builtin: true, typeIcons: ["White icons"], css: "skins/daisy-white/skin.css", js: "skins/daisy-white/skin.js" },
        { id: "daisy-oled", name: "Daisy OLED", author: "Leymo", builtin: true, typeIcons: ["Dark icons"], css: "skins/daisy-oled/skin.css", js: "skins/daisy-oled/skin.js" },
        { id: "matcha", name: "Matcha", author: "Leymo", builtin: true, typeIcons: [], css: "skins/matcha/skin.css", js: "skins/matcha/skin.js" },
        { id: "retro-purple", name: "Retro Purple", author: "Leymo", builtin: true, typeIcons: [], css: "skins/retro-purple/skin.css", js: "skins/retro-purple/skin.js" },
        { id: "retro-snes", name: "Super Retro", author: "Leymo", builtin: true, typeIcons: ["White icons"], css: "skins/retro-snes/skin.css", js: "skins/retro-snes/skin.js" },
        { id: "vertical-oled", name: "Vertical OLED", author: "Leymo", builtin: true, tag: "Vertical", typeIcons: ["Dark icons"], css: "skins/vertical-oled/skin.css", js: "skins/vertical-oled/skin.js" },
        { id: "vertical-retro", name: "Vertical Retro", author: "Leymo", builtin: true, tag: "Vertical", typeIcons: ["White icons"], css: "skins/vertical-retro/skin.css", js: "skins/vertical-retro/skin.js" },
        { id: "vertical-white", name: "Vertical White", author: "Leymo", builtin: true, tag: "Vertical", typeIcons: ["White icons"], css: "skins/vertical-white/skin.css", js: "skins/vertical-white/skin.js" },
        { id: "vertical-purple", name: "Vertical Purple", author: "Leymo", builtin: true, tag: "Vertical", typeIcons: [], css: "skins/vertical-purple/skin.css", js: "skins/vertical-purple/skin.js" },
        { id: "pokedex", name: "Pokédex", author: "Leymo", builtin: true, tag: "Lively", typeIcons: ["White icons"], css: "skins/pokedex/skin.css", js: "skins/pokedex/skin.js" },
        { id: "juicy", name: "Juicy Battles", author: "Leymo", description: "Example effects skin.", builtin: true, css: "skins/juicy/skin.css", js: "skins/juicy/skin.js" }]);
    },
    listTypePacks() { return window.__packs ? JSON.stringify(window.__packs) : "[]"; },
    getSetting(k) { const m = location.hash.match(/skin=([a-z-]+)/); const tp = location.hash.match(/pack=([a-z]+)/); return k === "settings" ? JSON.stringify({ skin: m ? m[1] : "default", typePack: tp ? tp[1] : "auto" }) : ""; },
    setSetting() {},
    runtimes() { return JSON.stringify([{ id: "com.kirin", label: "Kirin" }, { id: "cyou.joiplay.joiplay", label: "JoiPlay" }]); },
    games() { return JSON.stringify([{ title: "Pokémon Rejuvenation" }, { title: "Pokémon Tectonic" }]); },
    play(p) { console.log("play:", p); return true; },
    openSetup() { console.log("setup"); },
  };
  window.addEventListener("hashchange", () => { served = null; });
})();
