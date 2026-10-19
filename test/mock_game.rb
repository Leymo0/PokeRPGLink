# Minimal stand-ins for the Rejuvenation classes PokeRPGLink touches, so the mod
# can be loaded and exercised outside the game. Run: ruby test/mock_game.rb
require "json"
require "tmpdir"

GAME = Dir.mktmpdir("rejuv")
Dir.chdir(GAME)
%w[Graphics/Icons Graphics/Battlers Graphics/Pictures/RegionMap].each { |d| FileUtils.mkdir_p(d) } rescue nil
require "fileutils"
%w[Graphics/Icons Graphics/Battlers Graphics/Pictures/RegionMap].each { |d| FileUtils.mkdir_p(d) }
File.write("Graphics/Icons/iconPIKACHU.png", "x")
File.write("Graphics/Battlers/025.png", "x")
File.write("Graphics/Pictures/RegionMap/FullMap_1.PNG", "x")

module Input
  C = 13; B = 12; X = 14; Y = 15; Z = 16; L = 17; R = 18; UP = 8; DOWN = 2; LEFT = 4; RIGHT = 6; CTRL = 21; A = 11
  @pressed = []
  def self.feed(b); @pressed << b; end
  def self.update; @now = @pressed.shift; end
  def self.trigger?(b); @now == b; end
  def self.press?(b); @now == b; end
  def self.repeat?(b); @now == b; end
end

class PBStats; HP=0; ATTACK=1; DEFENSE=2; SPATK=3; SPDEF=4; SPEED=5; ACCURACY=6; EVASION=7; end
S = Struct
MonData   = S.new(:name, :dexnum, :Type1, :Type2, :BaseStats, :Abilities, :kind, :dexentry, :Height, :Weight, :evolutions)
MoveData  = S.new(:name, :type, :category, :basedamage, :accuracy, :maxpp, :priority, :desc)
TypeData  = S.new(:name, :weak, :resist, :immune)
ItemData  = S.new(:name, :desc, :flags) do
  def checkFlag?(f); (flags || {})[f]; end
end
AbilData  = S.new(:name, :desc)
MapMeta   = S.new(:Land, :Cave, :Water, :RockSmash, :OldRod, :GoodRod, :SuperRod, :Headbutt, :LandMorning, :LandDay, :LandNight, :Outdoor, :MapPosition)
FEDataS   = S.new(:name, :message)
TownPt    = S.new(:name, :poi, :flyData, :region)

class Cache
  attr_accessor :pkmn, :moves, :types, :items, :abil, :mapdata, :FEData, :town_map, :natures
end
$cache = Cache.new
$cache.pkmn = {
  PIKACHU: MonData.new("Pikachu", 25, :ELECTRIC, :ELECTRIC, [35,55,40,50,50,90], [:STATIC, :LIGHTNINGROD], "Mouse", "Stores electricity.", 4, 60, [[:RAICHU]]),
  GRIMER:  MonData.new("Grimer", 88, :POISON, :POISON, [80,80,50,40,50,25], [:STENCH], "Sludge", "Made of sludge.", 9, 300, []),
  ZUBAT:   MonData.new("Zubat", 41, :POISON, :FLYING, [40,45,35,30,40,55], [:INNERFOCUS], "Bat", "No eyes.", 8, 75, []),
  HOOTHOOT:MonData.new("Hoothoot", 163, :NORMAL, :FLYING, [60,30,30,36,56,50], [:INSOMNIA], "Owl", "Hoots.", 7, 212, []),
  GEODUDE: MonData.new("Geodude", 74, :ROCK, :GROUND, [40,80,100,30,30,20], [:STURDY], "Rock", "Rocks.", 4, 200, []),
}
$cache.moves = {
  THUNDERBOLT: MoveData.new("Thunderbolt", :ELECTRIC, :special, 90, 100, 15, 0, "May paralyze."),
  QUICKATTACK: MoveData.new("Quick Attack", :NORMAL, :physical, 40, 100, 30, 1, "Priority."),
  THUNDERWAVE: MoveData.new("Thunder Wave", :ELECTRIC, :status, 0, 90, 20, 0, "Paralyzes."),
  IRONTAIL:    MoveData.new("Iron Tail", :STEEL, :physical, 100, 75, 15, 0, "May lower Def."),
  FLY:         MoveData.new("Fly", :FLYING, :physical, 90, 95, 15, 0, "Flies."),
}
$cache.types = {
  ELECTRIC: TypeData.new("Electric", [:GROUND], [:ELECTRIC, :FLYING, :STEEL], []),
  NORMAL:   TypeData.new("Normal", [:FIGHTING], [], [:GHOST]),
  POISON:   TypeData.new("Poison", [:GROUND, :PSYCHIC], [:POISON, :GRASS], []),
  FLYING:   TypeData.new("Flying", [:ELECTRIC, :ROCK, :ICE], [:GRASS], [:GROUND]),
  ROCK:     TypeData.new("Rock", [:WATER, :GRASS], [:NORMAL, :FLYING], []),
  GROUND:   TypeData.new("Ground", [:WATER, :GRASS, :ICE], [:POISON, :ROCK], [:ELECTRIC]),
  STEEL:    TypeData.new("Steel", [:FIRE, :GROUND], [:NORMAL], [:POISON]),
}
$cache.items = { POTION: ItemData.new("Potion", "Heals 20 HP.", { medicine: true }), LIGHTBALL: ItemData.new("Light Ball", "Pikachu item."),
                 BICYCLE: ItemData.new("Bicycle", "Ride.", { keyitem: true, noUseInBattle: true }),
                 POKEBALL: ItemData.new("Poké Ball", "Catches.", { ball: true }), GREATBALL: ItemData.new("Great Ball", "Better.", { ball: true }),
                 MAGICBALL: ItemData.new("Magic Ball", "A custom ball.", { ball: true }), MASTERBALL: ItemData.new("Master Ball", "Never fails.", { ball: true }),
                 XATTACK: ItemData.new("X Attack", "Raises Attack.", { battleitem: true }), REPEL: ItemData.new("Repel", "Repels.") }
def pbGetPocket(i); f = $cache.items[i].flags || {}; return 2 if f[:medicine]; return 3 if f[:ball]; return 7 if f[:battleitem]; return 8 if f[:keyitem]; 1; end
def pbIsPokeBall?(i); i && ($cache.items[i].flags || {})[:ball] ? true : false; end
def pbIsTM?(i); false; end
CONSUMED = []
def pbConsumeItemInBattle(bag, item); CONSUMED << item; bag.pbDeleteItem(item) unless [3, 8].include?(pbGetPocket(item)); end
module ItemHandlers
  UseOnPokemon = { POTION: ->(item, pkmn, scene) { pkmn.hp = [pkmn.hp + 20, pkmn.totalhp].min; scene.pbDisplay("#{pkmn.name}'s HP was restored."); true } }
  UseFromBag = { REPEL: ->(i) { 1 } }
  UseInField = {}
  def self.hasBattleUseOnPokemon(i); i == :POTION; end
  def self.hasBattleUseOnBattler(i); [:XATTACK, :POKEBALL, :GREATBALL, :MAGICBALL, :MASTERBALL].include?(i); end
  def self.triggerUseOnPokemon(item, pkmn, scene); UseOnPokemon[item] ? UseOnPokemon[item].call(item, pkmn, scene) : false; end
end
def pbUseItemOnPokemon(item, pokemon, scene)
  ret = ItemHandlers.triggerUseOnPokemon(item, pokemon, scene)
  $PokemonBag.pbDeleteItem(item) if ret
  ret
end
$cache.abil = { STATIC: AbilData.new("Static", "May paralyze on contact."), STENCH: AbilData.new("Stench", "Flinch."), INNERFOCUS: AbilData.new("Inner Focus", "No flinch."), STURDY: AbilData.new("Sturdy", "Survive OHKO."), LIGHTNINGROD: AbilData.new("Lightning Rod", "Draws Electric moves.") , INSOMNIA: AbilData.new("Insomnia","No sleep.")}
$cache.mapdata = {
  5 => MapMeta.new({ PIKACHU: [[20, 3, 5], [10, 4, 6]], GRIMER: [[30, 4, 5]] }, nil, { GEODUDE: [[50, 10, 12]] }, nil, nil, nil, nil, nil, nil,
                   { ZUBAT: [[20, 3, 4]] }, { HOOTHOOT: [[25, 3, 5]] }, true, [0, 22, 29])
}
$cache.FEData = { ELECTERRAIN: FEDataS.new("Electric Terrain", ["The field is hyper-charged!"]) }
$cache.town_map = { 0 => { name: "Floria Island", filename: "FullMap_1.PNG" },
                    [22, 29] => TownPt.new("East Gearen City", "Gearen Lab", [58, 42, 50], 0),
                    [20, 29] => TownPt.new("West Gearen City", "Power Plant", [238, 35, 17], 0) }
$cache.natures = {}

FIELDEFFECTS = { ELECTERRAIN: { typeBoosts: { 1.5 => [:ELECTRIC] }, damageMods: { 1.5 => [:SURF] }, fieldChange: { INDOOR: [:MUDSPORT] }, mimicry: :ELECTRIC, naturePower: :THUNDERBOLT,
                                 typeMods: { ELECTRIC: [:QUICKATTACK] }, accuracyMods: { 50 => [:IRONTAIL] } } }

def getMoveName(m); $cache.moves[m] ? $cache.moves[m].name : m.to_s; end
def getItemName(i); $cache.items[i].name; end
def pbItemIconFile(i); "Graphics/Icons/#{i}"; end
def pbCheckPokemonIconFiles(p, egg = false); "Graphics/Icons/icon#{p[0]}"; end
def pbGetMapNameFromId(id); "Route 1"; end
def pbPocketNames; ["", "Items", "Medicine", "Poké Balls", "TMs", "Berries", "Enh", "Battle", "Key Items"]; end
def pbIsKeyItem?(i); i == :BICYCLE; end
def pbIsMail?(i); false; end
def pbIsImportantItem?(i); i == :BICYCLE; end
def pbGetTimeNow; Time.now; end
module PBDayNight; def self.isNight?(t); true; end; def self.isMorning?(t); false; end; def self.isEvening?(t); false; end; end
module PBExperience; def self.pbGetStartExperience(l, g); l ** 3; end; end

class PBMove
  attr_accessor :move, :pp
  def initialize(m); @move = m; @pp = 10; end
  def totalpp; 15; end
end

class FakeMon
  attr_accessor :species, :name, :level, :hp, :totalhp, :status, :moves, :item, :ability, :nature, :form, :mail, :zmoves
  attr_accessor :attack, :defense, :spatk, :spdef, :speed, :iv, :ev, :exp, :happiness, :ot, :ballused
  def initialize(sp, lv, moves, item = nil)
    @species = sp; @name = $cache.pkmn[sp].name; @level = lv; @hp = 30; @totalhp = 40; @status = nil
    @moves = moves.map { |m| PBMove.new(m) }; @item = item; @ability = $cache.pkmn[sp].Abilities[0]; @nature = :TIMID; @form = 0
    @attack = 30; @defense = 25; @spatk = 40; @spdef = 30; @speed = 50; @iv = [31] * 6; @ev = [0] * 6; @exp = 130; @happiness = 70
  end
  def type1; $cache.pkmn[@species].Type1; end
  def type2; $cache.pkmn[@species].Type2; end
  def isEgg?; false; end
  def isShiny?; false; end
  def isFemale?; false; end
  def gender; 0; end
  def growthrate; :Medium; end
  def getFormName; nil; end
  def SpeciesCompatible?(m); true; end
end

class Bag
  attr_reader :pockets
  def initialize; @pockets = [[], [:REPEL], [:POTION], [:POKEBALL, :GREATBALL, :MAGICBALL, :MASTERBALL], [], [], [], [:XATTACK], [:BICYCLE]]; @q = { POTION: 3, BICYCLE: 1, LIGHTBALL: 1, POKEBALL: 10, GREATBALL: 2, MAGICBALL: 1, MASTERBALL: 1, XATTACK: 1, REPEL: 2 }; end
  def pbQuantity(i); @q[i] || 0; end
  def pbDeleteItem(i, n = 1); @q[i] -= n; end
  def pbStoreItem(i, n = 1); @q[i] = (@q[i] || 0) + n; true; end
end

class Dex; attr_accessor :dexList, :seenCount, :ownedCount; end
class Trainer; attr_accessor :name, :money, :party, :pokedex; def numbadges; 3; end; end
$Trainer = Trainer.new
$Trainer.name = "Leymo"; $Trainer.money = 12345
$Trainer.party = [FakeMon.new(:PIKACHU, 12, [:THUNDERBOLT, :QUICKATTACK, :THUNDERWAVE, :IRONTAIL], :LIGHTBALL), FakeMon.new(:GEODUDE, 10, [:FLY])]
$Trainer.pokedex = Dex.new
$Trainer.pokedex.dexList = { PIKACHU: { seen?: true, owned?: true }, GRIMER: { seen?: true, owned?: false } }
$Trainer.pokedex.seenCount = 2; $Trainer.pokedex.ownedCount = 1
$PokemonBag = Bag.new

class GameMap; def map_id; 5; end; def name; "Route 1"; end; def events; {}; end; end
class GamePlayer; def x; 10; end; def y; 7; end; def moving?; false; end; end
class GameTemp; attr_accessor :message_window_showing; end
class GameScreen; def weather_type; 0; end; end
class PokemonGlobalMetadata; attr_accessor :visitedMaps, :surfing; def initialize; @visitedMaps = { 58 => true }; end; end
class PokemonTempS; attr_accessor :flydata, :begunNewGame; end
$game_map = GameMap.new; $game_player = GamePlayer.new; $game_temp = GameTemp.new; $game_screen = GameScreen.new
$PokemonGlobal = PokemonGlobalMetadata.new; $PokemonTemp = PokemonTempS.new
$game_switches = Hash.new(false)
$game_variables = { 5 => 12 }
$game_system = nil
class PokemonEncounters; attr_accessor :enctypes; end
$PokemonEncounters = nil

class Scene_Map; def update; end; end
$scene = Scene_Map.new
def pbMapInterpreterRunning?; false; end
SAVED = []
def pbSave; SAVED << true; true; end
def pbSEPlay(*a); end
FLOWN = []
module Kernel
  def self.pbCanUseHiddenMove?(p, m); true; end
  def self.pbUseHiddenMove(p, m); FLOWN << [$PokemonTemp.flydata, p.name]; true; end
end
class PokemonRegionMapScene
  def initialize(*a); end
  def getFlySpot(pos); d = $cache.town_map[pos]; d && !d.flyData.empty? ? d.flyData : nil; end
end

class PokemonScreen
  def initialize(scene, party); @scene = scene; @party = party; end
  def pbDisplay(t); @scene.pbDisplay(t); end
  def pbGiveItem(item, pkmn, id = 0)
    $PokemonBag.pbDeleteItem(item); $PokemonBag.pbStoreItem(pkmn.item) if pkmn.item; pkmn.item = item
    pbDisplay("#{pkmn.name} was given the #{getItemName(item)} to hold.\1"); true
  end
  def pbTakeItem(pkmn); $PokemonBag.pbStoreItem(pkmn.item); pbDisplay("Received the #{getItemName(pkmn.item)} from #{pkmn.name}."); pkmn.item = nil; end
end
class PokemonScreen_Scene
  attr_reader :sel
  def update; end
  def pbSelect(i); @sel = i; end
  def pbShowCommands(*a); :original; end
end

# --- battle mocks ---
class Side; attr_accessor :effects; def initialize; @effects = { Reflect: 3, Spikes: 1, StealthRock: false }; end; end
class GState; attr_accessor :effects; def initialize; @effects = { GRAVITY: 0, MAGICROOM: 2 }; end; end
class FieldS; attr_accessor :effect, :duration; def initialize; @effect = :ELECTERRAIN; @duration = 0; end; def isFieldEffect?; true; end; end
class BMove
  attr_reader :move, :pp, :totalpp, :type, :target
  def initialize(m); @move = m; @pp = 9; @totalpp = 15; @type = $cache.moves[m].type; @target = (m == :THUNDERWAVE ? :SingleNonUser : m == :QUICKATTACK ? :SingleNonUser : :AllOpposing); end
end
class Battler
  attr_accessor :index, :name, :species, :level, :hp, :totalhp, :status, :type1, :type2, :ability, :stages, :effects, :moves, :item, :pokemon, :pokemonIndex
  attr_accessor :attack, :defense, :spatk, :spdef, :speed, :form
  def initialize(i, mon, pi)
    @index = i; @pokemon = mon; @pokemonIndex = pi; @name = mon.name; @species = mon.species; @level = mon.level; @hp = mon.hp; @totalhp = mon.totalhp
    @type1 = mon.type1; @type2 = mon.type2; @ability = mon.ability; @stages = [0, 1, 0, 0, 0, -1, 0, 0]; @effects = { Confusion: 2, Substitute: 0 }
    @moves = mon.moves.map { |m| BMove.new(m.move) }; @item = mon.item; @attack = 30; @defense = 30; @spatk = 30; @spdef = 30; @speed = 30; @form = 0
  end
  def fainted; false; end
  def isFainted?; @hp <= 0; end
  def pbTarget(m); m.target; end
end
class PokeBattle_Battle
  attr_accessor :battlers, :field, :weather, :weatherduration, :sides, :state, :turncount, :opponent, :doublebattle, :partyorder, :cantescape, :trickroom
  def initialize
    foe = FakeMon.new(:GRIMER, 11, [:QUICKATTACK])
    @battlers = [Battler.new(0, $Trainer.party[0], 0), Battler.new(1, foe, 0), nil, nil]
    @field = FieldS.new; @weather = :RAINDANCE; @weatherduration = 3; @sides = [Side.new, Side.new]; @state = GState.new
    @turncount = 2; @opponent = nil; @doublebattle = false; @partyorder = [0, 1, 2, 3, 4, 5]; @trickroom = 0
  end
  def pbParty(i); $Trainer.party; end
  def pbCanSwitch?(*a); true; end
  def pbCanSwitchLax?(*a); true; end
  def pbCanMegaEvolve?(i); false; end
  def pbCanZMove?(i); false; end
  def pbCanUltraBurst?(i); false; end
  def pbDisplayPaused(msg); @scene.pbDisplayPausedMessage(msg); end
  attr_accessor :scene
  THROWN = []
  def pbThrowPokeBall(idx, ball, rareness = nil, showplayer = false); THROWN << ball; end
end
class CmdWindow; attr_accessor :index; def initialize; @index = 0; end; end
class FightWindow; attr_reader :index; def initialize; @index = 0; end; def setIndex(i); @index = i; true; end; end
class PokeBattle_Scene
  attr_accessor :battle
  def pbStartBattle(b); @battle = b; end
  def pbEndBattle(r); end
  def pbFrameUpdate(cw, update = true); end
  # Faithful-enough copies of the real loops: update input, frame update, read buttons.
  def pbCommandMenuEx(index, texts, mode = 0)
    cw = CmdWindow.new
    300.times { Input.update; pbFrameUpdate(cw); return cw.index if Input.trigger?(Input::C) }
    -99
  end
  def pbFightMenu(index)
    cw = FightWindow.new
    300.times do
      Input.update; pbFrameUpdate(cw)
      $mega_pressed = true if Input.trigger?(Input::X)
      return cw.index if Input.trigger?(Input::C)
      return -1 if Input.trigger?(Input::B)
    end
    -99
  end
  def pbSwitch(index, lax, cancancel); :opened_party_screen; end
  def pbDisplayMessage(msg, brief = false); end
  def pbDisplayPausedMessage(msg); @paused = msg; end            # one argument, like the real game
  ITEMMENU_OPENED = []
  def pbItemMenu(index); ITEMMENU_OPENED << index; [nil, -1]; end   # the game's own bag screen
  def pbCanUseBattleItem(pkmnid, item, screen)
    p = $Trainer.party[pkmnid]
    return true if item == :POTION && p.hp < p.totalhp
    screen.pbDisplay("It won't have any effect."); false
  end
  def pbUpdateSelected(i); @selected = i; end
  def pbChooseTarget(index)
    cur = 1
    300.times do
      Input.update; pbUpdateSelected(cur)
      return cur if Input.trigger?(Input::C)
      return -1 if Input.trigger?(Input::B)
    end
    -99
  end
end

load File.expand_path("../mod/PokeRPGLink.rb", __dir__)
