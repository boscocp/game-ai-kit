## Load every script the published archive put under `res://addons/`.
##
## Run by `scripts/check_published.py`, through `scripts/godot_checked.py
## --project`, in a blank project holding only the unzipped store download.
## An import does not fail on a script that does not parse (measured on
## 4.7.2: it registers the `class_name` and exits 0), so every script is
## loaded here, and every `class_name` the import registered is counted.
##
## It prints one line, `PUBLISHED-CHECK: <scripts> script(s) loaded,
## <classes> class_name(s) registered`, which the caller compares with
## what it counted in the zip. A script that does not parse prints a
## `SCRIPT ERROR: Parse Error` line, and `godot_checked.py` fails the run
## on it whatever this exits. That line is the only sign: measured on
## 4.7.2, `load` still hands back a `Script` for such a file, and the run
## exits 0 (CLAUDE.md, "A script error in a `-s` script does not fail the
## run").
extends SceneTree

const ADDONS: String = "res://addons"


func _initialize() -> void:
	var scripts: PackedStringArray = scripts_under(ADDONS)
	var loaded: int = 0
	for path: String in scripts:
		if load(path) is Script:
			loaded += 1
		else:
			printerr("ERROR: %s does not load in a stranger's project" % path)
	var classes: int = registered_classes()
	print("PUBLISHED-CHECK: %d script(s) loaded, %d class_name(s) registered" % [loaded, classes])
	quit(0 if loaded == scripts.size() else 1)


## Every `.gd` file below `folder`, walked depth first.
##
## Why a walk and not the class list: a script with no `class_name` is in
## no list, and it ships all the same.
func scripts_under(folder: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for name: String in DirAccess.get_files_at(folder):
		if name.get_extension() == "gd":
			found.append(folder.path_join(name))
	for name: String in DirAccess.get_directories_at(folder):
		found.append_array(scripts_under(folder.path_join(name)))
	return found


## How many `class_name`s the import registered from under `res://addons/`.
##
## Why: a class the import did not register is a type no game can name,
## and loading its file by path would not show that.
func registered_classes() -> int:
	var count: int = 0
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["path"]).begins_with(ADDONS + "/"):
			count += 1
	return count
