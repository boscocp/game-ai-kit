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
## Here there are thirty, and a reader can see all of them in one file.
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

## Checkers: a man of each side, and the crown a king wears on top of it.
const RED_MAN: String = ROOT + "checkers/red_man.png"
const WHITE_MAN: String = ROOT + "checkers/white_man.png"
const CROWN: String = ROOT + "checkers/crown.png"

## Noughts and crosses. Both are white, and the scene tints them.
const CROSS: String = ROOT + "tictactoe/cross.png"
const NOUGHT: String = ROOT + "tictactoe/nought.png"

# Every picture loaded so far, by folder and path. See `texture`.
static var _kept: Dictionary = {}


## Where a side's picture of a kind of piece lives. A side beyond the folders
## there are draws in the last one, as a missing colour used to: a presentation
## problem should not take the game down.
static func unit_path(faction: int, type_name: String) -> String:
	var side: String = SIDES[clampi(faction, 0, SIDES.size() - 1)]
	var file: String = UNIT_FILES.get(type_name, UNIT_FILES[NO_TYPE])
	return ROOT + "units/%s/%s" % [side, file]


## Every path in this table, so one test can hold that each one is a file.
static func every_path() -> Array[String]:
	var paths: Array[String] = []
	paths.append_array(TERRAIN)
	for faction: int in range(SIDES.size()):
		for type_name: String in UNIT_FILES:
			paths.append(unit_path(faction, type_name))
	paths.append_array([RED_MAN, WHITE_MAN, CROWN, CROSS, NOUGHT])
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
