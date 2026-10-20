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

# kind -> side -> Texture2D, and kind -> its row in the manifest.
var _textures: Dictionary = {}
var _sheets: Dictionary = {}


## Load what `make rts-art` downloaded, recoloured for `side_colours`.
func _init(side_colours: Array[Color]) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCES_PATH))
	_sheets = manifest["sheets"]
	var folder: String = ProjectSettings.globalize_path("res://").path_join(FOLDER)
	for kind: String in _sheets:
		var path: String = folder.path_join(kind + ".png")
		if not FileAccess.file_exists(path):
			return
		var by_side: Dictionary = {}
		for side: int in range(side_colours.size()):
			by_side[side] = _recoloured(path, _sheets[kind], manifest["team_colour"], side_colours[side])
		_textures[kind] = by_side
	found = true


## Draw `kind` of `side` centred on `centre` on `canvas`, facing `facing`
## (a direction, zero for none), walking or standing. False when there is no
## picture to draw, so the caller draws a shape instead.
func draw_unit(canvas: CanvasItem, kind: String, side: int, centre: Vector2, cell: float,
		facing: Vector2, walking: bool, tick: int) -> bool:
	if not found or not _textures.has(kind):
		return false
	var sheet: Dictionary = _sheets[kind]
	var frame := Vector2(sheet["frame"][0], sheet["frame"][1])
	var texture: Texture2D = _textures[kind].get(maxi(side, 0), _textures[kind][0])
	var column: int = 0
	var mirrored: bool = false
	var row: int = 0
	if int(sheet["directions"]) > 1:
		var octant: int = _octant(facing)
		column = octant if octant <= 4 else 8 - octant
		mirrored = octant > 4
		row = 1 + (tick / WALK_FRAME_TICKS) % 4 if walking else 0
	var source := Rect2(Vector2(column, row) * frame, frame)
	var cells: float = UNIT_CELLS if int(sheet["directions"]) > 1 else BUILDING_CELLS
	var size: Vector2 = frame * (cell * cells / maxf(frame.x, frame.y))
	var target := Rect2(centre - size / 2.0, size)
	if mirrored:
		target = Rect2(target.position + Vector2(size.x, 0.0), Vector2(-size.x, size.y))
	canvas.draw_texture_rect_region(texture, target, source)
	return true


# 0 north, then clockwise to 7 north-west; facing nowhere is south.
static func _octant(facing: Vector2) -> int:
	if facing == Vector2.ZERO:
		return 4
	var angle: float = fposmod(atan2(facing.x, -facing.y), TAU)
	return int(round(angle / (TAU / 8.0))) % 8


# The sheet at `path` with its team-colour pixels painted in `colour`. A
# building's sheet is cut to its first frame first, the only one drawn: the
# lab's sheet is a million pixels, and recolouring it whole took seconds.
func _recoloured(path: String, sheet: Dictionary, indexes: Array, colour: Color) -> Texture2D:
	var image: Image = Image.load_from_file(path)
	image.convert(Image.FORMAT_RGBA8)
	if int(sheet["directions"]) == 1:
		image = image.get_region(Rect2i(0, 0, sheet["frame"][0], sheet["frame"][1]))
	var palette: Array[Color] = _palette_of(path)
	var shades: Dictionary = {}
	for position: int in range(indexes.size()):
		var index: int = indexes[position]
		if index < palette.size():
			# Brightest first in Bos Wars' palette; keep that order in the new shades.
			shades[palette[index].to_rgba32()] = colour.darkened(0.18 * position)
	for index: int in range(image.get_width() * image.get_height() if not shades.is_empty() else 0):
		var at := Vector2i(index % image.get_width(), index / image.get_width())
		var pixel: Color = image.get_pixelv(at)
		var opaque: int = Color(pixel.r, pixel.g, pixel.b, 1.0).to_rgba32()
		if pixel.a > 0.0 and shades.has(opaque):
			image.set_pixelv(at, shades[opaque])
	return ImageTexture.create_from_image(image)


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
