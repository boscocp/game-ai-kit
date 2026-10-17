## When a skirmish is over: a side wins by holding a node.
##
## A side **holds** a node while one of its units stands on it and no enemy
## unit stands beside it. Holding is counted at the start of the holder's own
## turn, and `HOLD_TURNS` such starts in a row win -- so the other side always
## has whole turns to walk up and break it, and breaking it is as simple as
## arriving next to the node. That is what makes the flag worth fighting over
## before T26 brings an attack that does anything.
##
## T41: the owner stood on the white flag and nothing happened, because no rule
## gave a node any meaning at all. The decision, taken with the owner, was
## that holding one ends the game.
##
## When not to use it: once combat can remove a holder. Then "an enemy beside
## it" stops being the only way to contest a node, and the rule is a design
## question again.
class_name SkirmishVictory
extends RefCounted

## Nobody has won yet.
const NOBODY: int = -1
## Nobody won, and the game is over: the round limit came first.
const DRAW: int = -2
## Rounds before a game nobody has won is a draw. The review found one that
## could not end: red on both nodes, blue beside each, nothing to fight.
const ROUND_LIMIT: int = 30
## How many of its own turns in a row a side must start holding a node.
const HOLD_TURNS: int = 3

## The side that has won, `DRAW`, or `NOBODY`.
var winner: int = NOBODY

var _nodes: Array[Vector2i]
var _factions: int
# Node -> [side holding it, turns it has been held at that side's turn start].
var _held: Dictionary = {}


func _init(nodes: Array[Vector2i], factions: int = 2) -> void:
	_nodes = nodes.duplicate()
	_factions = factions


## Count the holds of the side about to move on `state`, and decide whether
## it has just won. Called once at the start of every turn.
func turn_started(state: BoardState) -> void:
	if winner != NOBODY:
		return
	var side: int = state.current_faction
	for node: Vector2i in _nodes:
		if _count(node, side, holder_of(state, node) == side) >= HOLD_TURNS:
			winner = side
	if winner == NOBODY and state.turn_number >= ROUND_LIMIT * _factions:
		winner = DRAW


## The side holding `node` on `state` right now, or `NOBODY`.
static func holder_of(state: BoardState, node: Vector2i) -> int:
	var standing: Unit = state.unit_at(node)
	if standing == null:
		return NOBODY
	for step: Vector2i in GridGraph.DIRECTIONS:
		var beside: Unit = state.unit_at(node + step)
		if beside != null and beside.faction != standing.faction:
			return NOBODY
	return standing.faction


## How far each hold has got, for the screen: "" when nobody holds anything.
## A hold is counted on its own side's turn, so between counts `state` says
## whether it still stands -- one the other side has walked up to and broken
## is not shown as two turns from winning.
func progress(state: BoardState, side_names: Array[String]) -> String:
	var lines: Array[String] = []
	for node: Vector2i in _nodes.filter(func(node: Vector2i) -> bool:
			return _held.has(node) and holder_of(state, node) == _held[node][0]):
		var held: Array = _held[node]
		lines.append("%s holds the node at %s: %d of %d turns" % [side_names[held[0]], node, held[1], HOLD_TURNS])
	return "\n".join(lines)


# One more turn start for `side` at `node`: the hold grows by one while it
# lasts, and a hold of this side's that has been broken is forgotten. A hold of
# the other side's is left alone -- it is counted on that side's own turn.
# Returns how long `side` has now held it.
func _count(node: Vector2i, side: int, holding: bool) -> int:
	var ours: bool = _held.has(node) and _held[node][0] == side
	if not holding:
		if ours:
			_held.erase(node)
		return 0
	_held[node] = [side, _held[node][1] + 1 if ours else 1]
	return _held[node][1]


## The rule, as the screen states it before anybody has won.
static func rule() -> String:
	return "to win: start %d of your turns in a row with a unit on a node and no enemy beside it -- or it is a draw after %d rounds" % [
		HOLD_TURNS, ROUND_LIMIT]


## The words for the end of a game.
static func announcement(winner_side: int, side_names: Array[String]) -> String:
	if winner_side == DRAW:
		return "a draw: %d rounds, and nobody held a node.  R starts again." % ROUND_LIMIT
	return "%s wins: it held a node for %d of its turns in a row.  R starts again." % [
		side_names[winner_side], HOLD_TURNS]
