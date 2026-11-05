## What the scene shows of the Advance Wars mode, as a `TacticalModeView`.
##
## Like `AdvanceWarsRuleset`, nothing here is new: each answer hands the
## question to the class that answered it before the split (T126) --
## `TacticalVictory` for the words of a win, `ThreatMap` for the tint,
## `TacticalScenario` for the points -- and every other answer is the base
## class's, which draws the board whole with no fog, no dash and no odds.
##
## When not to use it: to change what Advance Wars shows. Change the class
## that owns it; this file only points at it.
class_name AdvanceWarsView
extends TacticalModeView

## What the scene says it is, on screen, before anything else.
const WHAT_THIS_IS: String = "tactics in the style of Advance Wars: build, cross the river, destroy the enemy workshop"  # shown through tr()


## "Advance Wars", the game this mode plays like: a name, which the table
## keeps the same in both languages.
func title() -> String:
	return TranslationServer.translate("Advance Wars")


## `WHAT_THIS_IS`, in the language on screen.
func what_this_is() -> String:
	return TranslationServer.translate(WHAT_THIS_IS)


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
