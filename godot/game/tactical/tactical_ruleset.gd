## The rules the tactical scene plays by, asked rather than called (T84).
##
## The scene used to call its rules by name -- `TacticalScenario.build`,
## `TacticalCombat.apply`, `TacticalVictory.winner`, `TacticalRoster` -- so one game was all it could ever be. This is that
## list as one interface, and the scene holds one of it: the board, the
## pieces, their pictures, the keys and the turn stay the scene's, and what a
## walk and an attack *do*, who has won and who can play the other side are
## the ruleset's.
##
## What the screen shows of a mode -- its words, its tint, its fog -- is not
## here: it is the mode's `TacticalModeView` (T126), which the ruleset hands
## the scene through `mode_view`.
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


## One line saying what an attack did, for the person to read: a `Sentence`,
## worded where it is shown.
@abstract func told(before: BoardState, strike: Attack, after: BoardState) -> Array


## The next side's turn opened on `state`, as `[BoardState, Array[Array]]`:
## the new state and a `Sentence` for each thing that happened as it opened.
@abstract func open_turn(state: BoardState) -> Array


## The winner, `TacticalVictory.DRAW`, or `TacticalVictory.NOBODY` while the
## game is on. The two constants are shared, so the scene reads any mode's
## ending the same way.
@abstract func winner(state: BoardState) -> int


## The names of the controllers C cycles through, in order.
@abstract func roster_names() -> Array[String]


## A new controller from the roster row called `row_name`, or null.
@abstract func build_controller(row_name: String, seed_number: int) -> BlueController


## The roster row after `row_name`, round to the first after the last; a
## name no row has is followed by the first, as `TacticalRoster.after` does.
func controller_after(row_name: String) -> String:
	var order: Array[String] = roster_names()
	return order[(order.find(row_name) + 1) % order.size()]


## True when `unit`, which has not attacked this turn, still may: always in
## a mode where walking leaves the attack, as Advance Wars's does.
func can_still_attack(_state: BoardState, _unit: Unit) -> bool:
	return true


## What the scene draws and writes for this mode (T126): the header's words,
## the tint, the fog, the dash, the odds, the status and the legend. The
## rules hand the scene their view, so whoever opens it hands only rules, and
## `tactical` still never names a mode it does not own.
@abstract func mode_view() -> TacticalModeView
