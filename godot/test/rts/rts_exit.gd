# T138's gate: the RTS, run for a few frames and closed, leaves nothing
# behind -- no "ObjectDB instances were leaked at exit", no "resources still
# in use at exit".
#
# A process cannot read what it prints after its own end, so this one starts
# a second Godot, the same binary with the same environment (`scripts/godot`
# set it), and reads that one's output. Both lines are printed whenever there
# is a leak, verbose or not (core/object/object.cpp's ObjectDB::cleanup and
# core/io/resource.cpp's ResourceCache::clear, read on 4.7.2-stable);
# `--verbose` adds the class of each leaked object and the path of each
# resource, which a failure prints.
#
#   1. a planted leak, `planted_exit_leak.gd`, is seen: the reading works,
#      and a run that printed nothing is not taken for a clean one;
#   2. the RTS scene, opened as `make demo-rts` opens it, closes clean.
#
# Measured on 4.7.2 (T138): headless shows the leak the window showed, the
# same 21 and 15, so the gate needs no display.
#
#     ./scripts/godot --headless --path godot -s res://test/rts/rts_exit.gd
#
# Exit codes: 0 both held; 1 one did not.
extends SceneTree

const SCENE: String = "res://game/rts/rts.tscn"
const PLANTED: String = "res://test/rts/planted_exit_leak.gd"
## Frames the scene runs before it quits: the leak was there from the first.
const FRAMES: int = 30
const LEAKED: String = "leaked at exit"
const IN_USE: String = "still in use at exit"


func _init() -> void:
	var failures: Array[String] = []
	var planted: Dictionary = _run(["-s", PLANTED])
	if not (_says(planted, LEAKED) and _says(planted, IN_USE)):
		failures.append("the planted leak was not seen: the gate cannot read an exit (exit %d)" % planted["code"])
	var scene: Dictionary = _run([SCENE, "--quit-after", str(FRAMES)])
	if scene["code"] != 0 or not _says(scene, "Godot Engine"):
		failures.append("%s did not run to its end (exit %d)" % [SCENE, scene["code"]])
	if _says(scene, LEAKED) or _says(scene, IN_USE):
		failures.append("%s left something alive at exit:\n%s" % [SCENE, "\n".join(_what_leaked(scene))])
	for failure: String in failures:
		print(failure)
	print("rts exit: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


## A headless child Godot on this project with `arguments`, verbose:
## {code: its exit code, output: everything it printed, both streams}.
## Waits for it, which is why this is a gate and never game code.
func _run(arguments: Array[String]) -> Dictionary:
	var project: String = ProjectSettings.globalize_path("res://")
	var full: Array[String] = ["--headless", "--verbose", "--path", project]
	full.append_array(arguments)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), full, output, true)
	return {"code": code, "output": "\n".join(output)}


## Whether the run printed `words` anywhere.
static func _says(run: Dictionary, words: String) -> bool:
	return (run["output"] as String).contains(words)


## The lines that name what was left: the two counts, each leaked object's
## class, each resource's path.
static func _what_leaked(run: Dictionary) -> Array[String]:
	var named: Array[String] = []
	for line: String in (run["output"] as String).split("\n"):
		if _names_a_leak(line):
			named.append(line)
	return named


## Whether `line` is a count of what was left, or names one thing left.
static func _names_a_leak(line: String) -> bool:
	return line.contains(LEAKED) or line.contains(IN_USE) or line.begins_with("Leaked instance") \
		or line.begins_with("Resource still in use")
