## What an opponent is allowed to see: the fight as it was, `reaction` frames
## ago, and never the frame it is answering.
##
## The research arena hands every AI the fight 15 frames late, a person's
## reaction time (`docs/concepts/fighting-game-ai.md`). An opponent that read
## the present could guard a low on the frame it was pressed -- reflexes no
## person has. So the opponent is never handed the present to begin with: it
## is seated here, the game gives this the present, and this gives the
## opponent a copy of the frame `reaction` frames back. The reaction is read
## once, when the opponent is seated, so changing it later changes nothing;
## and one under `MINIMUM_REACTION` is refused a seat.
##
## Until `reaction` frames have passed the opponent is handed nothing and
## holds nothing: it has not seen the fight yet.
##
## The guarantee is the seat's, not the opponent's: `FightOpponent.choose`
## takes whatever state it is given, and an opponent built with a reference
## to the live fight could read it. What this holds is that a game which
## seats its opponent here hands it nothing fresher than `reaction` frames.
## It keeps its own copy of every frame, so a caller that steps one state in
## place, or swaps two, cannot make an old frame turn into a new one.
##
## When not to use it: an opponent meant to read the controller -- a training
## dummy set to "block everything" is one, and says so in its menu.
class_name FightDelay
extends RefCounted

## The fewest frames late an opponent may see the fight: the competition's
## number, a quarter of a second at 60 frames a second.
const MINIMUM_REACTION: int = 15

## Why the opponent was refused a seat, or "" when it has one.
var refusal: String = ""

## How many frames late the seated opponent sees the fight, read from it once,
## when it was seated: what is enforced, whatever the opponent says later.
var reaction: int
## The opponent in the seat.
var opponent: FightOpponent

var _index: int
## The frames seen so far, oldest first, at most `reaction + 1` of them: the
## oldest is the one handed over, the newest is the present.
var _frames: Array[FightState] = []


## Seat `seated` as player `index` (0 or 1), or refuse it, with the reason
## in `refusal`, when it asks to see the fight sooner than a person could.
func _init(seated: FightOpponent, index: int) -> void:
	opponent = seated
	_index = index
	reaction = seated.reaction
	var asks_too_soon: String = "an opponent must see the fight at least %d frames late, and this one asks for %d"
	if reaction < MINIMUM_REACTION:
		refusal = asks_too_soon % [MINIMUM_REACTION, reaction]


## The opponent's input for the frame after `now`, chosen from the frame
## `reaction` frames before it. 0 while it has seen nothing yet, and always
## 0 for a refused opponent. A fight that does not follow on from the last
## frame given -- a restart -- starts its memory again, and the opponent's:
## nothing seen in one fight is carried into the next.
func input_for(now: FightState) -> int:
	if refusal != "":
		return 0
	if not _frames.is_empty() and now.frame != _frames.back().frame + 1:
		_frames.clear()
		opponent.new_fight()
	_frames.append(now.copy())
	if _frames.size() > reaction + 1:
		_frames.pop_front()
	if _frames.size() <= reaction:
		return 0
	return opponent.choose(_frames[0].copy(), _index)
