# Same mock game, but shaped like Pokémon Reborn / Desolation
# (classic town map layout, no getFlySpot, Reborn constants).
GAMETITLE = "Pokemon Reborn"
GAMEVERSION = "19.5.5"
Reborn = true
Rejuv = false
Desolation = false
require_relative "mock_game"
require "json"

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

class PokemonRegionMapScene; undef_method :getFlySpot; end
File.write("Graphics/Pictures/mapRegion0.png", "x")
$cache.town_map = [
  ["Reborn Region", "mapRegion0.png", [
    [10, 5, "Reborn City", "Grand Hall", 38, 12, 20],
    [14, 9, "Opal Ward", "", nil, nil, nil],
    [3, 2, "Azurine Island", "", 120, 4, 4]
  ]]
]
MapMetaR = Struct.new(:Land, :Cave, :Water, :RockSmash, :OldRod, :GoodRod, :SuperRod, :Headbutt, :LandMorning, :LandDay, :LandNight, :Outdoor, :MapPosition, :MapSize)
$cache.mapdata[5] = MapMetaR.new(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, true, [0, 10, 5], [2, "11"])
$PokemonGlobal.visitedMaps = { 38 => true }
class GameMap; def width; 40; end; def height; 20; end; end
class GamePlayer; def x; 30; end; def y; 3; end; end

frames(20)
st = JSON.parse(File.read(File.join(PokeRPGLink.dir, "state.json")))
check "game detected as Reborn", st["game"]["family"] == "reborn" && st["game"]["title"] == "Pokemon Reborn"
check "player square includes MapSize subdivision", st["map"]["pos"] == [0, 11, 5]

send_cmd("req map"); frames(4)
tm = JSON.parse(File.read(File.join(PokeRPGLink.dir, "map.json")))
check "classic style + image path", tm["style"] == "classic" && tm["regions"][0]["image"] == "Graphics/Pictures/mapRegion0.png" && tm["regions"][0]["offset"] == 0
check "three points, two flyable", tm["points"].length == 3 && tm["points"].count { |p| p["fly"] } == 2
check "visited flags", tm["points"].find { |p| p["name"] == "Reborn City" }["visited"] && !tm["points"].find { |p| p["name"] == "Azurine Island" }["visited"]

send_cmd("fly 10 5 0"); frames(4); $scene.update
check "fly works with classic map", FLOWN.last && FLOWN.last[0] == [38, 12, 20]

puts($fails.zero? ? "\nALL PASSED" : "\n#{$fails} FAILED")
exit($fails.zero? ? 0 : 1)
