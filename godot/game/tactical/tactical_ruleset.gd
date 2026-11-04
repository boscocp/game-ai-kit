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


# --- what the scene shows (T85) ------------------------------------------------
# Each of these has an answer that leaves the screen as Advance Wars drew it
# before the seam, so only a mode that shows something else answers them.

## The mode's name as a person knows the game it comes from, such as
## "Advance Wars": a game's name, the same in every language.
func title() -> String:
	return mode_name()


## The line at the top of the screen saying what the game is.
@abstract func what_this_is() -> String


## What `side` sees of `state`, remembering what `earlier` -- the same side's
## last fog, or null -- had seen; null in a mode without fog, and the scene
## then draws the board whole.
func fog(_state: BoardState, _side: int, _earlier: TacticalFog) -> TacticalFog:
	return null


## The cells of `walks` (cell -> route, as `TacticalReach.walks_for` gives
## them) that a walk to would leave `unit` spent -- a dash, drawn in a
## second tint. None in a mode where every walk is one action.
func dashes(_state: BoardState, _unit: Unit, _walks: Dictionary) -> Array[Vector2i]:
	return []


## A short label on each enemy `shooter_id` may attack now -- its hit
## chance, "63%" -- drawn on the target before anything is clicked. None in
## a mode whose odds are words in the status.
func odds(_state: BoardState, _shooter_id: int) -> Dictionary[Vector2i, String]:
	return {}


## What T tints with the cursor on `cursor`, for a person playing `person`
## with `in_hand_id` in hand (-1 for nothing): `tint`, unless the mode
## answers about the cell under the cursor.
func tint_at(state: BoardState, side: int, _cursor: Vector2i, _person: int, _in_hand_id: int) -> Dictionary[Vector2i, int]:
	return tint(state, side)


## True when `side`, going from `before` to `after`, saw an enemy it did not
## see before: a walk that showed something can no longer be taken back. False
## in a mode without fog.
func reveals(_before: BoardState, _after: BoardState, _side: int) -> bool:
	return false


## The status on the person's turn: the piece in hand and what to do with
## it, the last refusal and what just happened.
func status(state: BoardState, in_hand: Unit, refusal: String, news: String, can_attack: bool) -> String:
	return TacticalStatus.text(state, in_hand, refusal, news, can_attack, self)


## The status on the computer's turn: who plays it, and what it will do --
## as much of it as `fog`, the fog on screen (null for none), lets show.
func computer_status(state: BoardState, turn: BlueTurn, controller: BlueController, news: String,
		_fog: TacticalFog) -> String:
	return TacticalStatus.computer_text(state, turn, controller, news)


## True when `unit`, which has not attacked this turn, still may: always in
## a mode where walking leaves the attack, as Advance Wars's does.
func can_still_attack(_state: BoardState, _unit: Unit) -> bool:
	return true


## What a person is told on picking up `unit` after it has walked this turn.
func moved_already(unit: Unit, can_attack: bool, can_undo: bool) -> String:
	return TacticalStatus.moved_already(unit, can_attack, can_undo)


## The legend's entries, `[Color or Texture2D, String]` each.
func legend() -> Array[Array]:
	return TacticalLegend.entries(TacticalRules.unit_types())
