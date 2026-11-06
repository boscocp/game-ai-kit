## The squad's game for expectiminimax (T88): `SquadSearchGame`, with an
## evaluation written by hand for the positions a search stops on before
## the game is over.
##
## MCTS plays on to the end, or near it, and needs nothing but who has more
## health left. Expectiminimax stops at a depth -- a piece's walk and shot,
## a turn -- and has to say there how good the position looks. Three
## terms, each in [-1, 1], each times its weight in `rules.json`'s
## `evaluation`:
##
## - **health**: the side's health left, less the other's, over a full
##   squad's -- what `SquadSearchGame.evaluate` scores alone;
## - **cover**: how much cover its pieces hold against the enemy's, less how
##   much the enemy's hold against its own: for every piece and every enemy,
##   the cover facing that enemy (`SquadCover`), over a full cover's worth;
## - **flanked**: the share of the enemy's pieces one of its pieces could
##   shoot from where it stands with no cover between -- flanked, or in the
##   open -- less the share of its own the enemy could.
##
## The weights add up to 1, and the health term is below 1 until a squad is
## gone, so no estimate reaches a win's +1. Nothing is fitted (invariant 6):
## the weights are a guess, written down, and the point of T88's duel is
## that MCTS needs none of it. Python's `gameaikit.squad.evaluation` is the
## same arithmetic.
##
## Complexity: a line of sight and a cover read for each pair of pieces, 16
## of each with full squads. When not to use it: for MCTS's playouts. They
## are scored on health alone, as T87 tuned them.
class_name SquadEvaluatedGame
extends SquadSearchGame


## The game's outcome once it is over; before that, the weighed sum of the
## three terms for `player`.
func evaluate(position: RefCounted, player: int) -> float:
	if is_terminal(position):
		return super.evaluate(position, player)
	var weights: Dictionary = SquadTable.rules()["evaluation"]
	var terms: Dictionary = terms_for((position as Position).board, player)
	var score: float = 0.0
	for term: String in ["health", "cover", "flanked"]:
		score += float(weights[term]) * terms[term]
	return score


## The three terms for `player` on `board`, unweighed: `{"health",
## "cover", "flanked"}`, each in [-1, 1]. What the overlay and the tests
## read; `evaluate` weighs them.
static func terms_for(board: BoardState, player: int) -> Dictionary:
	var other: int = TacticalScenario.FACTIONS - 1 - player
	var health: float = float(SquadVictory.health_left(board, player) - SquadVictory.health_left(board, other)) / full_health()
	return {"health": health, "cover": covered(board, player) - covered(board, other),
		"flanked": exposed(board, other) - exposed(board, player)}


## How much cover `side`'s pieces hold against the other side's, in [0, 1]:
## over every pair of its piece and an enemy, the cover facing that enemy,
## over a full cover's worth. 0 when either side has nobody left.
static func covered(board: BoardState, side: int) -> float:
	var rows: Array[String] = SquadScenario.rows()
	var full: float = float(SquadTable.cover_worth("full"))
	var total: float = 0.0
	var pairs: int = 0
	for piece: Unit in board.units_of(side):
		for enemy: Unit in board.units_of(TacticalScenario.FACTIONS - 1 - side):
			total += SquadCover.of(rows, enemy.cell, piece.cell)["cover"] / full
			pairs += 1
	return total / pairs if pairs > 0 else 0.0


## The share of `side`'s pieces, in [0, 1], that some enemy piece could
## shoot from where it stands -- in its sight and range, the line clear --
## with no cover facing that enemy. 0 when `side` has nobody left.
static func exposed(board: BoardState, side: int) -> float:
	var pieces: Array[Unit] = board.units_of(side)
	if pieces.is_empty():
		return 0.0
	var enemies: Array[Unit] = board.units_of(TacticalScenario.FACTIONS - 1 - side)
	var count: int = 0
	for piece: Unit in pieces:
		if _open_to_any(enemies, piece):
			count += 1
	return float(count) / pieces.size()


# True when one of `enemies` could shoot `piece` with no cover facing it.
static func _open_to_any(enemies: Array[Unit], piece: Unit) -> bool:
	var rows: Array[String] = SquadScenario.rows()
	for enemy: Unit in enemies:
		if SquadCombat.can_reach(rows, enemy, piece.cell) and SquadCover.of(rows, enemy.cell, piece.cell)["cover"] == 0:
			return true
	return false
