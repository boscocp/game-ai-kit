## What one side sees of the board, as the scene draws it (T85): the board
## as that side sees it, the cells none of its pieces can see, and where it
## last saw each enemy it no longer does.
##
## The scene draws whichever fog it is handed -- the hidden cells darkened,
## a faded picture on each cell an enemy was last seen on -- and draws the
## pieces from `seen`, never from the whole state, so nothing it shows has
## been perceived by nobody. A mode with no fog hands it none, and the board
## is drawn whole, as Advance Wars has always been.
##
## The tactical scene never names a mode, so the side's own memory is
## carried here as `memory`, which only the ruleset that made it reads: in
## the XCOM-style mode it is that side's `SideView`.
##
## When not to use it: hidden information beyond position. A piece seen is
## seen whole; one unseen is a cell and a picture.
class_name TacticalFog
extends RefCounted

## The side this is the fog of.
var side: int
## The board as the side sees it: its own pieces and the enemies it sees.
var seen: BoardState
## The cells none of the side's pieces can see.
var hidden: Array[Vector2i] = []
## Cell -> the kind of the enemy last seen there, for every enemy remembered
## and not seen now.
var ghosts: Dictionary[Vector2i, String] = {}
## What the ruleset keeps from one look to the next, handed back to it with
## the next look; nothing else reads it.
var memory: RefCounted


func _init(seeing_side: int, seen_board: BoardState) -> void:
	side = seeing_side
	seen = seen_board


## `decision` as a board drawn through `fog` may show it: whole with no fog;
## nothing for a piece the fog's side cannot see, which acts unseen; and a
## walk cut at the last cell it can see, so a seen piece walking into the
## dark does not draw where it goes.
static func clipped(fog: TacticalFog, decision: TacticalDecision) -> TacticalDecision:
	if fog == null or decision == null:
		return decision
	if fog.seen.unit_by_id(decision.unit_id) == null:
		return null
	if decision.move == null:
		return decision
	var path: Array[Vector2i] = []
	for cell: Vector2i in decision.move.path:
		if cell in fog.hidden:
			break
		path.append(cell)
	if path.size() == decision.move.path.size():
		return decision
	if path.is_empty():
		return null
	return TacticalDecision.walk(decision.unit_id, path, decision.reason, path[path.size() - 1])


## True when `cell` is one the fog's side cannot see.
func hides(cell: Vector2i) -> bool:
	return cell in hidden
