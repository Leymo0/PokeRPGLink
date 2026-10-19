# PokeRPGLink — a bottom-screen touch panel for Pokémon fangames on the AYN Thor

*by Leymo*

## What it looks like

The game runs on the top screen; PokeRPGLink is the touch panel on the bottom screen. Shown here with the *Daisy White* skin (Pokémon appear as the game's own icons on the real device).

| In battle | |
|---|---|
| ![Battle](docs/images/page-battle.png)<br>**Battle** (Pokémon Rejuvenation) — your moves with type, power, PP and how well they hit; weather, field effect and screens up top | ![Field effect](docs/images/page-field.png)<br>**Tap the field** — what the current field effect does to moves and types |
| ![Double battle](docs/images/page-double.png)<br>**Double battles** — compact cards; tap a move, then its target | ![Shadow and boss](docs/images/page-shadow.png)<br>**Shadow Pokémon & bosses** — heart gauge, boss shields, and *Call* |
| ![Tectonic avatar](docs/images/page-tectonic.png)<br>**Pokémon Tectonic** — Avatars with health bars and two moves a turn, Numb/Dizzy and the rest of Tectonic's statuses | ![Bag in battle](docs/images/page-battle-bag.png)<br>**Bag in battle** — only items you can use right now; pick the Pokémon here, no bag screen on top |
| ![Switch](docs/images/page-battle-mon.png)<br>**Switch** — HP, status and types for your whole team | |

| Out of battle | |
|---|---|
| ![Area](docs/images/page-area.png)<br>**Area** — the wild Pokémon here: shadows until you've seen them, a Poké Ball once caught, morning/day/night icons | ![Party](docs/images/page-party.png)<br>**Pokémon** — your team at a glance |
| ![Summary](docs/images/page-summary.png)<br>**Summary** — stats, ability, held item, move order | ![Bag](docs/images/page-bag.png)<br>**Bag** — use items, give them to a Pokémon |

## Skins

Eleven built-in skins, chosen from the panel's ⚙ button and remembered **per game**. Want your own? **[SKINS.md](SKINS.md)** explains how to make skins — colours, layouts, extra features, animations and sounds.

| Juicy Battles: animations & sounds on game events | Dim when idle (OLED Black) |
|---|---|
| ![Juicy Battles](docs/images/juicy.gif) | ![Dim when idle](docs/images/dim.gif) |
| Cards shake and flash when hit, numbers float up, stat changes pop — all from game events | Off by default. After 15 s without a touch the panel dims a little; any touch brings it back |

**Default**

![Default skin](docs/images/skin-default.png)

**Classic DS**

![Classic DS skin](docs/images/skin-classic-ds.png)

**OLED Black**

![OLED Black skin](docs/images/skin-oled-black.png)

**Daisy**

![Daisy skin](docs/images/skin-daisy.png)

**Daisy White**

![Daisy White skin](docs/images/skin-daisy-white.png)

**Daisy OLED**

![Daisy OLED skin](docs/images/skin-daisy-oled.png)

**Matcha**

![Matcha skin](docs/images/skin-matcha.png)

**Retro Purple**

![Retro Purple skin](docs/images/skin-retro-purple.png)

**Super Retro**

![Super Retro skin](docs/images/skin-retro-snes.png)

**Catch Tracker**

![Catch Tracker skin](docs/images/skin-catch-tracker.png)


## Supported games

| Game | How the mod gets in | Notes |
|---|---|---|
| Pokémon Rejuvenation (V13.5, V14) | its `.rb` Mods folder | Built against its scripts; field effects shown in full |
| Pokémon Reborn (E19.5) | its `.rb` Mods folder | Same engine as Rejuvenation |
| Pokémon Desolation (EP6) | its `.rb` Mods folder | Same engine as Reborn |
| Pokémon Infinite Fusion (incl. IF 2: Hoenn) | `Data/Scripts/998_PokeRPGLink/` | Built against its public source |
| Pokémon Tectonic | `Plugins/PokeRPGLink/` + a small loader added to `Data/PluginScripts.rxdata` | Its own adapter: six-button battle menu (the panel's Bag button is Tectonic's *Ball*), Avatars (health bars left, moves per turn, second status), Numb/Frostbite/Dizzy/Leeched/Waterlogged, stat steps, every battle effect the game shows, adaptive moves, several held items |
| Other Pokémon Essentials v19–v21 games that ship loose scripts in `Data/Scripts/` | `Data/Scripts/998_PokeRPGLink/` | Same adapter as Infinite Fusion |
| Other Essentials v19–v21 games with packed scripts but a `Data/PluginScripts.rxdata` | `Plugins/PokeRPGLink/` + loader (as Tectonic) | Generic Essentials adapter — should work, less tested |
| Older games with everything packed in `Scripts.rxdata` (Insurgence, Uranium, …) | — | Not supported: there's no safe place to add a mod |

**How the plugin loader works:** release builds of Essentials v19+ only run the plugins compiled into `Data/PluginScripts.rxdata` (the `Plugins` folder is re-read only in debug mode). The app appends one tiny plugin to that file — a loader that runs `Plugins/PokeRPGLink/PokeRPGLink.rb` — and keeps a backup next to it (`PluginScripts.rxdata.pokerpglink-backup`). A game update replaces that file; the app notices and adds the loader again the next time you open it.

Add several games in the app — the panel follows whichever one is running. The app reads each game's own files to decide where the mod goes, so you never have to know whether it's `patch/Mods`, `Data/Mods` or `Data/Scripts`.

The game runs on the top screen with your controller. The bottom screen shows a touch panel:

- **In battle:** Fight / Bag / Pokémon / Run as big buttons. The Fight view shows the foe and your Pokémon (types, HP, status, stat boosts, confusion etc.), weather, the field effect, screens and hazards, and your four moves with type, PP, STAB, field boost and effectiveness against the foe. Tap a move to use it; long-press a move for details; tap the weather/field chips for what the field does.
- **Bag:** the Bag button opens your bag on the bottom screen, in battle and out. Pick an item, pick the Pokémon (and the move, for PP items) right there, and the game uses it — no bag screen on top. In battle only usable items are listed; there's still a link to the game's own bag for anything unusual.
- **Quick Poké Ball (wild battles):** a ball button next to the battle log throws the last ball you used — any ball the game knows, custom ones included. If you've run out, it switches to the ball you have most of (keeping Master Ball-type balls as a last resort). Long-press it to pick a different ball.
- **Type icon packs:** put one PNG per type (`FIRE.png`, `WATER.png`…) in `<storage>/PokeRPGLink/typeicons/<pack name>/` and pick it under ⚙ → Type icons. The default, *Match skin*, lets each skin choose: Daisy and Daisy White use a pack named "White icons", Daisy OLED uses "Dark icons". Without a pack, PokeRPGLink's own simple glyphs are used.
- **Double battles:** the four Pokémon sit in a 2×2 grid laid out like the field (foes on top, your side below) with just name, HP and status — tap any of them for the full details. The Pokémon you're choosing for is outlined. Moves show effectiveness per foe (`L ×2`, `R ×½`). Tapping a single-target move opens a target picker in the same 2×2 layout, with each target's effectiveness and anything you can't hit greyed out. Spread moves go straight through. If the game opens its own target cursor (e.g. you picked the move with the controller), the picker pops up by itself.
- **Out of battle:**
  - **Area** — the wild Pokémon on your current map, grouped by Grass / Cave / Surfing / rods. Uncaught ones are shadows (`???` until you've seen them); caught ones show their icon with a green name and a Poké Ball mark. Sun / moon / sunrise icons mark day-, night- and morning-only Pokémon, and ones that can't appear right now are dimmed.
  - **Pokémon** — party HP and status; tap one for summary, stats (IV/EV), moves (tap two moves to swap their order), give/take held items, move up/down in the party.
  - **Bag** — pockets and items; use an item or give it to a Pokémon.
  - **Map** — the region map with your position; tap a fly point you've visited to Fly there.
  - **Pokédex** — opens the game's own Pokédex on the top screen.
  - **Save** — saves the game (with a confirm), plus shortcuts to open the in-game screens.
- **✚ button (top right):** a virtual A/B/X/Y/L/R and D-pad, for things like choosing a target in double battles by touch.
- **— button:** hides the panel into a small bubble; tap the bubble to bring it back.
- **Game mechanics:** Rejuvenation's field effects are read from the game's own data, so fields added in future updates appear automatically — including type boosts, moves that gain a second type or change accuracy on a field, what changes the field, and temporary fields (with what they revert to). Shadow Pokémon get a purple Shadow tag and their heart gauge (on your party and on foes), the battle bar shows the game's real 4th button (**Call** against Shadow Pokémon), and Rejuvenation boss Pokémon show their remaining shields. Beyond that, PokeRPGLink catches what it wasn't specifically built for: **every line the battle prints** goes into a battle log (one line under the weather chips, tap for all of it), and **every active effect** on a Pokémon, side or field is listed — so a new game's custom mechanics still show up in some form. Things a game only tracks in its own code (a karma meter, a special energy bar) need a small extension — see **[EXTENDING.md](EXTENDING.md)**; a one-line extension can show any game variable on the panel.
- **⚙ button:** skins, type icons, size, vibration, skin animations & sounds with volume, and **Dim when idle** (off by default: after 15 seconds without a touch the panel dims slightly to protect the OLED screen — still readable, and any touch brings it straight back). The skin and type icons are **remembered per game**: pick Matcha while playing Rejuvenation and Daisy in Tectonic, and each game comes back with its own look. Skins can re-theme the panel, change its layout or add features — see **[SKINS.md](SKINS.md)** to make your own. Built in: *Matcha* (matcha green and wood, one colour family — even the type icons), *Retro Purple* (translucent purple glass with neon edges), *Super Retro* (16-bit console grey and purple with red/yellow/blue/green face buttons), *Daisy*, *Daisy White* and *Daisy OLED* (colourful pill-shaped moves with a type icon, effectiveness and big PP, bouncy buttons and click sounds), plus *Classic DS* (light), *OLED Black*, *Catch Tracker* (an example plugin that adds an area-completion bar, a "not caught yet" banner in wild battles and a *To catch* tab) and *Juicy Battles* (an example effects skin — cards shake and flash on hits, chiptune bleeps on faints, catches and level-ups). Skins can react to game events (damage, faint, caught, level up, stat changes…) with their own animations and sound files.

The panel window is created with Android's `FLAG_NOT_FOCUSABLE`, so touching the bottom screen **never takes controller focus away from the game** on the top screen.

---

## 1. What to install (recommended setup)

| What | Why |
|---|---|
| **Kirin** (Android RPG Maker XP runtime) — free on its Patreon, install guide at playkirin.com | The Rejuvenation devs recommend Kirin over JoiPlay for V14: smoother and fewer crashes. |
| **The game's *Kirin* download** — rebornevo.com has Kirin builds for the Rebornverse games | Each runtime has its own build. Grab the Kirin one. |
| **PokeRPGLink** (this project) — install it with Obtainium, step 2 | The bottom-screen panel + the mod. The app installs the mod into your games for you. |

JoiPlay still works if you prefer it — download the *JoiPlay* build of the game instead. PokeRPGLink works with either because it only talks to the game through files in the game folder.

**Pokémon Tectonic:** download the normal PC version from tectonic-game.com, unzip it to your storage and run it with JoiPlay (with its RPG Maker plugin) — Tectonic's wiki says it runs there, with the occasional hiccup. Kirin may also run it. PokeRPGLink finds the folder and sets everything up the same way.

**Put the game folder in normal storage**, e.g. `/storage/emulated/0/Games/Rejuvenation/` — not inside `Android/data/…` (apps can't share files there).

Give Kirin (or JoiPlay) **All files access** in Android Settings → Apps → Kirin → Permissions, so the game can write its `PokeRPGLink` folder.

## 2. Download and set up Obtainium (recommended)

[Obtainium](https://github.com/ImranR98/Obtainium) installs PokeRPGLink straight from this page's releases and tells you when there's a new version — one tap to update, no hunting for APKs.

1. **Install Obtainium** on the Thor: download the latest `app-…-release.apk` from [Obtainium's releases](https://github.com/ImranR98/Obtainium/releases/latest) (pick *arm64-v8a* if you're asked) and open it. Allow *Install unknown apps* for your browser when Android asks.
2. Open Obtainium → **Add App** → paste `https://github.com/Leymo0/PokeRPGLink` → **Add**.
3. Tap **Install**. PokeRPGLink appears in your app drawer.
4. From now on Obtainium shows an update badge when a new version comes out. Tap **Update** — your settings, skins and games are kept, and the app updates the mod inside each game by itself the next time you open it.

**Without Obtainium:** open the [latest release](https://github.com/Leymo0/PokeRPGLink/releases/latest), download `PokeRPGLink-….apk` on the Thor and open it. To update later, install the new APK the same way over the old one.

## 3. Set it up on the Thor

Open **PokeRPGLink**. It always lives on the bottom screen, and it only ever shows you the next thing to do:

1. **Permissions** — tap *Allow showing on top* and *Allow file access*, switch PokeRPGLink on, press Back.
2. **Your game** — PokeRPGLink searches your storage by itself, adds every supported game it finds and installs the mod into the right folder. Nothing to tap. (It also keeps the mod up to date every time you open it after updating the app.) If nothing is found, check the game isn't inside the `Android` folder and tap *Search again*.
3. **Start** — one big button: the panel appears on the bottom screen and Kirin (or JoiPlay) opens on the top screen.
4. Load your save. The dot in the panel's top bar turns green.

The panel always goes on the bottom screen. If the bottom screen isn't available it shows on the main screen and jumps down by itself as soon as the bottom screen comes back. Everything else (adding a folder by hand, removing a game, reinstalling the mod, where skins go) is under **More options**.

Manual mod install if you prefer: copy `mod/PokeRPGLink.rb` into the game's mod folder — `patch/Mods/` on Rejuvenation V14 / Reborn E19.5 (create `Mods` if missing), `Data/Mods/` on Rejuvenation V13.5.

**Your own icons:** drop PNGs into `<game>/PokeRPGLink/icons/`, named by species (`PIKACHU.png`) or dex number (`025.png`); add `s` for shiny (`PIKACHUs.png`) or `_<form>` for forms. They replace the game's icons on the panel; uncaught Pokémon are still shown as shadows.

## 4. Playing every day

Once setup is done, **tapping the PokeRPGLink icon is all you need** — from either screen. It puts the panel on the bottom screen and opens Kirin (or JoiPlay) on the top screen in one go; pick your game there. Long-press the icon → **Setup** to get back to the setup screen (or use ⚙ on the panel → *PokeRPGLink setup*).

- **Play button on the panel:** while no game is running, the panel shows a big **Play** button that opens Kirin on the top screen. When the game has been closed, a ▶ button appears in the panel's top bar.
- **Show the panel when the Thor turns on** (setup screen → Quick start, off by default): the panel is waiting on the bottom screen after every restart, so you can start playing without touching the top screen at all.
- Kirin and JoiPlay don't let other apps open one specific game, so you still pick the game in their list (one tap).
- Have both Kirin and JoiPlay? Choose on the setup screen or tap *Use JoiPlay* on the panel — PokeRPGLink remembers the last one you used.

---

## Troubleshooting

- **Panel says "Waiting for the game"** — the mod isn't running. Check the mod is in the right Mods folder and restart the game. Look in `<game>/PokeRPGLink/log.txt`; the first line lists which hooks loaded.
- **No `PokeRPGLink` folder appears in the game folder** — the runtime can't write there: give Kirin/JoiPlay *All files access*.
- **No Pokémon pictures, just letters** — the game build doesn't ship loose image files, or the folder path is wrong. Everything still works; it's just text.
- **A feature does nothing after a game update** — open `PokeRPGLink/log.txt`; every hook fails on its own and gets logged, the game keeps working. Send me the log line.
- **Tectonic stopped connecting after a game update** — open the PokeRPGLink app once: the update replaced `Data/PluginScripts.rxdata`, and the app puts the loader back. Then restart the game.
- **Uninstall** — delete `PokeRPGLink.rb` from the Mods folder and the `PokeRPGLink` folder (for plugin games: the `Plugins/PokeRPGLink` folder, and put `PluginScripts.rxdata.pokerpglink-backup` back as `PluginScripts.rxdata`). Your save is never modified by the mod (except when you press Save, which uses the game's own save).

## How it works

```
Top screen: Kirin runs Rejuvenation + PokeRPGLink.rb
   │  writes  PokeRPGLink/state.json  (~7×/sec: battle, area, party, bag…)
   │  reads   PokeRPGLink/cmd/*.cmd   (one tap = one command file)
Bottom screen: PokeRPGLink app → non-focusable overlay window → WebView UI (ui/)
```

Battle taps are fed through the game's own menus (it moves the menu cursor and presses A for you), so all the game's rules and checks still apply. Out-of-battle actions (save, fly, items) wait until you're standing still with no text box open.

## For developers

Building the app yourself, signing releases, running the tests and the project layout are in **[BUILDING.md](BUILDING.md)**. Making skins: **[SKINS.md](SKINS.md)**. Adding support for a game's own mechanics: **[EXTENDING.md](EXTENDING.md)**.
