# Mock of Pokémon Tectonic (Essentials v19.1 rebuilt: PokeBattle_* classes, BattleEffect
# data, stat steps, Avatars, six-button battle menu). PokeRPGLink is loaded the way the
# app installs it: a loader plugin appended to Data/PluginScripts.rxdata by the
# Android app's PluginInjector (compiled and run here), which runs
# Plugins/PokeRPGLink/PokeRPGLink.rb.   Run: ruby test/run_tectonic_tests.rb
require "json"
require "tmpdir"
require "fileutils"
require "zlib"

ROOT = File.expand_path("..", __dir__)
GAME = Dir.mktmpdir("tect")
Dir.chdir(GAME)
FileUtils.mkdir_p("Data"); FileUtils.mkdir_p("Plugins/PokeRPGLink"); FileUtils.mkdir_p("Graphics/Pokemon/Icons")
File.write("Graphics/Pokemon/Icons/PIKACHU.png", "x")
File.write("release_version.txt", "3.2.2\n")
FileUtils.cp(File.join(ROOT, "mod/PokeRPGLink.rb"), "Plugins/PokeRPGLink/PokeRPGLink.rb")
# the game's own compiled plugins (one real-looking entry)
File.binwrite("Data/PluginScripts.rxdata", Marshal.dump([["Tectonic Battle", { :name => "Tectonic Battle", :credits => ["Zinnia"] },
  [["Main.rb", Zlib::Deflate.deflate("$tect_plugin = true")]]]]))

# --- run the Android app's injector on it ---
jdir = Dir.mktmpdir("inj")
src = File.join(jdir, "src/com/leymo/pokerpglink"); FileUtils.mkdir_p(src); FileUtils.mkdir_p(File.join(jdir, "out"))
FileUtils.cp(File.join(ROOT, "android/app/src/main/java/com/leymo/pokerpglink/PluginInjector.java"), src)
File.write(File.join(src, "Run.java"), "package com.leymo.pokerpglink; public class Run { public static void main(String[] a) throws Exception { PluginInjector.inject(new java.io.File(a[0])); PluginInjector.inject(new java.io.File(a[0])); System.out.println(PluginInjector.injected(new java.io.File(a[0]))); } }")
ok = system("javac -nowarn -d #{jdir}/out #{src}/*.java 2>/dev/null") && `java -cp #{jdir}/out com.leymo.pokerpglink.Run #{GAME} 2>/dev/null`.strip == "true"
abort "injector failed" unless ok

module Input
  C = 13; B = 12; A = 11; X = 14; Y = 15; Z = 16; L = 17; R = 18; UP = 8; DOWN = 2; LEFT = 4; RIGHT = 6; CTRL = 21
  USE = C; BACK = B; ACTION = A; SPECIAL = Z
  @q = []
  def self.update; @now = @q.shift; end
  def self.trigger?(b); @now == b; end
  def self.press?(b); @now == b; end
  def self.repeat?(b); @now == b; end
  def self.pressex?(*); false; end
end
module System; def self.game_title; "Project Chasm"; end; end
module Essentials; VERSION = "19.1"; end

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
    def self.icon_filename(sp, *a); "Graphics/Pokemon/Icons/#{sp}"; end
    def self.icon_filename_from_pokemon(p); icon_filename(p.species); end
    def self.front_sprite_filename(*); nil; end
    def species; @id; end
    def form; 0; end
  end
  class Type < Base; end
  class Item < Base
    def self.icon_filename(i); "Graphics/Items/#{i}"; end
    def is_key_item?; false; end
    def is_mail?; false; end
    def is_poke_ball?; @ball ? true : false; end
    def is_important?; false; end
  end
  class Ability < Base; end
  class Move < Base; end
  class Target < Base; end
  class BattleWeather < Base; end
  class Avatar < Base; end
  class BattleEffect < Base; end
  class Encounter < Base; def self.get(*); nil; end; end
end
GameData::Type.add(:ELECTRIC, name: "Electric"); GameData::Type.add(:NORMAL, name: "Normal"); GameData::Type.add(:FLYING, name: "Flying"); GameData::Type.add(:GROUND, name: "Ground")
GameData::Species.add(:PIKACHU, name: "Pikachu", types: [:ELECTRIC], base_stats: {}, abilities: [], hidden_abilities: [], evolutions: [])
GameData::Species.add(:TAILLOW, name: "Taillow", types: [:NORMAL, :FLYING], base_stats: {}, abilities: [], hidden_abilities: [], evolutions: [])
GameData::Species.add(:GEODUDE, name: "Geodude", types: [:GROUND], base_stats: {}, abilities: [], hidden_abilities: [], evolutions: [])
GameData::Ability.add(:STATIC, name: "Static", description: "May numb.")
GameData::Item.add(:POKEBALL, name: "Poké Ball", description: "Ball.", battle_use: 4, field_use: 0, ball: true)
GameData::Item.add(:ORANBERRY, name: "Oran Berry", description: "Heals.", battle_use: 0, field_use: 1)
GameData::Item.add(:LEFTOVERS, name: "Leftovers", description: "Heals a bit.", battle_use: 0, field_use: 0)
GameData::Move.add(:THUNDERBOLT, name: "Thunderbolt", type: :ELECTRIC, category: 1, power: 90, accuracy: 100, priority: 0, description: "Zap", total_pp: 15)
GameData::Move.add(:QUICKATTACK, name: "Quick Attack", type: :NORMAL, category: 0, power: 40, accuracy: 100, priority: 1, description: "Fast", total_pp: 30)
GameData::Move.add(:VOLTSTRIKE, name: "Volt Strike", type: :ELECTRIC, category: 3, power: 70, accuracy: 100, priority: 0, description: "Adaptive", total_pp: 10)
GameData::Target.add(:NearOther, num_targets: 1)
GameData::BattleWeather.add(:Moonglow, name: "Moonglow")
GameData::Avatar.add(:GEODUDE, num_phases: 3)
GameData::BattleEffect.add(:Confusion, name: "Confusion", info_displayed: true, type: :Integer)
GameData::BattleEffect.add(:Hidden, name: "Hidden", info_displayed: false, type: :Boolean)
GameData::BattleEffect.add(:Reflect, name: "Reflect", info_displayed: true, type: :Integer)
GameData::BattleEffect.add(:FlameSpikes, name: "Flame Spikes", info_displayed: true, type: :Integer)
GameData::BattleEffect.add(:InsightRoom, name: "Insight Room", info_displayed: true, type: :Integer)

module EffectHolder
  def eachEffect(only = false)
    @effects.each { |k, v| next if only && !(v == true || (v.is_a?(Integer) && v > 0)); yield k, v, GameData::BattleEffect.get(k) }
  end
end
module Effectiveness
  NORMAL_EFFECTIVE = 8
  def self.calculate(*); 8; end
end
def pbGetMapNameFromId(id); "Casaba Villa"; end
module PBDayNight; def self.isNight?(t); false; end; def self.isMorning?(t); false; end; def self.isEvening?(t); false; end; end
def pbGetTimeNow; Time.now; end

class Pokemon
  class Move
    attr_accessor :id, :pp
    def initialize(id); @id = id; @pp = 10; end
    def total_pp; 15; end
  end
  attr_accessor :species, :name, :level, :hp, :totalhp, :status, :moves, :items, :exp, :happiness
  def initialize(sp, lv, mv); @species = sp; @name = GameData::Species.get(sp).name; @level = lv; @hp = 20; @totalhp = 30; @status = :NONE
    @moves = mv.map { |m| Move.new(m) }; @items = []; @exp = 1; @happiness = 70; end
  def item; @items[0]; end
  def removeItem(i); @items.delete(i); end
  def species_data; GameData::Species.get(@species); end
  def types; species_data.types; end
  def ability; GameData::Ability.get(:STATIC); end
  def egg?; false; end
  def shiny?; false; end
  def form; 0; end
  def attack; 1; end; def defense; 1; end; def spatk; 1; end; def spdef; 1; end; def speed; 1; end
end
class PokemonBag
  attr_reader :pockets
  def initialize; @pockets = [[], [[:ORANBERRY, 2], [:LEFTOVERS, 1]], [[:POKEBALL, 5]]]; end
  def self.pocketNames; ["", "Items", "Balls"]; end
  def pbQuantity(i); @pockets.flatten(1).find { |x| x[0] == i }&.last || 0; end
  def pbStoreItem(i); @pockets[1] << [i, 1]; end
  def pbCanStore?(i); true; end
end
class PokeBattle_Trainer
  attr_accessor :party, :name, :money
  def seen?(s); true; end
  def owned?(s); s == :PIKACHU; end
  def numbadges; 1; end
end
$Trainer = PokeBattle_Trainer.new; $Trainer.name = "Leymo"; $Trainer.money = 100
$Trainer.party = [Pokemon.new(:PIKACHU, 12, [:THUNDERBOLT, :QUICKATTACK, :VOLTSTRIKE]), Pokemon.new(:TAILLOW, 9, [:QUICKATTACK])]
$Trainer.party[0].items = [:LEFTOVERS, :ORANBERRY]
$PokemonBag = PokemonBag.new
def pbTakeItemsFromPokemon(pkmn); pkmn.items.each { |i| $PokemonBag.pbStoreItem(i) }; n = pkmn.items.length; pkmn.items = []; n; end
def pbGiveItemToPokemon(item, pkmn, scene, from = true); pkmn.items << item; true; end
def pbMessage(*); end

class Game_Map; def map_id; 3; end; def name; "Casaba Villa"; end; def width; 20; end; def height; 20; end; def events; {}; end; end
class Game_Player; def x; 1; end; def y; 1; end; def moving?; false; end; end
class Game_Temp; attr_accessor :message_window_showing, :in_menu; end
class PokemonGlobalMetadata; attr_accessor :visitedMaps, :surfing, :encounter_version; def initialize; @visitedMaps = {}; end; end
$game_map = Game_Map.new; $game_player = Game_Player.new; $game_temp = Game_Temp.new; $PokemonGlobal = PokemonGlobalMetadata.new
class Scene_Map; def update; end; end
$scene = Scene_Map.new
def pbMapInterpreterRunning?; false; end
class PokemonParty_Scene; attr_reader :sel; def update; end; def pbSelect(i); @sel = i; end; def pbShowCommands(*a); :orig; end; end

class PokeBattle_ActiveField; include EffectHolder; attr_accessor :weather, :weatherDuration, :effects
  def initialize; @weather = :Moonglow; @weatherDuration = 3; @effects = { :InsightRoom => 2 }; end; end
class PokeBattle_ActiveSide; include EffectHolder; attr_accessor :effects; def initialize(e); @effects = e; end; end
class PokeBattle_Move
  attr_reader :id, :pp, :total_pp, :baseDamage
  def initialize(id); @id = id; @pp = 5; @total_pp = 15; @baseDamage = GameData::Move.get(id).power; end
  def type; GameData::Move.get(@id).type; end
  def category; GameData::Move.get(@id).category; end
  def calculatedCategory; category; end
  def pbCalcType(_u); type; end
  def pbTarget(_u); GameData::Target.get(:NearOther); end
  def pbCalcTypeMod(t, user, target, ui = false)
    tt = target.pbTypes(true)
    return 0 if t == :ELECTRIC && tt.include?(:GROUND)
    return 16 if t == :ELECTRIC && tt.include?(:FLYING)
    8
  end
end
class PokeBattle_Battler
  include EffectHolder
  attr_accessor :index, :pokemon, :hp, :totalhp, :level, :name, :species, :steps, :effects, :moves, :status, :bossStatus, :boss, :avatarPhase, :extraMovesPerTurn
  def initialize(i, pk); @index = i; @pokemon = pk; @hp = pk.hp; @totalhp = pk.totalhp; @level = pk.level; @name = pk.name; @species = pk.species
    @steps = { ATTACK: 2, SPEED: -1 }; @effects = { :Confusion => 2, :Hidden => true }; @status = :NUMB; @bossStatus = :NONE
    @moves = pk.moves.map { |m| PokeBattle_Move.new(m.id) }; @boss = false; @avatarPhase = 1; @extraMovesPerTurn = 0; end
  def getMoves; @moves; end
  def getStatuses; s = [@status]; s << @bossStatus if @boss; s; end
  def boss?; @boss; end
  def avatarData; GameData::Avatar.get(@species); end
  def fainted?; @hp <= 0; end
  def opposes?(i = 0); i = i.index if i.respond_to?(:index); (@index & 1) != (i & 1); end
  def pbTypes(_x = false, _y = false); @pokemon.types; end
  def ability; GameData::Ability.get(:STATIC); end
  def pbHasType?(t); pbTypes.include?(t); end
  def item; nil; end
  def attack; 1; end; def defense; 1; end; def spatk; 1; end; def spdef; 1; end; def speed; 1; end
end
class PokeBattle_Scene
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
  def pbCommandMenu(idx, first)
    pbCommandMenuEx(idx, ["", "Fight", "Dex", "Ball", "Pokémon", "Info", first ? "Run" : "Cancel"], 0)
  end
  def pbFightMenu(idx)
    cw = W.new(0)
    300.times { pbUpdate(cw); return if Input.trigger?(Input::USE) && yield(cw.index) }
  end
  def pbFirstTarget(idx, td); 1; end
  def pbChooseTarget(idx, td, vis = nil, dex = false); cw = W.new(1); 300.times { pbUpdate(cw); return cw.index if Input.trigger?(Input::USE) }; -99; end
  def pbPartyScreen(idx, can = false); :party; end
  def pbItemMenu(idx, first); $bag_opened = true; end
  def pbDisplayMessage(m, brief = false); end
  def pbDisplayPausedMessage(m); end
  def pbDisplayConfirmMessage(m); true; end
end
class PokeBattle_Battle
  attr_accessor :battlers, :field, :sides, :turnCount, :boss
  def initialize(boss)
    foe = PokeBattle_Battler.new(1, Pokemon.new(boss ? :GEODUDE : :TAILLOW, 8, [:QUICKATTACK]))
    if boss; foe.boss = true; foe.avatarPhase = 2; foe.extraMovesPerTurn = 1; foe.bossStatus = :DIZZY; end
    @battlers = [PokeBattle_Battler.new(0, $Trainer.party[0]), foe]
    @field = PokeBattle_ActiveField.new; @sides = [PokeBattle_ActiveSide.new({ :Reflect => 4 }), PokeBattle_ActiveSide.new({ :FlameSpikes => 1 })]
    @turnCount = 1; @boss = boss
  end
  def singleBattle?; true; end
  def trainerBattle?; false; end
  def bossBattle?; @boss; end
  def pbMoveCanTarget?(u, t, td); t != u; end
  def pbParty(i); $Trainer.party; end
  def pbPlayerDisplayParty(i); $Trainer.party; end
  def pbThrowPokeBall(idx, ball, *); $thrown = ball; end
end

# --- what the game does at startup: run every compiled plugin ---
Marshal.load(File.binread("Data/PluginScripts.rxdata")).each do |name, meta, scripts|
  scripts.each { |f, code| eval(Zlib::Inflate.inflate(code).force_encoding("UTF-8"), TOPLEVEL_BINDING, "[#{name}] #{f}") }
end

$fails = 0
def check(n, c); puts "#{c ? 'PASS' : 'FAIL'}  #{n}"; $fails += 1 unless c; end
def frames(n); n.times { Input.update }; end
def send_cmd(l); @n = (@n || 0) + 1; File.write(File.join(PokeRPGLink.dir, "cmd", format("%015d.cmd", @n)), l); end
def state; JSON.parse(File.read(File.join(PokeRPGLink.dir, "state.json"))); end

check "game's own plugin still runs", $tect_plugin == true
check "loader ran PokeRPGLink from Plugins/PokeRPGLink", defined?(PokeRPGLink::VERSION) && File.exist?("PokeRPGLink/log.txt")
check "tectonic adapter active", PokeRPGLink.tectonic? && PokeRPGLink.singleton_class.ancestors.include?(PokeRPGLink::TectMethods)
check "hooks installed", (%w[battle-start-end battle-command-menu battle-fight-menu battle-frame battle-target battle-switch battle-item-menu battle-messages input map] - PokeRPGLink.hooks_ok).empty?
puts "  failed: #{PokeRPGLink.hooks_failed.inspect}" unless PokeRPGLink.hooks_failed.empty?

frames(20)
s = state
check "title/family/version", s["game"]["title"] == "Pokémon Tectonic" && s["game"]["family"] == "tectonic" && s["game"]["version"] == "3.2.2"
p0 = s["party"][0]
check "several held items", p0["item"]["id"] == "LEFTOVERS" && p0["items"].map { |i| i["id"] } == ["LEFTOVERS", "ORANBERRY"]
check "bag pockets", s["bag"].map { |p| p["name"] } == ["Items", "Balls"]
send_cmd("takeitem 0"); frames(4); $scene.update
check "take items uses Tectonic's multi-item function", $Trainer.party[0].items.empty?
send_cmd("giveitem 1 ORANBERRY"); frames(4); $scene.update
check "give item", $Trainer.party[1].items == [:ORANBERRY]

# ---- wild battle
sc = PokeBattle_Scene.new
bt = PokeBattle_Battle.new(false)
sc.pbStartBattle(bt)
PokeRPGLink.menu = :command; PokeRPGLink.menu_index = 0
c = nil
send_cmd("bcmd 2"); c = sc.pbCommandMenu(0, true)
check "Pokémon → Tectonic menu slot 3", c == 3
send_cmd("bcmd 3"); c = sc.pbCommandMenu(0, true)
check "Run → slot 5", c == 5
r = nil
send_cmd("bmove 2"); c = sc.pbCommandMenu(0, true); sc.pbFightMenu(0) { |i| r = i; true }
check "panel move: Fight (slot 0) then move 2", c == 0 && r == 2
PokeRPGLink.menu = :command; frames(20)
b = state["battle"]
check "menu labels from the game", b["commands"] == ["Fight", "Ball", "Pokémon", "Run"]
check "weather by name", b["weather"]["name"] == "Moonglow" && b["weather"]["turns"] == 3
check "field/side effects from BattleEffect data", b["global"] == [{ "id" => "Insight Room", "turns" => 2 }] && b["sides"][0]["Reflect"] == 4 && b["sides"][1]["Flame Spikes"] == 1 && b["sidesAll"]
foe = b["battlers"].find { |x| x["index"] == 1 }
check "steps, Numb, effects (hidden ones skipped)", foe["stages"] == { "atk" => 2, "spe" => -1 } && foe["status"] == "NUMB" && foe["effects"] == ["Confusion"]
tb = b["moves"].find { |m| m["name"] == "Thunderbolt" }
check "effectiveness from the game's own calc (2x vs Flying)", tb["vs"][0]["mult"] == 2.0
check "adaptive category", b["moves"].find { |m| m["name"] == "Volt Strike" }["cat"] == "adaptive"
check "ball allowed in wild battles", !b["noBag"] && b["canRun"]
got = nil
send_cmd("bball"); c = sc.pbCommandMenu(0, true)
sc.pbItemMenu(0, true) { |*a| got = a; true }
check "quick ball: Ball button (slot 2) + game's block", c == 2 && got && got[0] == :POKEBALL && got[1] == 4 && got[2] == 1 && !$bag_opened
sc.pbEndBattle(0)

# ---- Avatar battle
bt2 = PokeBattle_Battle.new(true)
sc.pbStartBattle(bt2)
PokeRPGLink.menu = :command; PokeRPGLink.menu_index = 0
frames(20)
b = state["battle"]
av = b["battlers"].find { |x| x["index"] == 1 }
check "avatar: bars left, moves per turn, second status", av["boss"] == { "label" => "Avatar", "bars" => 2, "actions" => 2 } && av["status2"] == "DIZZY"
check "no ball / run vs avatars", b["noBag"] && !b["canRun"]
check "Electric vs Ground = 0", b["moves"].find { |m| m["name"] == "Thunderbolt" }["vs"][0]["mult"] == 0.0
sc.pbEndBattle(0)
frames(10)
check "back to map", state["mode"] == "map"
puts File.read(File.join(PokeRPGLink.dir, "log.txt")) rescue nil
puts($fails.zero? ? "\nALL PASSED" : "\n#{$fails} FAILED")
exit($fails.zero? ? 0 : 1)
