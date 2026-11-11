## The shape of a conformance vector, written like the JSON it describes,
## and the one question every vectors runner asks before it reads a file:
## where does this file part from that shape?
##
## Why it exists (T121): a runner is a `-s` script, and in one a cast that
## fails -- a string where a list should be -- is a SCRIPT ERROR that aborts
## the function it happens in. The run carries on, prints "0 failure(s)" and
## exits 0 (CLAUDE.md, the traps). A vector gate that goes green on a file it
## could not read is the defect invariant 4 names. So each family states the
## types it reads, once, as a shape, and its runner exits 2 on a file that
## does not match, before anything reads a field.
##
## A shape is a value like the file's own:
##
##     {"seed": NUMBER, "draws": [NUMBER], "name?": TEXT, "board": [[NUMBER]]}
##
## - a dictionary: the value is an object, every key is there and matches;
##   a key ending in `?` may be absent, and `*` matches every key the shape
##   does not name (a table keyed by names);
## - a one-item list: the value is a list, every item matches that item;
## - a leaf below: what one value must be.
##
## Only types. Whether a list may be empty, whether two lists agree in
## length, which keys a file may not add: those stay each family's rules.
## Test code, not an addon (invariant 2), and owned by no module: every
## family's gate stands on it, so `scripts/check_modules.py` lists it as
## global, and a change here selects them all.
##
## When not to use it: inside an addon. A vector's shape is the test's
## business; a game reads its own data through its own checks.
class_name VectorShape
extends RefCounted

## A number. JSON has one kind; Godot parses every number as a float, so a
## whole number in the file is a float here too and both are accepted.
const NUMBER: int = TYPE_FLOAT
## Text: a name, a word, a line of a map.
const TEXT: int = TYPE_STRING
## `true` or `false`.
const FLAG: int = TYPE_BOOL
## Any object at all: its keys are read by something that checks them.
const OBJECT: int = TYPE_DICTIONARY
## Any list at all: its items are read by something that checks them.
const LIST: int = TYPE_ARRAY
## Anything, null included: read only by a comparison that copes with any
## value, never cast.
const ANY: int = TYPE_NIL
## A number, an object or a list, or null where the file means "none": an
## unbounded cost, a puzzle with no solution, a map never finished.
const NUMBER_OR_NULL: int = TYPE_MAX + TYPE_FLOAT
const OBJECT_OR_NULL: int = TYPE_MAX + TYPE_DICTIONARY
const LIST_OR_NULL: int = TYPE_MAX + TYPE_ARRAY


## Where `value` parts from `shape`, as "<where> is not <what>", or "" when
## it matches. The first mismatch is enough: the runner names it and stops.
static func why_not(value: Variant, shape: Variant, where: String = "the file") -> String:
	if shape is Dictionary:
		return _why_not_an_object(value, shape, where)
	if shape is Array:
		return _why_not_a_list(value, shape, where)
	if _is_leaf(value, int(shape)):
		return ""
	return "%s is not %s" % [where, _named(int(shape))]


## A file under `spec/`, parsed, as the families' suites read their real
## vectors: `read_spec("vectors/search/optimal-path.json")`.
static func read_spec(path_under_spec: String) -> Variant:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec").path_join(path_under_spec)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## A deep copy of `vector` with the value at `path` -- keys and indices,
## outermost first -- replaced by `value`. How a suite plants a wrong type
## in a real file without touching the file.
static func planted(vector: Variant, path: Array, value: Variant) -> Variant:
	var copy: Variant = vector.duplicate(true)
	var holder: Variant = copy
	for step: Variant in path.slice(0, path.size() - 1):
		holder = holder[step]
	holder[path[-1]] = value
	return copy


static func _why_not_an_object(value: Variant, shape: Dictionary, where: String) -> String:
	if not value is Dictionary:
		return "%s is not an object" % where
	for key: String in shape:
		var why: String = _why_not_a_field(value, key, shape[key], where)
		if why != "":
			return why
	if shape.has("*"):
		return _why_not_a_table(value, shape, where)
	return ""


# One key the shape names: absent, which only an optional key may be, or
# held to its own shape. `*` is the table's, asked after every named key.
static func _why_not_a_field(value: Dictionary, key: String, shape: Variant, where: String) -> String:
	if key == "*":
		return ""
	var name: String = key.trim_suffix("?")
	if not value.has(name):
		return "" if key.ends_with("?") else "%s has no %s" % [where, name]
	return why_not(value[name], shape, "%s.%s" % [where, name])


# The keys the shape does not name, each held to its `*`.
static func _why_not_a_table(value: Dictionary, shape: Dictionary, where: String) -> String:
	for key: Variant in value:
		if shape.has(str(key)) or shape.has(str(key) + "?"):
			continue
		var why: String = why_not(value[key], shape["*"], "%s.%s" % [where, key])
		if why != "":
			return why
	return ""


static func _why_not_a_list(value: Variant, shape: Array, where: String) -> String:
	if not value is Array:
		return "%s is not a list" % where
	for index: int in (value as Array).size():
		var why: String = why_not(value[index], shape[0], "%s[%d]" % [where, index])
		if why != "":
			return why
	return ""


static func _is_leaf(value: Variant, leaf: int) -> bool:
	if leaf == ANY:
		return true
	if leaf > TYPE_MAX:
		return value == null or _is_leaf(value, leaf - TYPE_MAX)
	if leaf == NUMBER:
		return value is float or value is int
	return typeof(value) == leaf


static func _named(leaf: int) -> String:
	if leaf > TYPE_MAX:
		return _named(leaf - TYPE_MAX) + " or null"
	match leaf:
		NUMBER:
			return "a number"
		TEXT:
			return "text"
		FLAG:
			return "true or false"
		OBJECT:
			return "an object"
		LIST:
			return "a list"
	return "of type %s" % type_string(leaf)
