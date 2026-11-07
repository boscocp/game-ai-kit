## What a player saw when it decided: a fight reduced to six words (T18).
##
## Behaviour cloning learns "in this situation, the player did that", and
## everything it can learn is limited by how the situation is written down.
## Six features, each a word from a short list, so a row can be read aloud:
##
## * `last` -- the last action this player was seen doing, as of the frame
##   the situation is read from (`FightRecording.last_seen`): the context an
##   order-2 n-gram sees, so the comparison with T17 is fair;
## * `other` -- what the other fighter is doing, as T17 reads an action;
## * `me` -- free, in a move, in the air, or stunned by a hit or a block;
## * `distance` -- the gap between the two: close (a throw reaches), near (a
##   strike does), far;
## * `health` -- ahead, even or behind;
## * `corner` -- whether its back is to the wall.
##
## The features are computed here and nowhere else. Python never sees a
## fight, only the rows this writes, so there is no second copy of the
## arithmetic to fall out of step: the rows the model is fitted on and the
## situations it is asked about in the game come out of the same function.
##
## When not to use it: a fight where the exact spacing matters to the
## decision -- a footsies specialist steps in and out of one unit of reach.
## Three distance words cannot hold that.
class_name FightSituation
extends RefCounted

## The features, in the order a row is written.
const FEATURES: Array[String] = ["last", "other", "me", "distance", "health", "corner"]
## What `last` and `other` say when there is nothing to say.
const NOTHING: String = "nothing"  # not shown: an identifier
## The widest gap, in stage units, at which the two count as close and near:
## a throw reaches about 40 to 48, most standing strikes 60 to 110.
const CLOSE: int = 50
const NEAR: int = 110
## How far from the wall a fighter's back is "to the wall", in stage units.
const CORNER: int = 60
## How much health counts as a lead: a tenth of a full bar.
const LEAD: int = 100


## The situation player `me` saw in `state`, having last done `last` -- one
## of `FightAction.ACTIONS`, or "" for nothing yet.
static func of(state: FightState, me: int, last: String, data: FightData) -> Dictionary:
	var mine: FighterState = state.fighters[me]
	var other: FighterState = state.fighters[1 - me]
	var doing: String = FightAction.of(state, 1 - me, data)
	return {
		"last": last if last != "" else NOTHING,
		"other": doing if doing != "" else NOTHING,
		"me": condition_of(mine),
		"distance": distance_of(mine, other, data),
		"health": health_of(mine, other),
		"corner": "yes" if cornered(mine, other, data) else "no",  # not shown: an identifier, worded where a panel shows it
	}


## Free, moving, airborne, hit or blocking: what the fighter can do now. A
## backdash is "moving": committed, as a move is, and the action it is read
## as -- `last`, `other` -- already says which.
static func condition_of(fighter: FighterState) -> String:
	if fighter.is_airborne() or fighter.stun_kind == "takeoff":
		return "airborne"
	if fighter.stun_kind == "hit" or fighter.stun_kind == "block":
		return fighter.stun_kind
	if fighter.move != "" or fighter.stun_kind == FightBackdash.KIND:
		return "moving"
	return "free"


## Close, near or far: the gap between one body's centre and the other's
## edge, as `FightOpponent` measures reach.
static func distance_of(mine: FighterState, other: FighterState, data: FightData) -> String:
	var gap: int = absi(other.x - mine.x) - int(data.character(other.character)["body"])
	if gap <= CLOSE:
		return "close"
	return "near" if gap <= NEAR else "far"


## Ahead, even or behind on health, by more than `LEAD`.
static func health_of(mine: FighterState, other: FighterState) -> String:
	var lead: int = mine.health - other.health
	if lead > LEAD:
		return "ahead"
	return "behind" if lead < -LEAD else "even"


## True when the wall behind the fighter -- the side away from the other --
## is within `CORNER`.
static func cornered(mine: FighterState, other: FighterState, data: FightData) -> bool:
	var width: int = int(data.table["stage"]["width"])
	if other.x > mine.x:
		return mine.x <= CORNER
	return mine.x >= width - CORNER

