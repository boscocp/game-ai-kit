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
## Between the swatch and the words.
const WORDS_GAP: float = 8.0

# Open ground, under every translucent swatch. Made once, when first drawn.
var _ground: Texture2D

## Each entry is `[Color, String]` or `[Texture2D, String]`: the swatch and
## what it stands for. A picture may carry a third element, the tint the board
## draws it with, so the legend shows what the board shows.
var entries: Array[Array] = []


## How wide a line's words may be: the legend's own width, past its swatch.
## A line added from code -- the pad's table -- breaks to stay inside it.
func words_width() -> float:
	return size.x - SWATCH - WORDS_GAP


## How wide `words` are drawn, in the legend's font and size.
static func width_of(words: String) -> float:
	return ThemeDB.fallback_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE).x


## How far down the legend's lines go, from its top: the last line's words,
## their descent included, or its swatch, whichever ends lower. The box a
## scene gives the legend does not hold it -- `_draw` goes on past it -- so a
## check of what overlaps the legend measures this, not `size.y` (T108).
## A last line with a clear swatch (words alone) draws no swatch, and is
## over-counted by about a pixel: on the safe side.
func drawn_height() -> float:
	if entries.is_empty():
		return 0.0
	var last_top: float = (entries.size() - 1) * LINE
	var descent: float = ThemeDB.fallback_font.get_descent(TEXT_SIZE)
	return last_top + maxf(SWATCH + 2.0, SWATCH + 1.0 + descent)


## How wide the legend's widest line is drawn, its swatch included: what it
## covers to the right, which may be past its box.
func drawn_width() -> float:
	var widest: float = 0.0
	for entry: Array in entries:
		widest = maxf(widest, width_of(str(entry[1])))
	return SWATCH + WORDS_GAP + widest


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
			var tint: Color = entries[index][2] if entries[index].size() > 2 else Color.WHITE
			draw_texture_rect(entries[index][0], square, false, tint)
		else:
			_draw_swatch(square, entries[index][0])
		var words: String = entries[index][1]
		draw_string(font, Vector2(SWATCH + WORDS_GAP, top + SWATCH + 1.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE)


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
