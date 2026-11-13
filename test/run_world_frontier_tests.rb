# Pokémon World Frontier (Essentials 21.1, battle facilities only) on top of the
# Essentials mock. Run: ruby test/run_world_frontier_tests.rb
$MOCK_TITLE = "Pokémon World Frontier"
require_relative "ess_mock"

# type chart data like v21's GameData::Type (defender's weaknesses/resistances/immunities)
GameData::Type.add(:ELECTRIC, name: "Electric", weaknesses: [:GROUND], resistances: [:ELECTRIC, :FLYING], immunities: [])
GameData::Type.add(:NORMAL, name: "Normal", weaknesses: [:FIGHTING], resistances: [], immunities: [:GHOST])
GameData::Type.add(:FLYING, name: "Flying", weaknesses: [:ELECTRIC, :ICE, :ROCK], resistances: [:GRASS], immunities: [:GROUND])
GameData::Type.add(:GROUND, name: "Ground", weaknesses: [:WATER, :GRASS, :ICE], resistances: [:ROCK], immunities: [:ELECTRIC])

$MAP_NAME = "Battle Cathedral"
class Game_Map; def name; $MAP_NAME; end; end
class Game_Temp; attr_accessor :battle_rules; end
class Player; attr_accessor :battle_points; end
$player.battle_points = 120

# the game's switch/variable names (RPG::System) — World Frontier is made in Spanish
SysData = Struct.new(:switches, :variables)
$data_system = SysData.new([nil, "Símbolo Torre", "Símbolo Catedral", "Modo fácil"], [nil, "Racha Catedral", "Ronda", "Sin usar"])
$game_switches = [nil, true, false, true]
$game_variables = [nil, 6, 3, 0]

# Essentials' BattleChallenge, trimmed to what the panel reads
class BattleChallengeData
  attr_accessor :battleNumber, :numRounds, :wins, :swaps, :inProgress
  def initialize; @battleNumber = 3; @numRounds = 7; @wins = 2; @swaps = 1; @inProgress = false; end
end
class BattleChallenge
  attr_accessor :currentChallenge, :streak, :best
  def initialize; @bc = BattleChallengeData.new; @currentChallenge = "cathedralsingle"; @streak = 6; @best = 12; end
  def pbInProgress?; @bc.inProgress; end
  def pbInChallenge?; pbInProgress?; end
  def battleNumber; @bc.battleNumber; end
  def getCurrentWins(c); @streak; end
  def getMaxWins(c); @best; end
  def start!; @bc.inProgress = true; end
  def stop!; @bc.inProgress = false; end
end
$challenge = BattleChallenge.new
def pbBattleChallenge; $challenge; end

load File.expand_path("../mod/PokeRPGLink.rb", __dir__)

$fails = 0
def check(n, c); puts "#{c ? 'PASS' : 'FAIL'}  #{n}"; $fails += 1 unless c; end
def frames(n); n.times { Input.update }; end
def state; JSON.parse(File.read(File.join(PokeRPGLink.dir, "state.json"))); end
def vs(b, move, idx); b["moves"].find { |m| m["name"] == move }["vs"].find { |v| v["index"] == idx }["mult"]; end

frames(20)
s = state
check "game family = world-frontier", s["game"]["family"] == "world-frontier"
f = s["frontier"]
check "frontier state in the lobby", f && f["game"] == true && f["inChallenge"] == false
check "facility from the map name, with rules and the Ace", f["facility"]["id"] == "cathedral" && f["facility"]["format"] == "Inverse" && f["facility"]["ace"] == 30
check "all nine challenges listed", f["facilities"].map { |x| x["id"] } == %w[world tower castle temple cathedral victini fortress cruise stadium]
check "World Stadium has no Ace", !f["facilities"].first.key?("ace")
check "symbols from named switches", f["symbols"] == ["Símbolo Torre"] && f["facilities"].find { |x| x["id"] == "tower" }["earned"] == true && f["facilities"].find { |x| x["id"] == "cathedral" }["earned"] == false
check "Battle Points", f["bp"] == 120
check "named counters (only non-zero ones)", f["info"] == [{ "label" => "Racha Catedral", "value" => 6 }, { "label" => "Ronda", "value" => 3 }]

# walk into a generically named battle room mid-challenge: the facility sticks
$challenge.start!
$MAP_NAME = "Battle Room"
frames(20)
f = state["frontier"]
check "facility remembered in a generic room", f["facility"] && f["facility"]["id"] == "cathedral"
check "challenge numbers", f["inChallenge"] && f["battle"] == 3 && f["rounds"] == 7 && f["streak"] == 6 && f["best"] == 12
check "swaps only shown at the Cruise", !f.key?("swaps")

# ---- inverse battle (Cathedral): the panel flips effectiveness
sc = Battle::Scene.new
bt = Battle.new(true)
sc.pbStartBattle(bt)
PokeRPGLink.menu = :command; PokeRPGLink.menu_index = 0
frames(20)
b = state["battle"]
check "battle marked inverse", b["inverse"] == true
check "Electric vs Flying flips 2 → ½", vs(b, "Thunderbolt", 1) == 0.5
check "Electric vs Ground flips immune → 2", vs(b, "Thunderbolt", 3) == 2.0
check "battle knows the facility and battle number", b["frontier"]["name"] == "Battle Cathedral" && b["frontier"]["battle"] == 7 && b["frontier"]["ace"] == false
sc.pbEndBattle(0); frames(10)

# ---- the Ace: battle 30
$challenge.streak = 29
sc = Battle::Scene.new; bt = Battle.new(true); sc.pbStartBattle(bt)
PokeRPGLink.menu = :command; PokeRPGLink.menu_index = 0
frames(20)
check "battle 30 is the Ace battle", state["battle"]["frontier"]["ace"] == true
sc.pbEndBattle(0); frames(10)

# ---- Battle Tower: normal chart, nothing flipped
$challenge.stop!; $challenge.streak = 4
$MAP_NAME = "Battle Tower"; frames(10)
$challenge.start!
sc = Battle::Scene.new; bt = Battle.new(true); sc.pbStartBattle(bt)
PokeRPGLink.menu = :command; PokeRPGLink.menu_index = 0
frames(20)
b = state["battle"]
check "tower: not inverse, normal effectiveness", !b["inverse"] && vs(b, "Thunderbolt", 1) == 2.0 && vs(b, "Thunderbolt", 3) == 0.0
check "tower: facility in battle", b["frontier"]["id"] == "tower"
sc.pbEndBattle(0); frames(10)

# ---- a game that flips the chart itself (battle rule + patched Effectiveness): keep its numbers
module Effectiveness
  class << self
    alias_method :orig_calculate, :calculate
    def calculate(atk, *defs)
      m = orig_calculate(atk, *defs)
      return m unless $game_temp.battle_rules && $game_temp.battle_rules["inverseBattle"]
      defs.inject(1.0) { |a, d| x = orig_calculate(atk, d); a * (x == 0 ? 2.0 : x == 2 ? 0.5 : x == 0.5 ? 2.0 : 1.0) }
    end
  end
end
$game_temp.battle_rules = { "inverseBattle" => true }
sc = Battle::Scene.new; bt = Battle.new(true); sc.pbStartBattle(bt)
PokeRPGLink.menu = :command; PokeRPGLink.menu_index = 0
frames(20)
b = state["battle"]
check "inverse from a battle rule", b["inverse"] == true
check "game's own flipped numbers are not flipped twice", vs(b, "Thunderbolt", 1) == 0.5 && vs(b, "Thunderbolt", 3) == 2.0
sc.pbEndBattle(0); frames(10)
$game_temp.battle_rules = nil

# ---- leaving the frontier: outside a challenge, on a map that isn't a facility
$challenge.stop!
$MAP_NAME = "Hotel"
frames(20)
f = state["frontier"]
check "lobby-only: no facility, still World Frontier", f && f["game"] && !f.key?("facility") && !f["inChallenge"]

puts File.read(File.join(PokeRPGLink.dir, "log.txt")) rescue nil
puts($fails.zero? ? "\nALL PASSED" : "\n#{$fails} FAILED")
exit($fails.zero? ? 0 : 1)
