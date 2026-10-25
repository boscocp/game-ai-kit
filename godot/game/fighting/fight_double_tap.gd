## Back pressed twice, quickly: the evade, as fighting games spell it.
##
## The evade has a button of its own (`FightInput.EVADE`), and the rules only
## ever read that bit. Back tapped twice is turned into it here, at the edge
## where a person's keys become a frame's input, so the input log holds the
## bit the double tap produced and replays exactly -- the rules never learn
## a double tap exists, and a log recorded before it still replays the same.
##
## Back is away from the way the fighter faces: after a cross-over it is the
## other key, and a first tap taken the old way does not count -- nor does a
## key already held when the fighter turns, which was pressed as forward.
##
## The window runs from the first press, not from its release, so walking
## back briefly and then holding back to guard inside it is an evade. That is
## the trade-off every double tap makes: a quick back, back is a dash.
##
## When not to use it: the dummy and the opponents. They press the evade
## bit directly; a double tap is how a person asks for it.
class_name FightDoubleTap
extends RefCounted

## How many frames the second tap may come after the first and still count:
## a fifth of a second, about what shipped fighting games allow.
const WINDOW: int = 12
## What `_first_tap_at` holds when no first tap is waiting for its second.
const NEVER: int = -1
## What `_back_key` holds before the first frame: no way faced yet.
const NO_KEY: int = 0

var _frame: int = 0
var _back_was_held: bool = false
var _back_key: int = NO_KEY
var _first_tap_at: int = NEVER


## The frame's input, with the evade bit added on the frame the second tap
## of back goes down. `facing` is the fighter's, +1 right and -1 left.
func read(held: int, facing: int) -> int:
	_frame += 1
	var back_key: int = FightInput.LEFT if facing > 0 else FightInput.RIGHT
	var back_held: bool = FightInput.walk_direction(held) == -facing
	if back_key != _back_key:
		# A turn -- not the first frame, when there is no old way -- and a key
		# held now was pressed as forward: it is not a tap.
		_back_was_held = back_held and _back_key != NO_KEY
		_back_key = back_key
		_first_tap_at = NEVER
	var tapped: bool = back_held and not _back_was_held
	_back_was_held = back_held
	if not tapped:
		return held
	if _first_tap_at != NEVER and _frame - _first_tap_at <= WINDOW:
		_first_tap_at = NEVER
		return held | FightInput.EVADE
	_first_tap_at = _frame
	return held
