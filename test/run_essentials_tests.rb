# Mock of a Pokémon Essentials v21-style game (GameData, Battle::Scene, $player, $bag)
# to exercise PokeRPGLink's Essentials adapter. Run: ruby test/run_essentials_tests.rb
require "json"
require "tmpdir"
require "fileutils"

Dir.chdir(Dir.mktmpdir("ess"))
FileUtils.mkdir_p("Graphics/Pokemon/Icons"); File.write("Graphics/Pokemon/Icons/PIKACHU.png", "x")
FileUtils.mkdir_p("Graphics/UI/Town Map"); File.write("Graphics/UI/Town Map/hoenn.png", "x")
FileUtils.mkdir_p("Data/Scripts/011_Battle")
File.write("Data/Scripts/011_Battle/001_PBEffects.rb", <<~RB)
  module PBEffects
    AquaRing = 0
    Confusion = 1
    LeechSeed = 2
    MagicCoat = 3
    FutureSightCounter = 0
    Reflect = 0
    Spikes = 1
    Rainbow = 2
    TrickRoom = 0
    Gravity = 1
  end
RB

module Input
  C = 13; B = 12; A = 11; X = 14; Y = 15; Z = 16; L = 17; R = 18; UP = 8; DOWN = 2; LEFT = 4; RIGHT = 6; CTRL = 21
  USE = C; BACK = B; ACTION = A
  @q = []
  def self.update; @now = @q.shift; end
  def self.trigger?(b); @now == b; end
  def self.press?(b); @now == b; end
  def self.repeat?(b); @now == b; end
end

module System; def self.game_title; "Pokémon Test Quest"; end; end
module Essentials; VERSION = "21.1"; end
module Settings; GAME_VERSION = "1.2.0"; end

module GameData
  class Base
    def self.store; @store ||= {}; end
    def self.add(id, **kw); o = new; o.instance_variable_set(:@id, id); kw.each { |k, v| o.instance_variable_set("@#{k}", v) }; store[id] = o; end
    def self.get(id); store[id] || raise("no #{id}"); end
    def self.try_get(id); store[id]; end
    def self.each(&b); store.values.each(&b); end
    attr_reader :id
    def method_missing(n, *a); instance_variable_get("@#{n}"); end
    def respond_to_missing?(*_); true; end
  end
  class Species < Base
    def self.each_species(&b); each(&b); end
    def self.icon_filename(sp, *a); "Graphics/Pokemon/Icons/#{sp}"; end
    def self.icon_filename_from_pokemon(p); icon_filename(p.species); end
    def self.front_sprite_filename(sp, *a); nil; end
    def species; @id; end
    def form; 0; end
  end
  class Type < Base; end
  class Item < Base
    def self.icon_filename(i); "Graphics/Items/#{i}"; end
    def is_key_item?; @key; end
    def is_mail?; false; end
    def is_poke_ball?; @ball ? true : false; end
    def is_important?; @key; end
  end
  class Ability < Base; end
  class Move < Base; end
  class Nature < Base; end
  class GrowthRate < Base; def minimum_exp_for_level(l); l ** 3; end; end
  class MapMetadata < Base; end
  class Target < Base; end
  class TownMap < Base; end
  class Encounter < Base
    def self.get(map, ver = 0); store[map]; end
    def self.each_of_version(v, &b); each(&b); end
  end
end
GameData::Type.add(:ELECTRIC, name: "Electric"); GameData::Type.add(:NORMAL, name: "Normal"); GameData::Type.add(:FLYING, name: "Flying"); GameData::Type.add(:GROUND, name: "Ground")
GameData::Species.add(:PIKACHU, name: "Pikachu", types: [:ELECTRIC], base_stats: { HP: 35, ATTACK: 55, DEFENSE: 40, SPECIAL_ATTACK: 50, SPECIAL_DEFENSE: 50, SPEED: 90 }, abilities: [:STATIC], hidden_abilities: [], category: "Mouse", pokedex_entry: "Zap.", evolutions: [])
GameData::Species.add(:TAILLOW, name: "Taillow", types: [:NORMAL, :FLYING], base_stats: { HP: 40 }, abilities: [:STATIC], hidden_abilities: [], evolutions: [])
GameData::Species.add(:ZIGZAGOON, name: "Zigzagoon", types: [:NORMAL], base_stats: { HP: 38 }, abilities: [:STATIC], hidden_abilities: [], evolutions: [])
GameData::Species.add(:GEODUDE, name: "Geodude", types: [:GROUND], base_stats: { HP: 40 }, abilities: [:STATIC], hidden_abilities: [], evolutions: [])
GameData::Ability.add(:STATIC, name: "Static", description: "May paralyze.")
GameData::Item.add(:POTION, name: "Potion", description: "Heals 20 HP.", key: false, battle_use: 1, field_use: 1)
GameData::Item.add(:ULTRABALL, name: "Ultra Ball", description: "Good ball.", key: false, battle_use: 4, field_use: 0, ball: true)
GameData::Item.add(:DUSKBALL, name: "Dusk Ball", description: "Night ball.", key: false, battle_use: 4, field_use: 0, ball: true)
GameData::Item.add(:ORANBERRY, name: "Oran Berry", description: "Heals 10 HP.", key: false)
GameData::Item.add(:BICYCLE, name: "Bicycle", description: "Ride.", key: true)
GameData::Move.add(:THUNDERBOLT, name: "Thunderbolt", type: :ELECTRIC, category: 1, power: 90, accuracy: 100, priority: 0, description: "Zap", total_pp: 15)
GameData::Move.add(:QUICKATTACK, name: "Quick Attack", type: :NORMAL, category: 0, power: 40, accuracy: 100, priority: 1, description: "Fast", total_pp: 30)
GameData::Move.add(:DISCHARGE, name: "Discharge", type: :ELECTRIC, category: 1, power: 80, accuracy: 100, priority: 0, description: "Hits all", total_pp: 15)
GameData::Move.add(:FLY, name: "Fly", type: :FLYING, category: 0, power: 90, accuracy: 95, priority: 0, description: "Fly", total_pp: 15)
GameData::Nature.add(:TIMID, name: "Timid", stat_changes: [[:ATTACK, -10], [:SPEED, 10]])
GameData::GrowthRate.add(:Medium)
GameData::Target.add(:NearOther, num_targets: 1); GameData::Target.add(:AllNearOthers, num_targets: 2)
GameData::MapMetadata.add(7, outdoor_map: true, town_map_position: [0, 5, 6], town_map_size: nil)
GameData::TownMap.add(0, name: "Hoenn", filename: "hoenn.png", point: [[5, 6, "Route 101", "", nil, nil, nil], [3, 2, "Oldale Town", "", 12, 4, 5], [9, 9, "Petalburg", "", 20, 7, 7]])
GameData::Encounter.add(7, types: { Land: [[30, :ZIGZAGOON, 2, 3], [20, :ZIGZAGOON, 3, 4]], LandNight: [[10, :TAILLOW, 3, 3]], Water: [[60, :GEODUDE, 5, 10]] }, map: 7)

module Effectiveness
  NORMAL_EFFECTIVE_MULTIPLIER = 1.0
  def self.calculate(atk, *defs)
    m = 1.0
    defs.each { |d| m *= 0 if atk == :ELECTRIC && d == :GROUND; m *= 2 if atk == :ELECTRIC && d == :FLYING }
    m
  end
end
# laid out like the real file: battler block, position block, side block, field block — each from 0
module PBEffects
  AquaRing = 0; Confusion = 1; LeechSeed = 2; MagicCoat = 3
  FutureSightCounter = 0
  Reflect = 0; Spikes = 1; Rainbow = 2
  TrickRoom = 0; Gravity = 1
end
module PBDayNight; def self.isNight?(t); true; end; def self.isMorning?(t); false; end; def self.isEvening?(t); false; end; end
def pbGetTimeNow; Time.now; end
def pbGetMapNameFromId(id); "Route 101"; end

class Pokemon
  class Move
    attr_accessor :id, :pp
    def initialize(id); @id = id; @pp = 10; end
    def total_pp; 15; end
  end
  attr_accessor :species, :name, :level, :hp, :totalhp, :status, :moves, :item, :exp, :iv, :ev, :happiness, :mail
  attr_reader :attack, :defense, :spatk, :spdef, :speed
  def initialize(sp, lv, mv)
    @species = sp; @name = GameData::Species.get(sp).name; @level = lv; @hp = 20; @totalhp = 30; @status = :NONE
    @moves = mv.map { |m| Move.new(m) }; @exp = 200; @iv = { HP: 31, ATTACK: 1, DEFENSE: 2, SPECIAL_ATTACK: 3, SPECIAL_DEFENSE: 4, SPEED: 31 }; @ev = {}
    @attack = 10; @defense = 11; @spatk = 12; @spdef = 13; @speed = 14; @happiness = 70
  end
  def species_data; GameData::Species.get(@species); end
  def types; species_data.types; end
  def ability; GameData::Ability.get(:STATIC); end
  def nature; GameData::Nature.get(:TIMID); end
  def growth_rate; :Medium; end
  def egg?; false; end
  def shiny?; false; end
  def female?; false; end
  def male?; true; end
  def form; 0; end
  def hasMove?(m); @moves.any? { |x| x.id == m }; end
end

class Bag
  attr_reader :pockets
  def initialize; @pockets = [[], [[:POTION, 3], [:ORANBERRY, 1]], [], [[:ULTRABALL, 4], [:DUSKBALL, 9]], [], [], [], [], [[:BICYCLE, 1]]]; end
  def self.pocket_names; ["", "Items", "Medicine", "Balls", "TMs", "Berries", "Mail", "Battle", "Key Items"]; end
  def quantity(i); @pockets.flatten(1).find { |x| x[0] == i }&.last || 0; end
end
PokemonBag = Bag
class Player
  attr_accessor :party, :name, :money, :pokedex
  def seen?(s); [:PIKACHU, :ZIGZAGOON].include?(s); end
  def owned?(s); s == :PIKACHU; end
  def numbadges; 2; end
end
$player = Player.new; $player.name = "Leymo"; $player.money = 500
$player.party = [Pokemon.new(:PIKACHU, 12, [:THUNDERBOLT, :QUICKATTACK, :DISCHARGE]), Pokemon.new(:TAILLOW, 9, [:FLY])]
$Trainer = nil
$bag = Bag.new

class Game_Map; def map_id; 7; end; def name; "Route 101"; end; def width; 20; end; def height; 20; end; def events; {}; end; end
class Game_Player; def x; 1; end; def y; 1; end; def moving?; false; end; end
class Game_Temp; attr_accessor :message_window_showing, :fly_destination, :in_menu; end
class PokemonGlobalMetadata; attr_accessor :visitedMaps, :surfing, :encounter_version; def initialize; @visitedMaps = { 12 => true }; @encounter_version = 0; end; end
$game_map = Game_Map.new; $game_player = Game_Player.new; $game_temp = Game_Temp.new; $PokemonGlobal = PokemonGlobalMetadata.new
$game_system = nil
class Scene_Map; def update; end; end
$scene = Scene_Map.new
def pbMapInterpreterRunning?; false; end
SAVES = []; FLIGHTS = []
def pbSaveScreen; SAVES << 1; end
def pbFlyToNewLocation(pkmn, move = :FLY); FLIGHTS << [$game_temp.fly_destination, pkmn.name]; end
def pbCanFly?(pkmn); true; end
def pbGiveItemToPokemon(item, pkmn, scene, id); pkmn.item = item; scene.pbDisplay("#{pkmn.name} is now holding the #{GameData::Item.get(item).name}."); end
class PokemonParty_Scene
  attr_reader :sel
  def update; end
  def pbSelect(i); @sel = i; end
  def pbShowCommands(*a); :orig; end
end

# --- battle ---
class Battle
  class Field; attr_accessor :weather, :weatherDuration, :terrain, :terrainDuration, :effects; def initialize; @weather = :Rain; @weatherDuration = 4; @terrain = :Electric; @terrainDuration = 3; @effects = { PBEffects::TrickRoom => 2 }; end; end
  class Side; attr_accessor :effects; def initialize(e); @effects = e; end; end
  class Battler
    attr_accessor :index, :pokemon, :hp, :totalhp, :level, :name, :species, :stages, :effects, :moves, :status, :item
    def initialize(i, pk); @index = i; @pokemon = pk; @hp = pk.hp; @totalhp = pk.totalhp; @level = pk.level; @name = pk.name; @species = pk.species
      @stages = { ATTACK: 1, SPEED: -2 }; @effects = { PBEffects::Confusion => 3, PBEffects::LeechSeed => 0, PBEffects::MagicCoat => true }; @status = :PARALYSIS
      @moves = pk.moves.map { |m| BMove.new(m.id) }; end
    def fainted?; @hp <= 0; end
    def opposes?(i = 0); (@index & 1) != (i & 1); end
    def pbTypes(_x = false); @pokemon.types; end
    def ability; GameData::Ability.get(:STATIC); end
    def pbHasType?(t); pbTypes.include?(t); end
    def attack; 1; end; def defense; 1; end; def spatk; 1; end; def spdef; 1; end; def speed; 1; end
  end
  class BMove
    attr_reader :id, :pp, :total_pp
    def initialize(id); @id = id; @pp = 5; @total_pp = 15; end
    def type; GameData::Move.get(@id).type; end
    def power; GameData::Move.get(@id).power; end
    def pbCalcType(_u); type; end
    def pbTarget(_u); GameData::Target.get(@id == :DISCHARGE ? :AllNearOthers : :NearOther); end
  end
  class Scene
    attr_accessor :battle
    def pbStartBattle(b); @battle = b; end
    def pbEndBattle(r); end
    def pbFrameUpdate(cw = nil); end
    def pbUpdate(cw = nil); Input.update; pbFrameUpdate(cw); end
    W = Struct.new(:index)
    def pbCommandMenuEx(idx, texts, mode = 0)
      cw = W.new(0)
      300.times { pbUpdate(cw); return cw.index if Input.trigger?(Input::USE) }
      -99
    end
    def pbFightMenu(idx, mega = false)
      cw = W.new(0)
      300.times do
        pbUpdate(cw)
        if Input.trigger?(Input::USE)
          return if yield cw.index
        end
        $mega = true if Input.trigger?(Input::ACTION)
      end
    end
    def pbFirstTarget(idx, td); 1; end
    def pbChooseTarget(idx, td, vis = nil)
      cw = W.new(pbFirstTarget(idx, td))
      300.times { pbUpdate(cw); return cw.index if Input.trigger?(Input::USE); return -1 if Input.trigger?(Input::BACK) }
      -99
    end
    def pbPartyScreen(idx, can = false); :party_screen_opened; end
    def pbItemMenu(idx, first); $bag_opened = true; end
    def pbDisplayPausedMessage(msg); @p = msg; end
  end
  attr_accessor :battlers, :field, :sides, :turnCount
  def initialize(double)
    @battlers = [Battler.new(0, $player.party[0]), Battler.new(1, Pokemon.new(:TAILLOW, 8, [:QUICKATTACK]))]
    if double
      @battlers << Battler.new(2, $player.party[1]) << Battler.new(3, Pokemon.new(:GEODUDE, 8, [:QUICKATTACK]))
    end
    @double = double; @field = Field.new; @sides = [Side.new({ PBEffects::Reflect => 3 }), Side.new({ PBEffects::Spikes => 2, PBEffects::Rainbow => 4 })]; @turnCount = 1
  end
  def singleBattle?; !@double; end
  def trainerBattle?; true; end
  def pbCanMegaEvolve?(i); false; end
  def pbMoveCanTarget?(u, t, td); t != u; end
  def pbParty(i); $player.party; end
  def pbPlayerDisplayParty(i); $player.party; end
  def pbThrowPokeBall(idx, ball, rate = nil, show = false); $thrown = ball; end
end

SHOWN_V21 = []
def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil); SHOWN_V21 << message; :shown; end
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
