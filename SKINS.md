# Making PokeRPGLink skins and plugins

A **skin** is a folder. It can change how the bottom-screen panel looks (CSS), add features (JavaScript), or both. Players install one by copying the folder to:

```
<device storage>/PokeRPGLink/skins/<your-skin>/
```

and picking it from the **⚙** button on the panel. Three built-in skins ship with the app and are good starting points — they're in `ui/skins/` in this project:

| Built-in | Shows how to |
|---|---|
| `classic-ds` | Re-theme everything with CSS variables plus a few overrides |
| `oled-black` | Make a tiny tweak (5 lines) |
| `catch-tracker` | Add features with the plugin API: a section, a battle banner and a new tab |
| `daisy`, `daisy-white`, `daisy-oled` | A full re-skin: restyled move buttons (type icon, effectiveness, big PP), click sounds and bounce. The variants `@import` the Daisy CSS and change only variables — the easiest way to make your own colour version |
| `matcha`, `retro-purple`, `retro-snes` | Single-colour themes: they set `--t` (the type colour) to one value on moves and icons, recolour the built-in glyphs with `.tglyph [fill="#fff"] { fill: … }`, and tint image packs with a CSS `filter`. Their skin.js uses the shared `_shared/press.js` helper (`PokeRPGPress({ sound })`) for bounce + synth sounds |
| `juicy` | React to game events with animation and sound (shake on hit, chimes on catch/level-up) |

## Folder layout

```
my-skin/
  skin.json   required
  skin.css    optional — loaded after the panel's own styles
  skin.js     optional — runs after the panel starts
  …           anything else you want: sounds (.ogg/.mp3/.wav), images, fonts
```

Reference your own files from CSS with relative paths (`url(img/bg.png)`), and from JS with `PokeRPGLink.skinFile("sounds/hit.ogg")`.

`skin.json`:

```json
{ "name": "My Skin", "author": "you", "version": "1.0", "description": "One line about it.",
  "typeIcons": ["Dark icons"], "swatch": ["#10061f", "#2a1650", "#c77dff"], "tag": "Effects" }
```

`swatch` (optional) is the little preview in the skin picker: background, card and accent colour. `tag` (optional) is a one- or two-word label under the name, e.g. *Effects* or *Adds features*.

`typeIcons` (optional) names the type icon packs your skin looks best with, in order of preference; when the player's Type icons setting is *Match skin*, the first one they have installed is used.

## Theming with CSS

Most colours come from these variables — override them in `:root`:

| Variable | Used for |
|---|---|
| `--ink` | background |
| `--panel`, `--panel-2` | cards; chips and secondary buttons |
| `--line` | borders |
| `--text`, `--muted` | main and secondary text |
| `--amber` | selection, primary buttons, active tab |
| `--caught` | caught Pokémon names, area completion |
| `--fight`, `--bag`, `--mon`, `--run` | the four battle buttons |
| `--r-btn`, `--r-chip` | corner radius of big buttons / small chips |
| `--ui`, `--read` | interface font / reading font |

Type colours are classes: `.t-FIRE { --t: #ee8130 }` etc.

**Layout hooks** — `body` carries attributes you can target:

- `data-view` — `area`, `party`, `bag`, `map`, `dex`, `save`, a plugin tab id, or `b-fight` / `b-mon` in battle
- `data-mode` — `map`, `battle` or `title`
- `data-double` — `1` during double battles
- `data-skin` — your skin id

Main regions: `#bar` (top bar), `#main` (content), `#tabs` (bottom bar; `#tabs.battle` in battle), `#sheet` (pop-up panel), `#pad` (virtual buttons).
Move buttons contain `.ticon` (type icon), `.mn` (name), `.meff` (effectiveness word), `.ml` (type · power · PP line), `.ppbig` (large PP) and `.eff` (badges); the default look hides `.ticon`, `.meff` and `.ppbig`, Daisy shows them. Buttons also get `e-super`, `e-weak`, `e-none`, `e-normal` or `e-status`. `window.typeIcon("FIRE")` returns the type icon html (from the player's chosen icon pack when they have one).
Battle pieces: `.bstrip` (weather/field chips), `.fighter` (singles cards), `.field2` / `.mini` (doubles grid), `.moves` / `.move` (move buttons), `.tgt` (target picker).
Overworld pieces: `.grid` / `.tile` (area Pokémon; `.owned`, `.seen`, `.unseen`, `.off` = not out right now), `.row-btn` (list rows).

Example — move the battle buttons to the top and make move buttons taller:

```css
#app { grid-template-rows: auto auto 1fr; }
body[data-mode="battle"] #tabs { order: -1; }
body[data-mode="battle"] #main { order: 1; }
.move { min-height: 70px; }
```

## Plugins (skin.js)

Everything goes through `window.PokeRPGLink`:

```js
const T = window.PokeRPGLink;

T.state                    // latest game state (see below); null until the game connects
T.on("state", (s) => {})   // every new state (several times a second — keep it cheap)
T.on("render", (view, mainEl) => {})   // after a screen is drawn
T.on("battle", (battle) => {})         // after a battle screen is drawn

T.addSection("area", (s) => "<div>…</div>")   // html above a screen; also "battle", "party", "bag", "map", "dex", "save" or your tab id
T.addTab({ id: "notes", label: "Notes", icon: "<svg…>", render: (s) => "<div>…</div>" })
T.addBarButton({ id: "help", label: "?", icon: "<svg…>", onClick: () => T.openSheet("Help", "<p>…</p>") })

T.openSheet(title, html)    // pop-up panel; T.closeSheet()
T.onClick("name", (el, s) => {})   // clicks on <button data-plugin-click="name">
T.toast("Saved!", "ok")     // kinds: "ok", "error", or none
T.send("btn A")             // send a command to the game (list below)
T.settings()                // the player's panel settings

T.ui.esc(text)              // escape text for html
T.ui.icon(path, label, shadow)     // Pokémon icon like the built-in screens
T.ui.typeChip("FIRE")  T.ui.hpBar(hp, max)  T.ui.statusChip("BURN")  T.ui.imageUrl(gamePath)
T.ui.icons                  // the built-in SVG icons
```

Render functions are called often; return html strings, don't keep DOM references between renders. Errors in a plugin are caught and never break the panel.

### Game events (for animations and sounds)

The panel compares each new game state with the previous one and fires events. Listen to one with `T.on("damage", fn)` or to all of them with `T.on("event", (name, data) => …)`. They fire just after the screen is redrawn, so `T.find()` returns the fresh elements.

| Event | Data |
|---|---|
| `battleStart` / `battleEnd` | `{ trainer, double }` / `{}` |
| `turn` | `{ turn }` |
| `menu` | `{ menu, was }` — `"command"` means the battle is waiting for you |
| `sendOut` | `{ index, own, name }` — a new Pokémon entered a slot |
| `damage` / `heal` | `{ index, own, name, from, to, fraction }` — HP for your side, % for foes |
| `faint` | `{ index, own, name }` |
| `status` | `{ index, own, status }` |
| `statChange` | `{ index, own, stat, change }` — `stat` is `atk`, `def`, `spa`, `spd`, `spe`, `acc`, `eva` |
| `shieldBreak` | `{ index, left }` — Rejuvenation boss shields |
| `weather` / `field` | `{ id, name }` |
| `caught` | `{ owned }` — your caught count went up |
| `levelUp` | `{ slot, name, level }` |
| `badge` | `{ badges }` |
| `mapChange` | `{ id, name }` |
| `timeOfDay` | `{ period }` |
| `toast` | `{ text, kind }` — messages from the game (saved, item given…) |
| `message` | `{ text }` — each new line the battle prints (great for reacting to game-specific mechanics) |

### Sound and animation helpers

```js
T.playSound(T.skinFile("hit.ogg"), { volume: 0.8 })   // plays even without a tap
T.beep(660, 80, "square", 0.08, delayMs)              // synth bleep — no files needed
T.animate(T.find("battler", 1), [{ transform: "scale(1)" }, { transform: "scale(1.1)" }, { transform: "scale(1)" }], 250)
T.find("battler", i) / T.find("move", slot) / T.find("party", slot)   // elements on screen
```

Players control all of this from ⚙: *Skin animations & sounds* on/off and *Volume*. `playSound`, `beep` and `animate` respect those settings (and the system's reduced-motion setting), so you don't have to check them yourself. CSS `@keyframes` animations work as usual.

### Commands you can send

| Command | Does |
|---|---|
| `btn A` / `B` / `X` / `Y` / `L` / `R` / `UP` / `DOWN` / `LEFT` / `RIGHT` | Press a button once |
| `bcmd 0`–`3` | Battle menu: Fight, Bag, Pokémon, Run |
| `bmove <slot> [special] [t=<battler>]` | Use a move (optionally Mega/Z, optionally aimed at a battler) |
| `btarget <battler>` | Answer the game's target cursor |
| `bitem <ITEM> [party slot] [move]` | Use a bag item in battle (no bag screen) |
| `bball [BALL]` | Throw the quick ball, or a specific ball |
| `bswitch <party slot>` | Switch in a party member |
| `save`, `openparty`, `openbag`, `opendex`, `openmap` | Overworld actions (wait until the player is idle) |
| `useitem <ITEM>`, `useon <ITEM> <slot> [move]`, `giveitem <slot> <ITEM>`, `takeitem <slot>` | Items (`useon` uses it on a party member without the party screen) |
| `swapmove <slot> <i> <j>`, `swapparty <i> <j>` | Reorder |
| `fly <x> <y> <region>` | Fly to a town-map square |
| `req dex`, `req map` | Ask the game to write `dex.json` / `map.json` |

Battler slots: `0` you (left), `2` your ally (right), `1` foe (right), `3` foe (left).

### The state object (short version)

```text
state.mode            "map" | "battle" | "title"
state.game            { title, version, family }
state.player          { name, money, badges, seen, owned }
state.map             { id, name, period ("morning"|"day"|"evening"|"night"), pos, encounters: [
                        { kind ("grass"|"cave"|"surf"|"oldrod"…), time ("any"|"morning"|"day"|"night"),
                          list: [{ species, name, dex, chance, min, max, seen, owned, types, icon }] } ] }
state.party[]         { slot, species, name, level, hp, maxhp, status, types, ability, nature, item,
                        stats, base, ivs, evs, moves[], icon, … }
state.bag[]           { pocket, name, items: [{ id, name, qty, desc, icon, key, important,
                        battle: "pokemon"|"move"|"battler"|"ball"|"self"|null, field: "pokemon"|"field"|null }] }
state.battle          { turn, menu ("command"|"fight"|"target"|"switch"|"none"), activeIndex, double,
                        trainer, canRun, weather, field, global[], sides[2], battlers[], moves[],
                        targeting, party[] }
  commands[4]         the battle menu's real labels, e.g. ["Fight","Bag","Pokémon","Call"]
  battlers[]          { index, own, name, speciesName, level, hp, maxhp, hpPct (foes), status, types,
                        ability, stages, effects, item (own), owned (foes),
                        status2 (Tectonic Avatars can have two), shadow: { stage, max } (Shadow Pokémon),
                        boss: { label, shields (Rejuvenation), bars + actions (Tectonic Avatars) } }
  noBag               true when the game's bag/ball button can't be used (Tectonic outside wild battles)
  sidesAll            true when sides[] already lists only effects the game itself shows
  moves[]             { slot, name, type, cat, pow, acc, pp, maxpp, stab, field, fieldType, fieldAcc,
                        target, pick[], vs: [{ index, foe, mult }] }
  log[]               { id, text } — the battle's recent messages
  balls               { quick: { id, name, qty, icon, last }, all: [...] } — the quick-ball choice
  battlers[].otherEffects   less common active effects, by name
state.toasts[]        recent messages from the game
state.watch[]         { label, value } — game variables/switches chosen by extensions
state.ext             data added by game extensions (see EXTENDING.md)
```

Image paths (`icon`, `sprite`) are relative to the game folder — pass them through `T.ui.imageUrl()`.

## Sharing

Zip the folder. Players unzip it into `PokeRPGLink/skins/` and pick it from ⚙. Don't include Pokémon artwork or other people's assets in a skin.
