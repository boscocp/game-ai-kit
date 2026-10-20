## Every picture the games draw, by the path it lives at.
##
## The paths are a contract, not a convenience: nothing else in the code
## names a picture. So the views ask this table, the table names a file, and
## swapping the file is the whole change.
##
## Every path here is a CC0 file, listed in `res://assets/LICENCES.md` with its
## pack and its sha256. A person may generate their own pictures (T31): they
## go under `GENERATED`, at the same path below it, and a picture there is
## drawn instead of the CC0 one. That folder is gitignored, so it is theirs;
## empty, the game is back on the CC0 art.
##
## Pictures arrive at whatever size their author drew them -- the pack's run
## from 16 to 100 pixels -- and each view scales to its own cell. A generated file
## at 512 pixels works unchanged.
##
## When not to use it: a game with hundreds of sprites, which wants Godot's
## own resources (`.tres` tile sets, `SpriteFrames`) edited in the editor.
## Here there are a few dozen, and thirty strips for the fighters, and a
## reader can see all of them in one file.
class_name Art
extends RefCounted

const ROOT: String = "res://assets/"

## Where a person's own pictures go, mirroring the paths below `ROOT`. A static
## variable rather than a constant only so a test can point it elsewhere.
static var generated: String = ROOT + "generated/"

## The ground, one picture per kind of tile, in the order `BoardView`'s atlas
## columns are numbered. A picture with see-through parts -- trees, a rock, a
## flag -- is drawn over open ground, so it never needs its own grass.
const TERRAIN: Array[String] = [
	ROOT + "terrain/plain.png",
	ROOT + "terrain/rough.png",
	ROOT + "terrain/wall.png",
	ROOT + "terrain/node.png",
	ROOT + "terrain/water.png",
	ROOT + "terrain/bridge.png",
	ROOT + "terrain/trees.png",
]

## The picture for a unit with no type, which is every unit on the skirmish
## board: they differ only in side.
const NO_TYPE: String = "soldier"

## One folder per side, by faction number: red is 0, blue is 1.
const SIDES: Array[String] = ["red", "blue"]

## One picture per kind of piece, by `UnitType.type_name`. Five types that walk
## are five silhouettes -- a truck, a rifleman, a gun, a boat, a tank -- and the
## three that stand are three buildings, so a reader tells them apart by shape
## before colour comes into it.
const UNIT_FILES: Dictionary = {
	"runner": "runner.png",
	"shield": "shield.png",
	"mortar": "mortar.png",
	"wader": "wader.png",
	"ram": "ram.png",
	"bolt tower": "bolt_tower.png",
	"watchtower": "watchtower.png",
	"workshop": "workshop.png",
	NO_TYPE: "soldier.png",
}

## The kinds that walk on legs, and the sheet each walks with (T33). A kind
## not here is drawn with its still picture: the machines, which have no legs
## to walk on, and the buildings, which do not move. A sheet is read through
## the frame table of where it came from -- see `sheet_for`.
const SHEET_FILES: Dictionary = {
	"shield": "shield_walk.png",
	NO_TYPE: "soldier_walk.png",
}

## The fighting scenario's fighters (T35): one strip per animation, each a
## row of cels cut from a CC0 template by `tools/fighters/crop.gd`.
## `FighterSprites` says which cels a strip holds; the template's sheets
## themselves are not in the repository, only the cuts.
const FIGHTERS: String = ROOT + "fighters/"

## Checkers: a man of each side, and the crown a king wears on top of it.
const RED_MAN: String = ROOT + "checkers/red_man.png"
const WHITE_MAN: String = ROOT + "checkers/white_man.png"
const CROWN: String = ROOT + "checkers/crown.png"

## Noughts and crosses. Both are white, and the scene tints them.
const CROSS: String = ROOT + "tictactoe/cross.png"
const NOUGHT: String = ROOT + "tictactoe/nought.png"

## The racing demo: a car in each colour, seen from above, nose up; the
## grass it is drawn on; and what stands beside the track.
const RACING_CARS: Array[String] = [
	ROOT + "racing/car_red.png",
	ROOT + "racing/car_blue.png",
	ROOT + "racing/car_yellow.png",
	ROOT + "racing/car_black.png",
]
const RACING_GRASS: String = ROOT + "racing/grass.png"
const RACING_SCENERY: Array[String] = [
	ROOT + "racing/tree_large.png",
	ROOT + "racing/tree_small.png",
	ROOT + "racing/tyres.png",
	ROOT + "racing/tribune.png",
]

# Every picture loaded so far, by folder and path. See `texture`.
static var _kept: Dictionary = {}
# Every sheet asked for so far, kept the same way and for the same reason.
static var _sheets: Dictionary = {}


## Where a side's picture of a kind of piece lives. A side beyond the folders
## there are draws in the last one, as a missing colour used to: a presentation
## problem should not take the game down.
static func unit_path(faction: int, type_name: String) -> String:
	var side: String = SIDES[clampi(faction, 0, SIDES.size() - 1)]
	var file: String = UNIT_FILES.get(type_name, UNIT_FILES[NO_TYPE])
	return ROOT + "units/%s/%s" % [side, file]


## The sheet a side's kind of piece walks with, or null for a kind drawn
## with its still picture.
##
## The table comes with the file: a person's generated sheet is the walk
## LoRA's 4 by 4, the committed one is the pack's 24 by 8, and reading either
## through the other's table draws slices of the wrong frames.
static func sheet_for(faction: int, type_name: String) -> UnitSheet:
	if not SHEET_FILES.has(type_name):
		return null
	var path: String = sheet_path(faction, type_name)
	var key: String = generated + "|" + path
	if not _sheets.has(key):
		_sheets[key] = _usable_sheet(faction, type_name, path)
	return _sheets[key]


## The frame table for the sheet at `path` when it is drawn from `drawn_from`:
## the pack's when that is the committed file itself, the generator's when it
## is a person's own.
static func table_for(path: String, drawn_from: String) -> UnitSheet:
	return UnitSheet.puny(path) if drawn_from == path else UnitSheet.generated(path)


## `sheet` when a picture `size` pixels across divides into its table, and
## null otherwise, so the unit is drawn with its still picture rather than
## with slices of the wrong frames. A person's own sheet is the one that can
## come out the wrong size; the committed ones are held by a test.
static func sheet_if_it_fits(sheet: UnitSheet, size: Vector2i) -> UnitSheet:
	return sheet if sheet.fits(size) else null


# The sheet to draw, or null for the still picture. A person who generated
# their own still picture of a kind, and no sheet, sees their picture: the
# pack's figure would otherwise hide what they made (T31's promise).
static func _usable_sheet(faction: int, type_name: String, path: String) -> UnitSheet:
	var still: String = unit_path(faction, type_name)
	var own_sheet: bool = resolve(path) != path
	if resolve(still) != still and not own_sheet:
		return null
	var sheet: UnitSheet = table_for(path, resolve(path))
	return sheet_if_it_fits(sheet, Vector2i(texture(path).get_size()))


## Where a side's sheet of a kind of piece lives, beside its still picture.
static func sheet_path(faction: int, type_name: String) -> String:
	var side: String = SIDES[clampi(faction, 0, SIDES.size() - 1)]
	return ROOT + "units/%s/%s" % [side, SHEET_FILES[type_name]]


## Where a character's strip for an animation or a move lives.
static func fighter_strip(character: String, animation: String) -> String:
	return FIGHTERS + "%s/%s.png" % [character, animation]


## Every path in this table that the generator (T31) can draw, so one test
## can hold that each is a file and the generator's manifest names exactly
## these. The racing pictures are left out: nothing generates them, and
## `racing_paths` lists them for the racing suite to hold instead.
static func every_path() -> Array[String]:
	var paths: Array[String] = []
	paths.append_array(TERRAIN)
	for faction: int in range(SIDES.size()):
		for type_name: String in UNIT_FILES:
			paths.append(unit_path(faction, type_name))
		for type_name: String in SHEET_FILES:
			paths.append(sheet_path(faction, type_name))
	paths.append_array([RED_MAN, WHITE_MAN, CROWN, CROSS, NOUGHT])
	return paths


## The racing demo's pictures, Kenney's and never generated.
static func racing_paths() -> Array[String]:
	var paths: Array[String] = []
	paths.append_array(RACING_CARS)
	paths.append_array(RACING_SCENERY)
	paths.append(RACING_GRASS)
	return paths


## A picture, as a texture any view can draw. Kept once loaded, for as long
## as the game runs.
##
## Kept, not merely loaded, and that is measured: a `_draw` that loads a
## texture, draws it and returns drops the last reference to it. The texture is
## freed, the draw command still names it, and on 4.7.2 the picture came out a
## white square -- for exactly the pieces no legend happened to be holding.
static func texture(path: String) -> Texture2D:
	# Kept by the folder a picture may come from as well as by its path, so a
	# view asking every frame does not ask the resource loader every frame --
	# 12.6 microseconds a call, measured -- and a test moving the folder still
	# gets the picture from the new one.
	var key: String = generated + "|" + path
	if not _kept.has(key):
		_kept[key] = load(resolve(path)) as Texture2D
	return _kept[key]


## The file a path is drawn from: the person's own picture when there is one
## at the same place under `generated`, the CC0 file otherwise. Asks the
## resource loader, not the disk, because a picture Godot has not imported
## cannot be loaded however present it is.
static func resolve(path: String) -> String:
	var own: String = generated + path.trim_prefix(ROOT)
	return own if ResourceLoader.exists(own) else path
