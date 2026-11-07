## What the tactical scene draws and writes for one mode, asked rather than
## called (T126).
##
## A mode is two objects. Its `TacticalRuleset` holds the rules: the start, a
## walk, an attack, the news, the winner, the roster. This holds the rest --
## what the screen shows of them: the header's words, the points marked, the
## tint, the fog, the dash, the odds on a target, the status and the legend.
## A search asks the ruleset a thousand times and never asks this; the scene
## asks both.
##
## The split is T85's review's (finding 4): the ruleset had grown 28 answers,
## and each mode added to the scene added its own way of drawing to the rules.
## Each answer below that is not abstract leaves the screen as Advance Wars
## drew it before the seam, so only a mode that shows something else answers
## it.
##
## A view keeps nothing between calls but the ruleset it shows, which its
## ruleset hands it (`TacticalRuleset.mode_view`): the scene's own memory --
## the last fog each side saw -- stays the scene's.
##
## When not to use it: for anything a controller or a search must know. What
## a piece may do is the ruleset's, even when the screen also shows it.
@abstract
class_name TacticalModeView
extends RefCounted

## What the scene does after a key the mode answered (`pressed`): nothing,
## draw the screen again, or start a new game -- on a new map, say.
const NOTHING: int = 0
const DRAW: int = 1
const NEW_GAME: int = 2

## The rules this view shows. The status asks them which targets a piece in
## hand may attack, so the words cannot offer what the rules refuse.
var rules: TacticalRuleset


func _init(shown: TacticalRuleset) -> void:
	rules = shown


## The mode's name as a person knows the game it comes from, such as
## "Advance Wars": a game's name, the same in every language.
func title() -> String:
	return rules.mode_name()


## The line at the top of the screen saying what the game is.
@abstract func what_this_is() -> String


## How to win, as the screen states it before anybody has.
@abstract func rule() -> String


## The words for the end of a game won by `winner_side`.
@abstract func announcement(winner_side: int, state: BoardState) -> String


## The board's tint: cell -> how strongly `side` threatens it. Empty for a
## mode that tints nothing.
@abstract func tint(state: BoardState, side: int) -> Dictionary[Vector2i, int]


## The cells the board marks as points to hold; none for a mode without.
@abstract func points() -> Array[Vector2i]


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


## True when the tint's numbers are hit chances rather than counts: the
## board then writes them with a `%`, in a corner of their own (T137).
## False here: a count of pieces that could strike.
func tint_is_a_chance() -> bool:
	return false


## True when `side`, going from `before` to `after`, saw an enemy it did not
## see before: a walk that showed something can no longer be taken back, or
## Z would let a person look round a corner for free. False in a mode
## without fog.
func reveals(_before: BoardState, _after: BoardState, _side: int) -> bool:
	return false


## The status on the person's turn: the piece in hand and what to do with
## it, the last refusal and what just happened.
func status(state: BoardState, in_hand: Unit, refusal: String, news: String, can_attack: bool) -> String:
	return TacticalStatus.text(state, in_hand, refusal, news, can_attack, rules)


## The status on the computer's turn: who plays it, and what it will do --
## as much of it as `fog`, the fog on screen (null for none), lets show.
func computer_status(state: BoardState, turn: BlueTurn, controller: BlueController, news: String,
		_fog: TacticalFog) -> String:
	return TacticalStatus.computer_text(state, turn, controller, news)


## What a person is told on picking up `unit` after it has walked this turn.
func moved_already(unit: Unit, can_attack: bool, can_undo: bool) -> String:
	return TacticalStatus.moved_already(unit, can_attack, can_undo)


## The map the scene draws, rows of `TacticalRules`' letters: the tactical
## map, unless the mode plays on another or is building one (T96).
func rows() -> Array[String]:
	return TacticalScenario.MAP


## What the mode did with `keycode`, a key the scene does not use itself, as
## what the scene must do next: `NOTHING`, `DRAW` or `NEW_GAME`.
func pressed(_keycode: Key) -> int:
	return NOTHING


## What the board shows while the mode builds something of its own in place
## of the game -- the squad mode's map, made a step at a time (T96):
## `labels` (cell -> words on it), `next` (cells about to be decided),
## `stuck` (cell -> 0, where it failed) and `overlay`, the same in English.
## {} while it builds nothing, and the board is the game's.
func building() -> Dictionary:
	return {}


## The legend's entries, `[Color or Texture2D, String]` each.
func legend() -> Array[Array]:
	return TacticalLegend.entries(TacticalRules.unit_types())
