## The RTS's pictures: Bos Wars' sheets, when somebody has downloaded them.
##
## Referenced, never committed (ADR 0020): `art_sources.json` names every
## sheet's URL and sha256, `make rts-art` puts them in `build/rts-art/`, and
## this reads them from there with `Image.load_from_file` -- outside the
## project, so Godot never imports them and nothing of them can be exported.
## With the folder empty, `found` is false and the board draws shapes.
##
## Bos Wars paints each player's colour in four palette entries, 208 to 211,
## and recolours them per player at run time. A PNG loaded into an `Image`
## loses its palette, so the four colours are read from the file's own
## `PLTE` chunk first, and every pixel of exactly those colours is replaced
## by a shade of the side's.
##
## A unit's sheet has five columns -- north, north-east, east, south-east,
## south -- and the west half is the east half mirrored. Its rows are the
## animation's frames: the first standing, the next four walking.
##
## When not to use it: art that is part of the game. This is decoration a
## person chose to fetch; the game must play the same without it.
class_name RtsArt
extends RefCounted

const SOURCES_PATH: String = "res://game/rts/art_sources.json"
## Where `make rts-art` puts the sheets, from the project's own folder.
const FOLDER: String = "../build/rts-art"
## How many cells wide a building's picture is drawn; a unit's is one and a half.
const BUILDING_CELLS: float = 2.2
const UNIT_CELLS: float = 1.6
## Ticks a walking frame is shown.
const WALK_FRAME_TICKS: int = 8

## True when every sheet was found and loaded.
var found: bool = false

# kind -> the whole sheet, as loaded; kind -> its row in the manifest.
var _images: Dictionary = {}
var _sheets: Dictionary = {}
# [kind, side] -> {team colour, as RGBA32 -> the side's shade}: each
# sheet's own palette, since nothing promises they share one.
var _shades: Dictionary = {}
# [kind, side, column, row] -> one frame, recoloured: made the first time
# it is drawn. A frame is a few thousand pixels; a whole sheet recoloured
# at start was over a million for the lab alone, and held the window
# blank for seconds.
var _frames: Dictionary = {}


## Load what `make rts-art` downloaded, to be recoloured for `side_colours`.
func _init(side_colours: Array[Color]) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCES_PATH))
	_sheets = manifest["sheets"]
	var folder: String = ProjectSettings.globalize_path("res://").path_join(FOLDER)
	for kind: String in _sheets:
		var path: String = folder.path_join(kind + ".png")
		if not FileAccess.file_exists(path):
			return
		var image: Image = Image.load_from_file(path)
		image.convert(Image.FORMAT_RGBA8)
		_images[kind] = image
		var palette: Array[Color] = _palette_of(path)
		for side: int in range(side_colours.size()):
			_shades[[kind, side]] = _shades_for(palette, manifest["team_colour"], side_colours[side])
	found = true


## Draw `unit` (a snapshot's dictionary) centred on `centre` on `canvas`,
## facing `facing` (a direction, zero for none), walking or standing. A
## building is drawn at its stage of construction, read off its health,
## which rises as it goes up. False when there is no picture to draw, so
## the caller draws a shape instead.
func draw_unit(canvas: CanvasItem, unit: Dictionary, centre: Vector2, cell: float,
		facing: Vector2, walking: bool, tick: int) -> bool:
	var kind: String = unit["kind"]
	if not found or not _images.has(kind):
		return false
	var sheet: Dictionary = _sheets[kind]
	var frame := Vector2(sheet["frame"][0], sheet["frame"][1])
	var at: Vector2i = _building_frame(kind, unit) if int(sheet["directions"]) == 1 else Vector2i.ZERO
	var mirrored: bool = false
	if int(sheet["directions"]) > 1:
		var octant: int = _octant(facing)
		at = Vector2i(octant if octant <= 4 else 8 - octant, 1 + (tick / WALK_FRAME_TICKS) % 4 if walking else 0)
		mirrored = octant > 4
	var cells: float = UNIT_CELLS if int(sheet["directions"]) > 1 else BUILDING_CELLS
	var size: Vector2 = frame * (cell * cells / maxf(frame.x, frame.y))
	canvas.draw_texture_rect(_frame_of(kind, maxi(unit["side"], 0), at, mirrored), Rect2(centre - size / 2.0, size), false)
	return true


# Which frame of a building's sheet: its stages of construction run along
# the sheet, the finished building last; one going up shows the stage its
# health has reached.
func _building_frame(kind: String, unit: Dictionary) -> Vector2i:
	var frame := Vector2i(_sheets[kind]["frame"][0], _sheets[kind]["frame"][1])
	var columns: int = maxi(_images[kind].get_width() / frame.x, 1)
	var frames: int = columns * maxi(_images[kind].get_height() / frame.y, 1)
	var index: int = frames - 1
	if not unit["complete"]:
		var share: float = clampf(float(unit["health"]) / float(RtsKinds.of(kind, "health")), 0.0, 1.0)
		index = mini(floori(share * (frames - 1)), frames - 2)
	return Vector2i(index % columns, index / columns)


# The frame at `at` of `kind`'s sheet in `side`'s colours, turned to face
# west when `mirrored`, made once. Mirrored here and not by drawing into a
# rectangle of negative width: that draws nothing, and every unit walking
# west vanished.
func _frame_of(kind: String, side: int, at: Vector2i, mirrored: bool = false) -> Texture2D:
	var key: Array = [kind, side, at.x, at.y, mirrored]
	if not _frames.has(key):
		var frame := Vector2i(_sheets[kind]["frame"][0], _sheets[kind]["frame"][1])
		var image: Image = (_images[kind] as Image).get_region(Rect2i(at * frame, frame))
		if mirrored:
			image.flip_x()
		_frames[key] = ImageTexture.create_from_image(_recoloured(image, _shades.get([kind, side], {})))
	return _frames[key]


# 0 north, then clockwise to 7 north-west; facing nowhere is south.
static func _octant(facing: Vector2) -> int:
	if facing == Vector2.ZERO:
		return 4
	var angle: float = fposmod(atan2(facing.x, -facing.y), TAU)
	return int(round(angle / (TAU / 8.0))) % 8


# Bos Wars' team colours, entries `indexes` of `palette`, each mapped to a
# shade of `colour`: brightest first in the palette, and kept in that order.
static func _shades_for(palette: Array[Color], indexes: Array, colour: Color) -> Dictionary:
	var shades: Dictionary = {}
	for position: int in range(indexes.size()):
		if int(indexes[position]) < palette.size():
			shades[palette[int(indexes[position])].to_rgba32()] = colour.darkened(0.18 * position)
	return shades


# `image` with every pixel of a team colour painted in the side's shade.
static func _recoloured(image: Image, shades: Dictionary) -> Image:
	for index: int in range(image.get_width() * image.get_height() if not shades.is_empty() else 0):
		var at := Vector2i(index % image.get_width(), index / image.get_width())
		var pixel: Color = image.get_pixelv(at)
		var opaque: int = Color(pixel.r, pixel.g, pixel.b, 1.0).to_rgba32()
		if pixel.a > 0.0 and shades.has(opaque):
			image.set_pixelv(at, shades[opaque])
	return image


# The colours of the PNG's palette, in index order; empty for a PNG with none.
static func _palette_of(path: String) -> Array[Color]:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var colours: Array[Color] = []
	var at: int = 8
	while at + 8 <= bytes.size():
		var length: int = bytes.decode_u32(at)
		length = ((length & 0xff) << 24) | ((length & 0xff00) << 8) | ((length >> 8) & 0xff00) | ((length >> 24) & 0xff)
		if bytes.slice(at + 4, at + 8).get_string_from_ascii() == "PLTE":
			return _colours_in(bytes, at + 8, length)
		at += 12 + length
	return colours


# The `length` bytes from `start`, read three at a time as colours.
static func _colours_in(bytes: PackedByteArray, start: int, length: int) -> Array[Color]:
	var colours: Array[Color] = []
	for offset: int in range(start, start + length - 2, 3):
		colours.append(Color8(bytes[offset], bytes[offset + 1], bytes[offset + 2]))
	return colours
