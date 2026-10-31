## The rules the tactical scene plays by, asked rather than called (T84).
##
## The scene used to call its rules by name -- `TacticalScenario.build`,
## `TacticalCombat.apply`, `TacticalVictory.winner`, `ThreatMap.of`,
## `TacticalRoster` -- so one game was all it could ever be. This is that
## list as one interface, and the scene holds one of it: the board, the
## pieces, their pictures, the keys and the turn stay the scene's, and what a
## walk and an attack *do*, who has won and who can play the other side are
## the ruleset's.
##
## Two rulesets exist. `AdvanceWarsRuleset` wraps the classes above
## unchanged, and is the scene's default, so the Advance Wars game is the
## game it was. `SquadRuleset` (module `squad`) plays XCOM's shot, cover
## and fog on the same state and map. The scene is handed a ruleset by
## whoever opens it, which is why `tactical` never names `squad`.
##
## Every method takes the state it rules on and keeps nothing between calls:
## a ruleset is a table of rules, and a search may ask it about a thousand
## states without it remembering any.
##
## When not to use it: a game on another board. The seam is the tactical
## scene's: its map, its two sides, its kinds of decision (a walk, an attack,
## a build). A game that decides something else is another scene.
@abstract
class_name TacticalRuleset
extends RefCounted


## The mode's name, as the screen and a recording give it, such as
## "advance wars".
@abstract func mode_name() -> String


## A fresh game: the state the first turn is played on.
@abstract func start() -> BoardState


## Why this walk cannot be made, or `BoardState.LEGAL`.
@abstract func why_walk_refused(state: BoardState, move: Move) -> String


## The state after this walk, or null when it is refused.
@abstract func walk(state: BoardState, move: Move) -> BoardState


## Why this attack cannot be made, or `BoardState.LEGAL`.
@abstract func why_attack_refused(state: BoardState, strike: Attack) -> String


## The state after this attack, or null when it is refused. The dice come
## from `state.dice_seed`, so the same state and attack give the same result.
@abstract func attack(state: BoardState, strike: Attack) -> BoardState


## One line saying what an attack did, for the person to read.
@abstract func told(before: BoardState, strike: Attack, after: BoardState) -> String


## The next side's turn opened on `state`, as `[BoardState, Array[String]]`:
## the new state and a line for each thing that happened as it opened.
@abstract func open_turn(state: BoardState) -> Array


## The winner, `TacticalVictory.DRAW`, or `TacticalVictory.NOBODY` while the
## game is on. The two constants are shared, so the scene reads any mode's
## ending the same way.
@abstract func winner(state: BoardState) -> int


## How to win, as the screen states it before anybody has.
@abstract func rule() -> String


## The words for the end of a game won by `winner_side`.
@abstract func announcement(winner_side: int, state: BoardState) -> String


## The board's tint: cell -> how strongly `side` threatens it. Empty for a
## mode that tints nothing.
@abstract func tint(state: BoardState, side: int) -> Dictionary[Vector2i, int]


## The cells the board marks as points to hold; none for a mode without.
@abstract func points() -> Array[Vector2i]


## The names of the controllers C cycles through, in order.
@abstract func roster_names() -> Array[String]


## A new controller from the roster row called `row_name`, or null.
@abstract func build_controller(row_name: String, seed_number: int) -> BlueController


## The roster row after `row_name`, round to the first after the last; a
## name no row has is followed by the first, as `TacticalRoster.after` does.
func controller_after(row_name: String) -> String:
	var order: Array[String] = roster_names()
	return order[(order.find(row_name) + 1) % order.size()]
