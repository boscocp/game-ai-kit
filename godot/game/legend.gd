## What each colour on the screen means, drawn in a corner of every example.
##
## A coloured square means nothing to somebody who did not write it, and every
## example in the kit draws the AI's reasoning in coloured squares. So each
## one carries a legend, and `check_demos.py` refuses an example scene without
## one. Entries are a colour or a picture, and a few words; the legend draws a
## swatch and the words beside it, one per line. A picture is the tile or the
## piece itself, so the legend shows what is on the board rather than a colour
## standing for it. A clear colour draws the words alone, for a shape a swatch
## cannot show -- a dot, a ring, a tick.
class_name Legend
extends Control

## 16, not the 14 it was with flat colours: the pack's tiles are 16 pixels,
## and drawn at their own size they stay sharp.
const SWATCH: float = 16.0
const LINE: float = 20.0
const TEXT_SIZE: int = 14

# Open ground, under every translucent swatch. Made once, when first drawn.
var _ground: Texture2D

## Each entry is `[Color, String]` or `[Texture2D, String]`: the swatch and
## what it stands for.
var entries: Array[Array] = []


## Replace what the legend says. Called once, by the example that owns it.
func set_entries(new_entries: Array[Array]) -> void:
	entries = new_entries
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for index: int in range(entries.size()):
		var top: float = index * LINE
		var square := Rect2(0.0, top + 2.0, SWATCH, SWATCH)
		if entries[index][0] is Texture2D:
			draw_texture_rect(entries[index][0], square, false)
		else:
			_draw_swatch(square, entries[index][0])
		var words: String = entries[index][1]
		draw_string(font, Vector2(SWATCH + 8.0, top + SWATCH + 1.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE)


# A swatch over a square of open ground. The colours on the board are mostly
# translucent and sit over that ground, and over the window's grey they read
# as a different colour -- a review measured the difference.
func _draw_swatch(square: Rect2, colour: Color) -> void:
	if colour.a == 0.0:
		return
	if _ground == null:
		_ground = BoardView.tile_texture(BoardView.PLAIN)
	draw_texture_rect(_ground, square, false)
	draw_rect(square, colour)
