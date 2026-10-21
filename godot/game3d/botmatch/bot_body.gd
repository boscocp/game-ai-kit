## One bot as a person sees it: Kenney's survivor (CC0) when `make
## assets-3d` has fetched it, with its own skin tinted to the team's colour
## and its idle and run played as the bot stands or moves; and a humanoid of
## boxes when it has not -- head, torso, arms and legs, the hit zones drawn.
##
## Seen only. Where a shot lands is the rules' zones, not this mesh: the
## survivor's limbs swing as it runs, and a hit read off a swinging arm
## would make the match depend on a download.
class_name BotBody
extends Node3D

const HEIGHT: float = 1.8
const IDLE: StringName = &"idle"
const RUN: StringName = &"run"
## Each animation's name inside its file, as Kenney's export gives it.
const TAKES: Dictionary = {IDLE: "Root|Idle", RUN: "Root|Run"}
## Moving at least this fast, in metres a second, it runs.
const RUNNING: float = 0.5

var _player: AnimationPlayer
var _last: Vector3 = Vector3.INF


## Built from `shelf`, coloured `colour`: the skin tinted with it, or the
## boxes painted it.
func _init(shelf: AssetShelf, colour: Color) -> void:
	var skin: Texture2D = shelf.resource("soldier_skin") as Texture2D
	var look: Node3D = shelf.model("soldier", HEIGHT, colour)
	add_child(look)
	if skin == null or not shelf.has_model("soldier"):
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = skin
	material.albedo_color = colour.lerp(Color.WHITE, 0.35)
	for mesh: MeshInstance3D in look.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
	_player = _animations(shelf, look.get_child(0))


## Put it at `place`, facing `facing` (the match's radians), crouched or
## not, `delta` seconds after the last time; it runs when it moved.
func stand(place: Vector3, facing: float, crouched: bool, delta: float) -> void:
	var moved: float = 0.0 if _last == Vector3.INF else place.distance_to(_last) / maxf(delta, 1e-3)
	_last = place
	position = place
	rotation = Vector3(0, -facing + PI / 2.0, 0)
	scale = Vector3(1, 0.6 if crouched else 1.0, 1)
	if _player != null:
		var wanted: StringName = RUN if moved >= RUNNING else IDLE
		if _player.current_animation != wanted:
			_player.play(wanted, 0.15)


# An AnimationPlayer on the model's own root, holding the idle and the run
# copied out of their files: their tracks name the same skeleton path.
func _animations(shelf: AssetShelf, model_root: Node) -> AnimationPlayer:
	var library := AnimationLibrary.new()
	for take: StringName in TAKES:
		var scene: PackedScene = shelf.resource("soldier_" + str(take)) as PackedScene
		if scene == null:
			continue
		var source: Node = scene.instantiate()
		var players: Array[Node] = source.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty() and (players[0] as AnimationPlayer).has_animation(TAKES[take]):
			var animation: Animation = (players[0] as AnimationPlayer).get_animation(TAKES[take]).duplicate()
			animation.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(take, animation)
		source.free()
	var player := AnimationPlayer.new()
	model_root.add_child(player)
	player.add_animation_library(&"", library)
	return player
