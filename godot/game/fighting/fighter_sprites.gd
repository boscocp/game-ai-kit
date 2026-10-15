## Which picture draws a fighter on a frame, from `sprites.json` (T35).
##
## The pictures are strips: one animation's cels side by side, cut from a CC0
## template by `tools/fighters/crop.gd`. This class says which cel of which
## strip a fighter shows, and it decides that from the fight alone -- the
## move and the frame of it, the stun, the crouch -- never from a clock of its
## own. So a replay draws the same pictures as the fight it replays, and a
## move's picture can never disagree with its boxes: the cels listed as a
## move's `active` are the ones on screen exactly while its hitbox is out.
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
## How many units of the stage each cel of the walk is held for.
const UNITS_PER_CEL: int = 4
## How many frames of hitstun each cel of the hit animation is held for.
const STUN_PER_CEL: int = 4

## Everything the file says.
var table: Dictionary = {}
# Every strip loaded so far, by path; null for one that is not on disk.
var _strips: Dictionary = {}


## The table at `path`, or an empty one when the file cannot be read: the
## fight then draws its blocks, as it did before there were pictures.
static func read(path: String = PATH) -> FighterSprites:
	var sprites := FighterSprites.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	sprites.table = parsed if parsed is Dictionary else {}
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


## The strip for an animation, or null when it is not on disk.
func strip(character: String, animation: String) -> Texture2D:
	var path: String = Art.fighter_strip(character, animation)
	if not _strips.has(path):
		_strips[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _strips[path]


## True when every strip a character needs is on disk: a fighter is drawn
## from pictures only if all of them are there, never half from blocks.
func complete(character: String) -> bool:
	if table.is_empty() or not table["characters"].has(character):
		return false
	var drawn: Dictionary = table["characters"][character]
	for animation: String in drawn["animations"].keys() + drawn["moves"].keys():
		if strip(character, animation) == null:
			return false
	return true


## The size of one cel of a character's sheet, in pixels.
func cell(character: String) -> Vector2i:
	var sheet: Dictionary = table["sheets"][table["characters"][character]["sheet"]]
	return Vector2i(int(sheet["cell"][0]), int(sheet["cell"][1]))


## `[animation, index]`: which cel of which strip draws `fighter` now.
## `walking` is whether it moved since the frame before, `clock` the
## fight's frame, and `knocked_out` whether it has lost. A walk's cel is read
## off where the fighter stands, so walking backwards plays it backwards.
func pose(fighter: FighterState, data: FightData, walking: bool, clock: int, knocked_out: bool) -> Array:
	if knocked_out:
		return ["down", 0]
	if fighter.move != "":
		return [fighter.move, move_index(fighter, data)]
	if fighter.stun > 0 and fighter.stun_kind == "block":
		var guard: String = "guard_crouching" if fighter.crouching else "guard"
		return [guard, _held(guard, fighter, clock)]
	if fighter.stun > 0:
		var last: int = cels(fighter.character, "hit").size() - 1
		return ["hit", last - mini(last, fighter.stun / STUN_PER_CEL)]
	if fighter.crouching:
		return ["crouch", _held("crouch", fighter, clock)]
	if walking:
		return ["walk", posmod(fighter.x * fighter.facing / UNITS_PER_CEL, cels(fighter.character, "walk").size())]
	return ["idle", _held("idle", fighter, clock)]


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
