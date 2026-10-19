# Exercises PokeRPGLink against the mock game. Exit code != 0 on failure.
require_relative "mock_game"

$fails = 0
def check(name, cond)
  puts "#{cond ? 'PASS' : 'FAIL'}  #{name}"
  $fails += 1 unless cond
end

def frames(n); n.times { Input.update }; end
def send_cmd(line)
  @n = (@n || 0) + 1
  File.write(File.join(PokeRPGLink.dir, "cmd", format("%015d.cmd", @n)), line)
end
def state; JSON.parse(File.read(File.join(PokeRPGLink.dir, "state.json"))); end

check "all hooks installed", PokeRPGLink.hooks_failed.empty?
puts "  hooks: #{PokeRPGLink.hooks_ok.join(', ')}"

# --- reload safety: loading twice must not double-wrap ---
load File.expand_path("../mod/PokeRPGLink.rb", __dir__)
frames(2)
check "double load is safe (no recursion)", true

# --- overworld state ---
frames(20)
s = state
check "mode is map", s["mode"] == "map"
check "map name", s["map"]["name"] == "Route 1"
grass = s["map"]["encounters"].select { |g| g["kind"] == "grass" }
check "grass groups for any/day/night", grass.map { |g| g["time"] }.sort == %w[any day night]
pika = grass.find { |g| g["time"] == "any" }["list"].find { |e| e["species"] == "PIKACHU" }
check "pikachu chance summed (30) and owned", pika["chance"] == 30 && pika["owned"] && pika["min"] == 3 && pika["max"] == 6
check "pikachu icon resolved", pika["icon"] == "Graphics/Icons/iconPIKACHU.png"
FileUtils.mkdir_p("PokeRPGLink/icons"); File.write("PokeRPGLink/icons/088.png", "x")
PokeRPGLink.instance_variable_set(:@icon_cache, {})
frames(20)
grim = state["map"]["encounters"].flat_map { |g| g["list"] }.find { |e| e["species"] == "GRIMER" }
check "custom icon pack by dex number wins", grim["icon"] == "PokeRPGLink/icons/088.png"
# Rejuvenation 14 style: the game's icon lookup gives a path whose file isn't loose
# (packed graphics); the mod draws the game's bitmap into PokeRPGLink/cache instead.
class FakeColor; attr_reader :red, :green, :blue, :alpha; def initialize(r, g, b, a); @red, @green, @blue, @alpha = r, g, b, a; end; end
class Bitmap
  def initialize(path); raise "missing" unless path.to_s.include?("Packed"); @w, @h = 8, 4; end
  def width; @w; end
  def height; @h; end
  def get_pixel(x, y); FakeColor.new(x * 30, y * 60, 200, x < 4 ? 255 : 0); end
  def dispose; end
end
def pbCheckPokemonIconFiles(p, egg = false); raise ArgumentError, "%03d with a symbol"; end
def pbResolveBitmap(x); x.to_s.include?("iconGRIMER") ? "Graphics/Packed/iconGRIMER.png" : nil; end
FileUtils.rm_f("PokeRPGLink/icons/088.png")
PokeRPGLink.instance_variable_set(:@icon_cache, {})
frames(20)
grim2 = state["map"]["encounters"].flat_map { |g| g["list"] }.find { |e| e["species"] == "GRIMER" }
png = (File.binread(grim2["icon"]) rescue "")
require "zlib"
idat = png[33 + 8, png[33, 4].unpack1("N")] rescue ""
pix = (Zlib::Inflate.inflate(idat) rescue "")
check "packed icon drawn into the cache as a PNG (first frame only)", grim2["icon"].to_s.start_with?("PokeRPGLink/cache/") && png.start_with?("\x89PNG".b) && png[16, 8].unpack("NN") == [4, 4] && pix.bytesize == 4 * (4 * 4 + 1)
check "period is night", s["map"]["period"] == "night"
check "map position", s["map"]["pos"] == [0, 22, 29]
check "party has 2", s["party"].length == 2
check "party moves", s["party"][0]["moves"].map { |m| m["name"] } == ["Thunderbolt", "Quick Attack", "Thunder Wave", "Iron Tail"]
check "held item", s["party"][0]["item"]["name"] == "Light Ball"
check "bag medicine pocket", s["bag"].find { |p| p["name"] == "Medicine" }["items"][0]["qty"] == 3

# --- field actions ---
send_cmd("swapmove 0 0 3")
frames(4); $scene.update; frames(10)
check "swap moves", $Trainer.party[0].moves.map(&:move) == [:IRONTAIL, :QUICKATTACK, :THUNDERWAVE, :THUNDERBOLT]
send_cmd("save")
frames(4); $scene.update
check "save ran", SAVED.length == 1
send_cmd("giveitem 1 POTION")
frames(4); $scene.update
check "give item", $Trainer.party[1].item == :POTION && $PokemonBag.pbQuantity(:POTION) == 2
frames(10)
check "toast from game text, control chars stripped", state["toasts"].any? { |t| t["text"] == "Geodude was given the Potion to hold." }
send_cmd("fly 22 29")
frames(4); $scene.update
check "fly uses party Fly user + flydata", FLOWN.last == [[58, 42, 50], "Geodude"]
send_cmd("fly 20 29")
frames(4); $scene.update; frames(10)
check "fly refuses unvisited", state["toasts"].any? { |t| t["text"].include?("haven't visited") }
send_cmd("swapparty 0 1")
frames(4); $scene.update
check "swap party", $Trainer.party[0].species == :GEODUDE
send_cmd("swapparty 0 1"); frames(4); $scene.update

# --- static exports ---
send_cmd("req dex"); send_cmd("req map")
frames(4)
dex = JSON.parse(File.read(File.join(PokeRPGLink.dir, "dex.json")))
check "dex sorted with locations", dex["species"].first["species"] == "PIKACHU" && dex["species"].first["where"].any? { |w| w.include?("Route 1") }
# Rejuvenation 14 keeps species data inside a per-form wrapper
class MonWrapper; def initialize(sym, data); @flags = {}; @mon = sym; @pokemonData = { "Normal Form" => data }; end; end
$cache.pkmn[:ZUBAT] = MonWrapper.new(:ZUBAT, $cache.pkmn[:ZUBAT])
send_cmd("req dex"); frames(4)
dex14 = JSON.parse(File.read(File.join(PokeRPGLink.dir, "dex.json")))
zb = dex14["species"].find { |e| e["species"] == "ZUBAT" }
check "dex works with Rejuvenation 14 species wrappers", zb && zb["dex"] == 41 && zb["base"] && zb["types"] == ["POISON", "FLYING"] && dex14["species"].length == dex["species"].length
$cache.pkmn[:ZUBAT] = $cache.pkmn[:ZUBAT].instance_variable_get(:@pokemonData)["Normal Form"]   # back to plain data for the rest
check "error toasts stay short", PokeRPGLink.short_error(RuntimeError.new("undefined method `x' for #<MonWrapper:0x1 @flags={} @a=" + "y" * 500 + ">")).length <= 141
tm = JSON.parse(File.read(File.join(PokeRPGLink.dir, "map.json")))
check "town map regions+points", tm["regions"][0]["image"].end_with?("FullMap_1.PNG") && tm["points"].length == 2
check "fly flags", tm["points"].find { |p| p["x"] == 22 }["visited"] == true && tm["points"].find { |p| p["x"] == 20 }["visited"] == false

# --- battle ---
scene = PokeBattle_Scene.new
battle = PokeBattle_Battle.new
scene.pbStartBattle(battle)
send_cmd("save"); frames(4)
check "field actions blocked in battle", PokeRPGLink.field_queue.empty?

# Command menu: tap Run (3)
send_cmd("bcmd 3")
r = scene.pbCommandMenuEx(0, [])
check "tap Run returns 3", r == 3

# Tap a move while on the command menu: should open Fight then pick move 2
send_cmd("bmove 2")
r1 = scene.pbCommandMenuEx(0, [])
check "move tap opens Fight first", r1 == 0
r2 = scene.pbFightMenu(0)
check "then picks move 2", r2 == 2

# Mega flag presses X before C
$mega_pressed = false
send_cmd("bmove 1 mega")
scene.pbCommandMenuEx(0, [])
r3 = scene.pbFightMenu(0)
check "special toggle pressed then move 1", $mega_pressed && r3 == 1

# Spamming taps: once a move is chosen, more battle taps are ignored until the game asks again
send_cmd("bmove 2"); send_cmd("bmove 3"); frames(10)
check "taps after a chosen move are not queued for later turns", PokeRPGLink.battle_queue.empty?
old = Dir.children(File.join(PokeRPGLink.dir, "cmd")).length
File.write(File.join(PokeRPGLink.dir, "cmd", format("%015d_00001.cmd", (Time.now.to_f * 1000).to_i - 9000)), "save")
frames(6)
check "old taps are dropped, not replayed", Dir.children(File.join(PokeRPGLink.dir, "cmd")).length == old && PokeRPGLink.instance_variable_get(:@field_queue).empty?

# Switch tap at the command menu -> opens Pokemon (2) then pbSwitch returns party index directly
send_cmd("bswitch 1")
r4 = scene.pbCommandMenuEx(0, [])
check "switch tap opens Pokemon", r4 == 2
check "pbSwitch returns chosen party index", scene.pbSwitch(0, false, true) == 1

# Forced switch: party screen already open, then tap
PokeRPGLink.in_switch = true
send_cmd("bswitch 1"); frames(10)
ps = PokemonScreen_Scene.new
ps.update
check "party screen selects slot", ps.sel == 1
check "auto Switch In", ps.pbShowCommands("x", []) == 0
PokeRPGLink.in_switch = false

# Battle state
PokeRPGLink.menu = :command; PokeRPGLink.menu_index = 0
frames(20)
b = state["battle"]
check "mode battle", state["mode"] == "battle"
check "weather + field", b["weather"]["id"] == "RAINDANCE" && b["field"]["name"] == "Electric Terrain"
check "field info boosts", b["field"]["info"]["boosts"].include?("Electric ×1.5")
check "side effects", b["sides"][0]["Reflect"] == 3 && b["sides"][0]["Spikes"] == 1 && !b["sides"][0].key?("StealthRock")
check "global effects", b["global"].map { |g| g["id"] } == ["MAGICROOM"]
mv = b["moves"].find { |m| m["name"] == "Thunderbolt" }
check "thunderbolt vs grimer neutral, field 1.5, stab", mv["vs"][0]["mult"] == 1.0 && mv["field"] == 1.5 && mv["stab"]
it = b["moves"].find { |m| m["name"] == "Iron Tail" }
check "iron tail vs poison neutral", it["vs"][0]["mult"] == 1.0
tw = b["moves"].find { |m| m["name"] == "Thunder Wave" }
check "status move has no mult", tw["vs"][0]["mult"].nil?
foe = b["battlers"].find { |x| !x["own"] }
check "foe hp pct + stages + effects", foe["hpPct"] == 75 && foe["stages"]["atk"] == 1 && foe["stages"]["spe"] == -1 && foe["effects"] == ["Confusion"]
check "battle party list", b["party"].length == 2 && b["party"][0]["inBattle"]
# --- double battle targeting ---
dbl = PokeBattle_Battle.new
dbl.doublebattle = true
foe2 = FakeMon.new(:ZUBAT, 10, [:QUICKATTACK])
dbl.battlers[2] = Battler.new(2, $Trainer.party[1], 1)
dbl.battlers[3] = Battler.new(3, foe2, 1)
scene2 = PokeBattle_Scene.new
scene2.pbStartBattle(dbl)
PokeRPGLink.menu = :command; PokeRPGLink.menu_index = 0
frames(20)
bd = JSON.parse(File.read(File.join(PokeRPGLink.dir, "state.json")))["battle"]
qa = bd["moves"].find { |m| m["name"] == "Quick Attack" }
check "single-target move lists valid targets (foes + ally)", qa["pick"].sort == [1, 2, 3]
tb = bd["moves"].find { |m| m["name"] == "Thunderbolt" }
check "spread move has no picker", tb["pick"].nil?
check "effectiveness vs all others incl ally", qa["vs"].map { |v| v["index"] }.sort == [1, 2, 3]

send_cmd("bmove 1 t=3")
scene2.pbCommandMenuEx(0, [])
scene2.pbFightMenu(0)
check "pre-picked target returned without cursor", scene2.pbChooseTarget(0) == 3

# game opens the cursor first, then the player taps a target on the 5th frame
PokeRPGLink.instance_variable_set(:@pending_target, nil)
cnt = 0
orig = PokeRPGLink.method(:target_frame)
PokeRPGLink.define_singleton_method(:target_frame) do |sc|
  cnt += 1
  PokeRPGLink.handle(["btarget", "2"]) if cnt == 5
  orig.call(sc)
end
check "tap on target during cursor finishes it", scene2.pbChooseTarget(0) == 2
check "menu reset after targeting", PokeRPGLink.menu == :none
# a tap on yourself (invalid for a single-target move) is ignored; B then leaves
cnt = 0
PokeRPGLink.define_singleton_method(:target_frame) do |sc|
  cnt += 1
  PokeRPGLink.handle(["btarget", "0"]) if cnt == 5
  PokeRPGInput.press("B") if cnt == 10
  orig.call(sc)
end
res = scene2.pbChooseTarget(0)
check "invalid target ignored", res == -1
PokeRPGLink.define_singleton_method(:target_frame) { |sc| orig.call(sc) }
scene2.pbEndBattle(0)
scene.pbStartBattle(battle)
# Shadow foe, boss shields, real menu labels ("Call"), field add-on type
foe_mon = battle.battlers[1].pokemon
def foe_mon.isShadow?; true; end
def foe_mon.heartStage; 4; end
bb = battle.battlers[1]
def bb.isbossmon; true; end
def bb.shieldCount; 2; end
send_cmd("bcmd 3")
scene.pbCommandMenuEx(0, ["What will Pikachu do?", "Fight", "Bag", "Pokémon", "Call"])
PokeRPGLink.menu = :command
frames(20)
b2 = state["battle"]
fb = b2["battlers"].find { |x| !x["own"] }
check "shadow foe flagged with heart stage", fb["shadow"] == { "stage" => 4, "max" => 5 }
check "boss shields exported", fb["boss"]["shields"] == 2
check "menu labels exported (Call)", b2["commands"] == ["Fight", "Bag", "Pokémon", "Call"]
qa2 = b2["moves"].find { |m| m["name"] == "Quick Attack" }
check "field adds Electric to Quick Attack; effectiveness uses both types", qa2["fieldType"] == "Electric" && qa2["vs"][0]["mult"] == 1.0
check "field accuracy change", b2["moves"].find { |m| m["name"] == "Iron Tail" }["fieldAcc"] == 50
check "field summary lists type add-ons + accuracy", b2["field"]["info"]["typeAdds"][0].include?("also Electric") && b2["field"]["info"]["accuracy"][0].include?("50%")
# Catch-all: battle log, other effects, extensions
scene.pbDisplayMessage("The field is \\c[2]hyper-charged!\\wt[10]")
scene.pbDisplayMessage("Grimer's Stench activated!")
bb.effects[:MagicCoat] = true
FileUtils.mkdir_p(File.join(PokeRPGLink.dir, "extensions"))
File.write(File.join(PokeRPGLink.dir, "extensions", "demo.rb"), <<~RB)
  PokeRPGLink.watch_variable(5, "Karma")
  PokeRPGLink.add_state("rift") { |st| { "energy" => 3 } }
  PokeRPGLink.add_command("hello") { |args| $hello = args }
RB
PokeRPGLink.load_extensions
send_cmd("ext hello world")
frames(20)
st3 = state
check "battle log captures messages, control codes stripped", st3["battle"]["log"].map { |l| l["text"] } == ["The field is hyper-charged!", "Grimer's Stench activated!"]
check "uncommon effects reported as otherEffects", st3["battle"]["battlers"].find { |x| !x["own"] }["otherEffects"].include?("MagicCoat")
check "extension state + watched variable", st3["ext"]["rift"] == { "energy" => 3 } && st3["watch"][0] == { "label" => "Karma", "value" => 12, "kind" => "var" }
check "extension command", $hello == ["world"]
# ---- level-up crash regression: the game's pbDisplayPausedMessage takes ONE argument
battle.scene = scene
crashed = begin; battle.pbDisplayPaused("Pikachu learned Thunder!"); false; rescue ArgumentError; true; end
check "paused message passes through unchanged (level-up crash fixed)", !crashed
# …and if the game (or another mod) redefines it later, we still reach the new version
class PokeBattle_Scene; def pbDisplayPausedMessage(msg, extra = :x); @paused2 = [msg, extra]; end; end
crashed = begin; scene.pbDisplayPausedMessage("A", :b); false; rescue ArgumentError; true; end
check "later redefinitions are respected", !crashed && scene.instance_variable_get(:@paused2) == ["A", :b]
# …and a caller handing over more than the game's method takes (Rejuvenation 14 on Kirin) is trimmed
class PokeBattle_Scene; def pbDisplayPausedMessage(msg); @paused3 = msg; end; end
crashed = begin; scene.pbDisplayPausedMessage("B", :extra, :more); false; rescue ArgumentError; true; end
check "extra arguments trimmed to what the game accepts", !crashed && scene.instance_variable_get(:@paused3) == "B"

# ---- panel bag in battle
$Trainer.party[0].hp = 10
frames(20)
bagst = state
pot = bagst["bag"].flat_map { |p| p["items"] }.find { |i| i["id"] == "POTION" }
xat = bagst["bag"].flat_map { |p| p["items"] }.find { |i| i["id"] == "XATTACK" }
bic = bagst["bag"].flat_map { |p| p["items"] }.find { |i| i["id"] == "BICYCLE" }
check "item kinds exported", pot["battle"] == "pokemon" && pot["field"] == "pokemon" && xat["battle"] == "battler" && bic["battle"].nil?
send_cmd("bitem POTION 0")
cmd = scene.pbCommandMenuEx(0, [])
res = scene.pbItemMenu(0)
check "Bag pressed for the panel item", cmd == 1
check "item menu returns panel choice without opening the bag", res == [:POTION, 0] && PokeBattle_Scene::ITEMMENU_OPENED.empty? && CONSUMED.last == :POTION
send_cmd("bitem XATTACK"); scene.pbCommandMenuEx(0, [])
check "battler item targets the active Pokémon", scene.pbItemMenu(0) == [:XATTACK, 0]
$Trainer.party[1].hp = $Trainer.party[1].totalhp
send_cmd("bitem POTION 1"); scene.pbCommandMenuEx(0, [])
check "useless item refused with the game's message", scene.pbItemMenu(0) == [nil, -1]
check "without a panel choice the game's bag opens", scene.pbItemMenu(0) == [nil, -1] && PokeBattle_Scene::ITEMMENU_OPENED == [0]

# ---- quick ball
frames(20)
bl = state["battle"]["balls"]
check "fallback = most plentiful ball (not Master Ball)", bl["quick"]["id"] == "POKEBALL" && bl["all"].length == 4
battle.pbThrowPokeBall(1, :MAGICBALL)
frames(20)
check "last thrown custom ball becomes the quick ball", state["battle"]["balls"]["quick"]["id"] == "MAGICBALL" && state["battle"]["balls"]["quick"]["last"]
$PokemonBag.pbDeleteItem(:MAGICBALL, 1)
frames(20)
check "falls back when you run out", state["battle"]["balls"]["quick"]["id"] == "POKEBALL"
send_cmd("bball"); scene.pbCommandMenuEx(0, [])
check "quick ball throw goes through the item menu", scene.pbItemMenu(0) == [:POKEBALL, 0]

scene.pbEndBattle(0)
frames(10)
check "back to map after battle", state["mode"] == "map"

# ---- field: use an item on a Pokémon chosen on the panel
$Trainer.party[0].hp = 5
send_cmd("useon POTION 0"); frames(4); $scene.update; frames(10)
check "field use on a chosen Pokémon (no party screen)", $Trainer.party[0].hp == 25 && state["toasts"].any? { |t| t["text"].include?("HP was restored") }

# Virtual buttons work anywhere
send_cmd("btn A")
hits = 0
12.times { Input.update; hits += 1 if Input.trigger?(Input::C) }
check "virtual A press registers once", hits == 1

File.write(File.expand_path("sample_map_state.json", __dir__), File.read(File.join(PokeRPGLink.dir, "state.json")))
puts "\nlog.txt:\n" + (File.read(File.join(PokeRPGLink.dir, "log.txt")) rescue "")
puts($fails.zero? ? "\nALL PASSED" : "\n#{$fails} FAILED")
exit($fails.zero? ? 0 : 1)
