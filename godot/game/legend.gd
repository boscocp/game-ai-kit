## What each colour on the screen means, drawn in a corner of every example.
##
## A coloured square means nothing to somebody who did not write it, and every
## example in the kit draws the AI's reasoning in coloured squares. So each
## one carries a legend, and `check_demos.py` refuses an example scene without
## one. Entries are a colour and a few words; the legend draws a swatch and the
## words beside it, one per line.
class_name Legend
extends Control

const SWATCH: float = 14.0
const LINE: float = 20.0
const TEXT_SIZE: int = 14

## Each entry is `[Color, String]`: the swatch and what it stands for.
var entries: Array[Array] = []


## Replace what the legend says. Called once, by the example that owns it.
func set_entries(new_entries: Array[Array]) -> void:
	entries = new_entries
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for index: int in range(entries.size()):
		var top: float = index * LINE
		draw_rect(Rect2(0.0, top + 3.0, SWATCH, SWATCH), entries[index][0])
		var words: String = entries[index][1]
		draw_string(font, Vector2(SWATCH + 8.0, top + SWATCH + 1.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE)
