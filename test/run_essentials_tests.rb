# Mock of a Pokémon Essentials v21-style game (GameData, Battle::Scene, $player, $bag)
# to exercise PokeRPGLink's Essentials adapter. Run: ruby test/run_essentials_tests.rb
require_relative "ess_mock"
load File.expand_path("../mod/PokeRPGLink.rb", __dir__)

$fails = 0
def check(n, c); puts "#{c ? 'PASS' : 'FAIL'}  #{n}"; $fails += 1 unless c; end
def frames(n); n.times { Input.update }; end
def send_cmd(l); @n = (@n || 0) + 1; File.write(File.join(PokeRPGLink.dir, "cmd", format("%015d.cmd", @n)), l); end
def state; JSON.parse(File.read(File.join(PokeRPGLink.dir, "state.json"))); end

check "essentials adapter active", PokeRPGLink.essentials?
check "essentials hooks installed", (%w[battle-start-end battle-command-menu battle-fight-menu battle-frame battle-target battle-switch battle-item-menu battle-messages party-screen input map] - PokeRPGLink.hooks_ok).empty?
puts "  failed: #{PokeRPGLink.hooks_failed.inspect}" unless PokeRPGLink.hooks_failed.empty?

frames(20)
s = state
check "game title + family", s["game"]["title"] == "Pokémon Test Quest" && s["game"]["family"] == "essentials-v21"
g = s["map"]["encounters"]
check "encounter types mapped (grass any/night, surf)", g.map { |x| [x["kind"], x["time"]] }.sort == [["grass", "any"], ["grass", "night"], ["surf", "any"]]
zz = g.find { |x| x["time"] == "any" }["list"][0]
check "slots merged with chance + level range", zz["species"] == "ZIGZAGOON" && zz["chance"] == 50 && zz["min"] == 2 && zz["max"] == 4 && zz["seen"] && !zz["owned"]
p0 = s["party"][0]
check "party mon data", p0["name"] == "Pikachu" && p0["types"] == ["ELECTRIC"] && p0["ivs"]["spa"] == 3 && p0["nature"]["up"] == "Spe" && p0["moves"][0]["pow"] == 90
check "party icon resolved", p0["icon"] == "Graphics/Pokemon/Icons/PIKACHU.png"
check "bag pockets", s["bag"].find { |p| p["name"] == "Items" }["items"].map { |i| i["name"] } == ["Potion", "Oran Berry"]
check "save confirm handled by game", s["features"]["saveAsks"] == true
check "map position", s["map"]["pos"] == [0, 5, 6]
check "no battle-facility panel outside a challenge", !s.key?("frontier")

send_cmd("giveitem 0 ORANBERRY"); frames(4); $scene.update
check "give item via game function", $player.party[0].item == :ORANBERRY
send_cmd("swapmove 0 0 2"); frames(4); $scene.update
check "swap moves", $player.party[0].moves.map(&:id) == [:DISCHARGE, :QUICKATTACK, :THUNDERBOLT]
send_cmd("swapmove 0 0 2"); frames(4); $scene.update
send_cmd("save"); frames(4); $scene.update
check "save opens the game's save screen", SAVES.length == 1

send_cmd("req map"); frames(4)
tm = JSON.parse(File.read(File.join(PokeRPGLink.dir, "map.json")))
check "v21 town map", tm["regions"][0]["image"] == "Graphics/UI/Town Map/hoenn.png" && tm["points"].count { |p| p["fly"] } == 2 && tm["points"].find { |p| p["name"] == "Oldale Town" }["visited"]
send_cmd("fly 3 2 0"); frames(4); $scene.update
check "fly via pbFlyToNewLocation with the party's Fly user", FLIGHTS.last == [[12, 4, 5], "Taillow"]

send_cmd("req dex"); frames(4)
dex = JSON.parse(File.read(File.join(PokeRPGLink.dir, "dex.json")))
check "dex export", dex["species"].length == 4 && dex["species"].find { |d| d["species"] == "ZIGZAGOON" }["where"].any? { |w| w.include?("grass") }

# ---- double battle
sc = Battle::Scene.new
bt = Battle.new(true)
sc.pbStartBattle(bt)
PokeRPGLink.menu = :command; PokeRPGLink.menu_index = 0
frames(20)
b = state["battle"]
check "battle state: weather/terrain/side/field fx", b["weather"]["name"] == "Rain" && b["field"]["name"] == "Electric Terrain" && b["sides"][0]["Reflect"] == 3 && b["global"][0]["id"] == "TrickRoom"
foe = b["battlers"].find { |x| x["index"] == 1 }
check "battler stages/effects (LeechSeed idx 0 counts)", foe["stages"] == { "atk" => 1, "spe" => -2 } && foe["effects"].sort == ["Confusion", "LeechSeed"]
tb = b["moves"].find { |m| m["name"] == "Thunderbolt" }
check "effectiveness normalised (Electric vs Flying = 2, vs Ground = 0)", tb["vs"].find { |v| v["index"] == 1 }["mult"] == 2.0 && tb["vs"].find { |v| v["index"] == 3 }["mult"] == 0.0
check "unknown effects found via PBEffects scopes", foe["otherEffects"] == ["MagicCoat"] && b["sides"][1]["Rainbow"] == 4
check "single-target move lists picks, spread move doesn't", tb["pick"].sort == [1, 2, 3] && b["moves"].find { |m| m["name"] == "Discharge" }["pick"].nil?

r = nil
send_cmd("bmove 0 t=3")
c1 = sc.pbCommandMenuEx(0, [])
sc.pbFightMenu(0) { |i| r = i; true }
check "panel move: Fight then move 0", c1 == 0 && r == 0
check "pre-picked target returned", sc.pbChooseTarget(0, GameData::Target.get(:NearOther)) == 3
send_cmd("bmove 2")
sc.pbCommandMenuEx(0, []); sc.pbFightMenu(0) { |i| r = i; true }
check "spread move auto-confirmed", sc.pbChooseTarget(0, GameData::Target.get(:AllNearOthers)) == 1

# game opens cursor first, player taps target 2 a few frames later
cnt = 0
orig = PokeRPGLink.method(:battle_frame)
PokeRPGLink.define_singleton_method(:battle_frame) { |s2, cw| cnt += 1; PokeRPGLink.handle(["btarget", "2"]) if cnt == 3; orig.call(s2, cw) }
check "tap on target during cursor", sc.pbChooseTarget(0, GameData::Target.get(:NearOther)) == 2
PokeRPGLink.define_singleton_method(:battle_frame) { |s2, cw| orig.call(s2, cw) }

# panel bag: Essentials hands the choice to the game's block
got = nil
send_cmd("bitem POTION 1"); sc.pbCommandMenuEx(0, [])
sc.pbItemMenu(0, true) { |*a| got = a; true }
check "essentials item menu yields the panel choice", got && got[0] == :POTION && got[1] == 1 && got[2] == 1 && !$bag_opened
frames(20)
bl = state["battle"]["balls"]
check "essentials ball fallback = most plentiful", bl["quick"]["id"] == "DUSKBALL"
bt.pbThrowPokeBall(1, :ULTRABALL); frames(20)
check "essentials remembers last ball", state["battle"]["balls"]["quick"]["id"] == "ULTRABALL"
got = nil
send_cmd("bball"); sc.pbCommandMenuEx(0, [])
sc.pbItemMenu(0, true) { |*a| got = a; true }
check "essentials quick ball targets a foe", got && got[0] == :ULTRABALL && got[1] == 4 && [1, 3].include?(got[2])
crashed = begin; sc.pbDisplayPausedMessage("Pikachu learned Thunder!"); false; rescue ArgumentError; true; end
check "essentials paused message passes through", !crashed

# switch through the party screen
PokeRPGLink.in_switch = true
send_cmd("bswitch 1"); frames(10)
ps = PokemonParty_Scene.new
ps.update
check "party screen picks display slot + auto Switch In", ps.sel == 1 && ps.pbShowCommands("x", []) == 0
PokeRPGLink.in_switch = false
sc.pbEndBattle(0)
frames(10)
check "back to map", state["mode"] == "map"
puts File.read(File.join(PokeRPGLink.dir, "log.txt")) rescue nil
r = pbMessageDisplay(nil, "Hello there!")
frames(40)
st = JSON.parse(File.read(File.join(PokeRPGLink.dir, "story.json"))) rescue {}
check "v21 story log (plain pbMessageDisplay)", r == :shown && SHOWN_V21 == ["Hello there!"] && (st["lines"] || []).any? { |l| l["text"] == "Hello there!" }
puts($fails.zero? ? "\nALL PASSED" : "\n#{$fails} FAILED")
exit($fails.zero? ? 0 : 1)
