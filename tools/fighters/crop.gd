# Cut the fighters' strips from the template's sheets (T35, ADR 0015).
#
# The sheets are not in the repository -- only what is cut from them. This is
# the cut, written down so anyone can repeat it: download the two sheets
# `godot/game/fighting/sprites.json` names, check each against its sha256,
# and lay the listed cels of each animation side by side, one strip a file,
# under `godot/assets/fighters/<character>/`.
#
#     make fighter-sheets     # download into build/fighter-sheets/ (gitignored)
#     make fighter-strips     # this script, then `make import`
#
# A cel is a whole cell of the sheet's grid, not the figure's bounding box:
# the template was rendered with a fixed camera, so a whole cell keeps the
# fighter's feet where they were and every cel lines up with every other.
#
# Exit codes: 0 every strip written, 1 a sheet's sha256 is not the table's,
# 2 a sheet or the table could not be read.
extends SceneTree

const OUT: String = "res://assets/fighters/"


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	quit(_run(arguments[0] if not arguments.is_empty() else ""))


func _run(sheets_folder: String) -> int:
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(FighterSprites.PATH))
	if sheets_folder == "" or not table is Dictionary:
		printerr("crop: usage: crop.gd -- <folder holding the downloaded sheets>")
		return 2
	var sheets: Dictionary = {}
	for name: String in table["sheets"]:
		var path: String = sheets_folder.path_join(name)
		if not FileAccess.file_exists(path):
			printerr("crop: %s is missing; run `make fighter-sheets`" % path)
			return 2
		if FileAccess.get_sha256(path) != table["sheets"][name]["sha256"]:
			printerr("crop: %s is not the sheet the table names: its sha256 differs" % path)
			return 1
		sheets[name] = Image.load_from_file(path)
	var written: int = 0
	for character: String in table["characters"]:
		written += _cut_character(table, character, sheets)
	print("crop: %d strips written under %s" % [written, OUT])
	return 0


# Every strip of one character. Returns how many were written.
func _cut_character(table: Dictionary, character: String, sheets: Dictionary) -> int:
	var drawn: Dictionary = table["characters"][character]
	var layout: Dictionary = table["sheets"][drawn["sheet"]]
	var sprites := FighterSprites.new()
	sprites.table = table
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + character))
	var animations: Array = drawn["animations"].keys() + drawn["moves"].keys()
	for animation: String in animations:
		var strip: Image = _strip(sheets[drawn["sheet"]], layout, sprites.cels(character, animation))
		strip.save_png(ProjectSettings.globalize_path(Art.fighter_strip(character, animation)))
	return animations.size()


# The listed cels of a sheet, side by side, whole cells.
static func _strip(sheet: Image, layout: Dictionary, cels: Array[int]) -> Image:
	var size := Vector2i(int(layout["cell"][0]), int(layout["cell"][1]))
	var columns: int = int(layout["columns"])
	var strip: Image = Image.create_empty(size.x * cels.size(), size.y, false, Image.FORMAT_RGBA8)
	var source: Image = sheet.duplicate() as Image
	source.convert(Image.FORMAT_RGBA8)
	for index: int in range(cels.size()):
		var at := Vector2i((cels[index] % columns) * size.x, (cels[index] / columns) * size.y)
		strip.blit_rect(source, Rect2i(at, size), Vector2i(index * size.x, 0))
	return strip
