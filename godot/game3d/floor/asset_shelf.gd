## Where a 3D example gets a model: the downloaded file, or a primitive.
##
## ADR 0018 keeps every 3D pack out of git. `assets.json` names each file the
## examples use, `make assets-3d` downloads them into `game3d/downloaded/`,
## and this shelf hands back the model when it is there and imported, and a
## plain shape when it is not -- a capsule for a bot, a box for cover, a box
## on four wheels for a car. So every example runs on a fresh checkout, in CI
## and in `make check`, and the AI it shows is the same either way.
##
## When not to use it: for anything a decision reads. A model is what a person
## sees; what a bot reasons with is the snapshot, and it never asks the shelf.
class_name AssetShelf
extends RefCounted

const MANIFEST: String = "res://game3d/assets.json"
## The primitives a manifest row may fall back to. "none" is a file that is
## not a model on its own, such as the texture a model points at.
const FALLBACKS: Array[String] = ["capsule", "box", "car", "none"]

## The folder the files are read from, `res://` and ending in a slash.
var into: String = ""
# Each manifest row, by its name.
var _rows: Dictionary = {}


## Reads `manifest_path`. `folder` replaces the manifest's own folder, which
## is how a test plants a checkout where nothing was downloaded.
func _init(manifest_path: String = MANIFEST, folder: String = "") -> void:
	var text: String = FileAccess.get_file_as_string(manifest_path)
	var manifest: Variant = JSON.parse_string(text)
	if not (manifest is Dictionary):
		push_error("AssetShelf: cannot read %s" % manifest_path)
		return
	into = folder if folder != "" else "res://%s/" % str(manifest["into"]).trim_prefix("godot/")
	for row: Dictionary in manifest["files"]:
		_rows[str(row["name"])] = row


## Whether the named file is on disk and Godot has imported it, so `model`
## will hand back the real thing. A file downloaded and not yet imported
## (`make import`) is not there yet, as far as the engine is concerned.
func has_model(model_name: String) -> bool:
	return _rows.has(model_name) and ResourceLoader.exists(_path_of(model_name))


## The named model, `height` metres tall, standing on its origin. Tinted
## `colour` when it is a primitive; a downloaded model keeps its own colours.
## A name the manifest lacks, or a row that is not a model ("none", such as a
## texture), is a mistake in the caller: it is reported, and drawn as a box so
## the scene still loads.
func model(model_name: String, height: float, colour: Color) -> Node3D:
	var kind: String = str(_rows.get(model_name, {}).get("fallback", "none"))
	if kind == "none":
		push_error("AssetShelf: %s is not a model in the manifest" % model_name)
		return primitive("box", height, colour)
	if has_model(model_name):
		var packed: PackedScene = load(_path_of(model_name)) as PackedScene
		if packed != null:
			return _scaled_to(packed.instantiate() as Node3D, height)
	return primitive(kind, height, colour)


## A plain shape of `kind` (one of FALLBACKS but "none"), `height` tall.
static func primitive(kind: String, height: float, colour: Color) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Primitive_%s" % kind
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if kind == "capsule":
		var capsule := CapsuleMesh.new()
		capsule.height = height
		capsule.radius = height * 0.25
		_add_mesh(holder, capsule, material, Vector3(0, height * 0.5, 0))
	elif kind == "car":
		var body := BoxMesh.new()
		body.size = Vector3(height * 1.6, height * 0.5, height * 3.4)
		_add_mesh(holder, body, material, Vector3(0, height * 0.55, 0))
		for corner: Vector3 in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = height * 0.3
			wheel.bottom_radius = height * 0.3
			wheel.height = height * 0.25
			var place := Vector3(corner.x * height * 0.85, height * 0.3, corner.z * height * 1.1)
			_add_mesh(holder, wheel, material, place).rotation = Vector3(0, 0, PI / 2)
	else:
		var box := BoxMesh.new()
		box.size = Vector3(height, height, height)
		_add_mesh(holder, box, material, Vector3(0, height * 0.5, 0))
	return holder


func _path_of(model_name: String) -> String:
	return into + str(_rows[model_name]["saved_as"])


static func _add_mesh(holder: Node3D, mesh: Mesh, material: Material, place: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = place
	holder.add_child(instance)
	return instance


# A pack's models come in their author's units and stand where their author
# put them; the examples ask for metres, feet on the origin. The model's box
# is every mesh's box carried up to the model's root, and the model is hung
# inside a holder that scales it and lifts its lowest point to zero.
static func _scaled_to(node: Node3D, height: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Model"
	holder.add_child(node)
	var bounds: AABB = bounds_of(node)
	if bounds.size.y <= 0.0:
		return holder
	var factor: float = height / bounds.size.y
	node.scale = Vector3.ONE * factor
	node.position = Vector3(0, -bounds.position.y * factor, 0)
	return holder


## Every mesh's box in `root`'s own space, merged: how big a model is and
## where it stands, which a test asks of what `model` handed back. A skinned
## mesh is measured at rest, which is the pose a model is placed in.
static func bounds_of(root: Node3D) -> AABB:
	var bounds := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = _transform_to(root, mesh) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


# The transform from `node`'s space to `root`'s, walked up the parents: the
# nodes are not in the tree yet, so there is no global transform to ask.
static func _transform_to(root: Node3D, node: Node3D) -> Transform3D:
	var carried := Transform3D.IDENTITY
	var step: Node = node
	while step != root and step is Node3D:
		carried = (step as Node3D).transform * carried
		step = step.get_parent()
	return carried
