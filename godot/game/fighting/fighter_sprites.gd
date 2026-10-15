## Which picture draws a fighter on a frame, from `sprites.json` (T35).
##
## The pictures are strips: one animation's cels side by side, cut from a CC0
## template by `tools/fighters/crop.gd`. This class says which cel of which
## strip a fighter shows, and it decides that from the fight alone -- the
## move and the frame of it, the stun, the crouch -- never from a clock of its
## own. So a replay draws the same pictures as the fight it replays, and a
## move's picture keeps time with its boxes: the cels listed as a move's
## `active` are on screen on its active frames and on no others.
##
## The boxes stay the truth. A sprite is drawn to look like the move; the
## frame data decides what it hits, and the view draws the boxes over it.
##
## When not to use it: animation authored in the editor, with an
## `AnimationPlayer` driving the boxes. That is the other way round -- the
## picture leading and the data following -- and a frame-data lesson wants
## the data leading.
class_name FighterSprites
extends RefCounted

const PATH: String = "res://game/fighting/sprites.json"
## How many fight frames each cel of a looping animation is held for.
const FRAMES_PER_CEL: int = 6
## How many frames of walking each cel of the walk is held for, at any speed.
const WALK_FRAMES_PER_CEL: int = 4
## How many frames of hitstun each cel of the hit animation is held for.
const STUN_PER_CEL: int = 3
## The animations every character needs besides its moves.
const ANIMATIONS: Array[String] = ["idle", "walk", "crouch", "guard", "guard_crouching", "hit", "down", "jump"]

## Everything the file says.
var table: Dictionary = {}
# Every strip loaded so far, by path; null for one that is not on disk.
var _strips: Dictionary = {}


## The table at `path`, or an empty one when the file cannot be read: the
## fight then draws its blocks, as it did before there were pictures.
static func read(path: String = PATH) -> FighterSprites:
	var sprites := FighterSprites.new()
	if not FileAccess.file_exists(path):
		return sprites
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	sprites.table = parsed if parsed is Dictionary and (parsed as Dictionary).has("characters") else {}
	return sprites


## The cels an animation shows, in strip order. For a move: its startup
## cels, then its active ones, then its recovery.
func cels(character: String, animation: String) -> Array[int]:
	var drawn: Dictionary = table["characters"][character]
	var listed: Array = []
	if drawn["moves"].has(animation):
		for phase: String in ["startup", "active", "recovery"]:
			listed.append_array(drawn["moves"][animation][phase])
	else:
		listed = drawn["animations"][animation]
	# JSON reads every number as a float; a cel is a whole number.
	var found: Array[int] = []
	found.assign(listed.map(func(cel: float) -> int: return int(cel)))
	return found


## The strip for an animation, or null when it is not on disk. Loaded
## through `Art`, so a person's own strip at the same path under
## `Art.generated` is drawn instead (T31).
func strip(character: String, animation: String) -> Texture2D:
	var path: String = Art.fighter_strip(character, animation)
	if not _strips.has(path):
		_strips[path] = Art.texture(path) if ResourceLoader.exists(Art.resolve(path)) else null
	return _strips[path]


## True when the table covers everything the character can show -- every
## animation in `ANIMATIONS` and every move the frame data gives it -- and
## the strip of each, and of anything else the table lists, is on disk. A fighter is drawn from pictures only then,
## never half from blocks, and never with a move the table cannot draw.
func complete(character: String, data: FightData) -> bool:
	var drawn: Dictionary = table.get("characters", {}).get(character, {})
	if drawn.is_empty():
		return false
	var needed: Array = ANIMATIONS + data.character(character)["moves"].keys() + drawn["animations"].keys() \
			+ drawn["moves"].keys()
	for animation: String in needed:
		var listed: bool = drawn["animations"].has(animation) or drawn["moves"].has(animation)
		if not listed or strip(character, animation) == null:
			return false
	return true


## The size of one cel of a character's sheet, in pixels.
func cell(character: String) -> Vector2i:
	var sheet: Dictionary = table["sheets"][table["characters"][character]["sheet"]]
	return Vector2i(int(sheet["cell"][0]), int(sheet["cell"][1]))


## `[animation, index]`: which cel of which strip draws `fighter` now.
## `clock` is the fight's frame and `knocked_out` whether it has lost.
func pose(fighter: FighterState, data: FightData, clock: int, knocked_out: bool) -> Array:
	if knocked_out:
		return ["down", 0]
	if fighter.move != "":
		return [fighter.move, move_index(fighter, data)]
	if fighter.stun > 0 and fighter.stun_kind == "block":
		var guard: String = "guard_crouching" if fighter.crouching else "guard"
		return [guard, _held(guard, fighter, clock)]
	if fighter.stun > 0 and fighter.stun_kind == "hit":
		var last: int = cels(fighter.character, "hit").size() - 1
		return ["hit", last - mini(last, fighter.stun / STUN_PER_CEL)]
	if fighter.is_airborne():
		return ["jump", jump_index(fighter, data)]
	if fighter.stun_kind == "takeoff":
		return ["jump", 0]
	if fighter.crouching or fighter.stun_kind == "landing":
		return ["crouch", _held("crouch", fighter, clock)]
	if walks(fighter):
		var stride: int = int(data.character(fighter.character)["walk_speed"]) * WALK_FRAMES_PER_CEL
		return ["walk", posmod(fighter.x * fighter.facing / stride, cels(fighter.character, "walk").size())]
	return ["idle", _held("idle", fighter, clock)]


## True when the fighter's own input walked it this frame: free, standing,
## holding a direction. Read off the fight, so a fighter only pushed does
## not walk, and showing the same frame twice shows the same walk. Its cel
## is read off where it stands, so walking backwards plays it backwards.
static func walks(fighter: FighterState) -> bool:
	return fighter.is_free() and not fighter.crouching and FightInput.walk_direction(fighter.held_before) != 0


## The cel of the jump for the frame of it the fighter is on: the cels spread
## evenly over the whole arc, take-off first, so the picture rises and falls
## with the frame data.
func jump_index(fighter: FighterState, data: FightData) -> int:
	var shown: int = cels(fighter.character, "jump").size()
	return mini(shown - 1, (fighter.jump_frame - 1) * shown / data.jump_length(fighter.character))


## The cel of a move for the frame its fighter is on: each phase's cels
## spread evenly over that phase's frames, so the active cels are shown on
## the active frames and on no others.
func move_index(fighter: FighterState, data: FightData) -> int:
	var frames: Dictionary = data.move(fighter.character, fighter.move)
	var phases: Dictionary = table["characters"][fighter.character]["moves"][fighter.move]
	var before: int = 0
	var into: int = fighter.move_frame
	for phase: String in ["startup", "active", "recovery"]:
		var length: int = int(frames[phase])
		var shown: int = (phases[phase] as Array).size()
		if into <= length:
			return before + (into - 1) * shown / length
		before += shown
		into -= length
	return before - 1


# A looping animation's cel on this frame.
func _held(animation: String, fighter: FighterState, clock: int) -> int:
	return (clock / FRAMES_PER_CEL) % cels(fighter.character, animation).size()
