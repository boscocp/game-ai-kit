## The tactical game's own rules, as a `TacticalRuleset`: Advance Wars.
##
## Nothing here is a rule. Each method hands the question to the class that
## answered it before the seam existed -- `TacticalScenario`, `BoardState`,
## `TacticalCombat`, `TurnStart`, `TacticalVictory`, `ThreatMap`,
## `TacticalRoster` -- unchanged, so a game played through this ruleset is
## the game played before it, the same seeds giving the same results. That is
## what every tactical gate holds, and it is the scene's default ruleset.
##
## When not to use it: to change the Advance Wars rules. Change the class
## that owns the rule; this file only points at it.
class_name AdvanceWarsRuleset
extends TacticalRuleset

## This mode's name. Only games played in it are recorded: the learned
## opponent's data is Advance Wars games, and a recording replays by its rules.
const MODE: String = "advance wars"  # not shown: a key, the screen words it


## `rules`, or this ruleset when a caller gave none -- the one default every
## caller of the seam shares, so none of them writes it again.
static func or_default(rules: TacticalRuleset) -> TacticalRuleset:
	return rules if rules != null else AdvanceWarsRuleset.new()


## "advance wars".
func mode_name() -> String:
	return MODE


## "Advance Wars", the game this mode plays like: a name, which the table
## keeps the same in both languages.
func title() -> String:
	return TranslationServer.translate("Advance Wars")


## `TacticalGame.WHAT_THIS_IS`, in the language on screen.
func what_this_is() -> String:
	return TranslationServer.translate(TacticalGame.WHAT_THIS_IS)


## `TacticalScenario.build`: the workshops, the towers, three walkers.
func start() -> BoardState:
	return TacticalScenario.build()


## The board's own ruling: whose unit, the route, the movement left.
func why_walk_refused(state: BoardState, move: Move) -> String:
	return state.why_refused(move)


## The board's own walk.
func walk(state: BoardState, move: Move) -> BoardState:
	return state.apply(move)


## `TacticalCombat.why_refused`.
func why_attack_refused(state: BoardState, strike: Attack) -> String:
	return TacticalCombat.why_refused(state, strike)


## `TacticalCombat.apply`: a fight to the death, or a siege.
func attack(state: BoardState, strike: Attack) -> BoardState:
	return TacticalCombat.apply(state, strike)


## `TacticalCombat.told`.
func told(before: BoardState, strike: Attack, after: BoardState) -> String:
	return TacticalCombat.told(before, strike, after)


## `TurnStart.open`: income, points, then the towers fire.
func open_turn(state: BoardState) -> Array:
	return TurnStart.open(state)


## `TacticalVictory.winner`: a workshop destroyed, or the round limit.
func winner(state: BoardState) -> int:
	return TacticalVictory.winner(state)


## `TacticalVictory.rule`.
func rule() -> String:
	return TacticalVictory.rule()


## `TacticalVictory.announcement`.
func announcement(winner_side: int, state: BoardState) -> String:
	return TacticalVictory.announcement(winner_side, state)


## `ThreatMap.of`: every cell `side` could strike next turn, and by how many.
func tint(state: BoardState, side: int) -> Dictionary[Vector2i, int]:
	return ThreatMap.of(state, side)


## The two control points.
func points() -> Array[Vector2i]:
	return TacticalScenario.POINTS


## `TacticalRoster.names`.
func roster_names() -> Array[String]:
	return TacticalRoster.names()


## `TacticalRoster.build`.
func build_controller(row_name: String, seed_number: int) -> BlueController:
	return TacticalRoster.build(row_name, seed_number)
