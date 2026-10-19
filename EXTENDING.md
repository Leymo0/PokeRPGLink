# Teaching PokeRPGLink a game's special mechanics

PokeRPGLink picks up a lot on its own:

- **Every message the battle prints** goes to the battle log (the line under the weather chips — tap it for the full log). Custom abilities, gimmick fields, boss phases… if the game tells the player, it shows up here.
- **Every active effect** on a Pokémon, a side or the field is listed, not just the well-known ones (the less common ones appear as "+N more" and in the Pokémon's detail sheet).
- **Data the game stores in its tables** — field effects, abilities, items, moves, types, encounters — is read live, so things added in updates appear automatically.

What it can't do by itself is understand a mechanic that only exists inside a game's code (a karma meter, a rift energy bar, a custom party feature). For those, write a small **extension**: a Ruby file that tells PokeRPGLink what to read, plus (optionally) a skin that shows it.

## Where extensions go

```
<game folder>/PokeRPGLink/extensions/my-game.rb
```

Every `.rb` file in that folder is loaded when the game starts, after PokeRPGLink itself. A broken extension is logged to `PokeRPGLink/log.txt` and skipped — it can't crash the game.

## The simplest extension: show game variables

Most games keep their counters in RPG Maker variables and switches. Find the number in the game's editor/event list (or by watching it change), then:

```ruby
PokeRPGLink.watch_variable(42, "Karma")
PokeRPGLink.watch_variable(77, "Rift energy")
PokeRPGLink.watch_switch(150, "Got the Bicycle")
```

These appear under **Game info** on the panel's Save tab. No skin needed.

## Custom data for skins

```ruby
PokeRPGLink.add_state("rift") do |state|
  { "energy" => $game_variables[77], "boss" => $game_switches[160] }
end
```

The block runs a few times a second; whatever it returns (numbers, strings, true/false, arrays, hashes) shows up in the panel as `PokeRPGLink.state.ext.rift`. Keep it fast and read-only.

## Custom commands

```ruby
PokeRPGLink.add_command("quickheal") do |args|
  # runs inside the game when the panel sends: ext quickheal <args...>
  $Trainer.party.each { |p| p.heal }
  PokeRPGLink.toast("Party healed", "ok")
end
```

From a skin: `PokeRPGLink.send("ext quickheal")`. Commands run the moment they arrive, so only do things that are safe at any time — or check `PokeRPGLink.map_idle?` first and toast if the player is busy.

## Showing it on the panel

Pair the extension with a skin (see [SKINS.md](SKINS.md)):

```js
PokeRPGLink.addSection("battle", (s) =>
  s.ext && s.ext.rift ? `<div class="chip">Rift energy ${s.ext.rift.energy}</div>` : "");
```

## Useful hooks inside the game

| | |
|---|---|
| `PokeRPGLink.battle` | the current battle object, or `nil` |
| `PokeRPGLink.trainer` | the player (`$Trainer` / `$player`) |
| `PokeRPGLink.toast(text, "ok" / "error")` | message on the panel |
| `PokeRPGLink.log(text)` | write to `PokeRPGLink/log.txt` |
| `PokeRPGLink.map_idle?` | true when the player is standing still with no message or menu open |

## Sharing

Ship the extension `.rb` and its skin folder together. Players copy the `.rb` into `<game>/PokeRPGLink/extensions/` and the skin folder into `PokeRPGLink/skins/` on their device. Note that an extension runs as part of the game — only install ones from people you trust, the same as any other mod.
