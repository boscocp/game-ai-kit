## The words beside and under the maze: how the game stands, the keys, and
## what each ghost is deciding -- its target and why, each way and how far
## the cell beyond it is from the target, and how it chose.
##
## The panel reads only `MazeDemo.decision_overlay()`, so what a person reads
## is what the tests read. Every sentence is a key of `godot/locale/maze.csv`,
## translated with `TranslationServer.translate` -- these are static
## functions, and `tr()` is a method of an object (T79). The identifiers the
## rules compare (a mode, a direction, how a way was chosen) stay English in
## the overlay and are worded here.
class_name MazePanel
extends RefCounted

## A direction, as the panel says it.
const DIRECTION_WORDS: Dictionary = {  # shown through tr()
	"up": "up", "left": "left", "down": "down", "right": "right"}
## A mode, as the panel says it: "chase" alone is a verb in another table.
const MODE_WORDS: Dictionary = {  # shown through tr()
	"scatter": "scatter mode", "chase": "chase mode"}
## The ghosts' names, as the arcade gave them.
const GHOST_WORDS: Dictionary = {  # shown through tr()
	"blinky": "BLINKY", "pinky": "PINKY"}
## How each ghost's chase target is said.
const CHASE_TARGETS: Dictionary = {  # shown through tr()
	"blinky": "target: your cell {cell}",
	"pinky": "target: four cells ahead of you, {cell}",
}
## How a game ended.
const OUTCOMES: Dictionary = {  # shown through tr()
	"won": "all four pellets eaten: you win  ·  R plays again",
	"caught": "caught  ·  R plays again",
}
## The rule the kit adds to the arcade's, a line a key.
const IMPRECISION: Array[String] = [  # shown through tr()
	"In chase, at a fork, a ghost keeps the shortest line with",
	"chance {precision}, otherwise takes any way evenly: a rule",
	"of this game, not the arcade's, so the maze has chance in it.",
]


## The two lines under the maze: how the game stands, and the keys.
static func status(overlay: Dictionary, paused: bool, started: bool, view_on: bool, two_ghosts: bool) -> String:
	var keys: String = _keys(view_on, two_ghosts)
	if overlay["outcome"] != MazeGame.PLAYING:
		return "\n".join([TranslationServer.translate(OUTCOMES[overlay["outcome"]]), keys])
	var standing: String = TranslationServer.translate("step {step}, {mode}  ·  pellets left: {pellets}").format(
			{step = overlay["step"], mode = mode_words(overlay["mode"]), pellets = overlay["pellets_left"]})
	if not started:
		standing = TranslationServer.translate("press an arrow to start: Pac-Man runs until a wall stops him")
	elif paused:
		standing += "  ·  " + TranslationServer.translate("paused: P runs on, space plays one step")
	return "\n".join([standing, keys])


## The panel: each ghost's decision, then the rule the kit adds.
static func describe(overlay: Dictionary) -> String:
	var lines: PackedStringArray = []
	for ghost: Dictionary in overlay["ghosts"]:
		lines += _ghost_lines(ghost)
		lines.append("")
	for line: String in IMPRECISION:
		lines.append(TranslationServer.translate(line).format({precision = "%.2f" % overlay["precision"]}))
	return "\n".join(lines)


## A mode, in words.
static func mode_words(mode: String) -> String:
	return TranslationServer.translate(MODE_WORDS.get(mode, mode))


## A direction, in words.
static func direction_words(direction: String) -> String:
	return TranslationServer.translate(DIRECTION_WORDS.get(direction, direction))


## A cell as the panel writes it: (column, row).
static func cell_words(cell: Vector2i) -> String:
	return "(%d, %d)" % [cell.x, cell.y]


static func _keys(view_on: bool, two_ghosts: bool) -> String:
	var view: String = TranslationServer.translate("V: the ghosts' view off")
	if view_on:
		view = TranslationServer.translate("V: the ghosts' view on")
	var second: String = TranslationServer.translate("G: Pinky too")
	if two_ghosts:
		second = TranslationServer.translate("G: Blinky alone")
	var rest: String = TranslationServer.translate("arrows: walk  ·  P: pause  ·  space: one step  ·  R: again")
	return "  ·  ".join([rest, view, second])


static func _ghost_lines(ghost: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = [TranslationServer.translate("{ghost}, in {mode}").format(
			{ghost = TranslationServer.translate(GHOST_WORDS[ghost["name"]]), mode = mode_words(ghost["mode"])})]
	lines += _target_lines(ghost)
	for way: Dictionary in ghost["ways"]:
		lines.append(_way_line(way, way["direction"] == ghost["chosen"]))
	lines += _choice_lines(ghost)
	return lines


# One way: chosen or not, where it goes, the cell beyond and its distance.
static func _way_line(way: Dictionary, chosen: bool) -> String:
	return "  %s %-10s %-10s %5.1f" % [">" if chosen else " ", direction_words(way["direction"]),
			cell_words(way["beyond"]), way["distance"]]


static func _target_lines(ghost: Dictionary) -> PackedStringArray:
	var cell: String = cell_words(ghost["target"])
	if ghost["mode"] == MazeRules.SCATTER:
		return [TranslationServer.translate("target: its home corner, outside the walls, {cell}").format({cell = cell})]
	var lines: PackedStringArray = [TranslationServer.translate(CHASE_TARGETS[ghost["name"]]).format({cell = cell})]
	if ghost.get("up_bug", false):
		lines.append(TranslationServer.translate("  and four to the left too: you face up, the arcade's bug"))
	return lines


static func _choice_lines(ghost: Dictionary) -> PackedStringArray:
	var values: Dictionary = {way = direction_words(ghost["chosen"]), best = direction_words(ghost["best"]),
			roll = "%.2f" % ghost.get("roll", 0.0), precision = "%.2f" % ghost["precision"],
			pick = ghost.get("pick", 0) + 1, ways = ghost["ways"].size(), mode = mode_words(ghost["mode"])}
	if ghost["kind"] == MazeGhost.REVERSAL:
		return [TranslationServer.translate("the mode changed: it turns back, {way}, without choosing").format(values)]
	if ghost["kind"] == MazeGhost.ONLY_WAY:
		return [TranslationServer.translate("one way open, so no choice: {way}").format(values)]
	if ghost["kind"] == MazeGhost.DICE:
		var second: String = TranslationServer.translate("a second draw picks way {pick} of {ways}: {way}")
		return [TranslationServer.translate("dice {roll}, not under {precision}: imprecise").format(values),
			second.format(values)]
	if ghost.has("roll"):
		return [TranslationServer.translate("dice {roll}, under {precision}: it keeps the shortest, {way}").format(values)]
	return [TranslationServer.translate("the shortest line to the target: {way}").format(values)]
