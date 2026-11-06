# The planted case of `rts_exit.gd` (T138): a run that leaks on purpose, so
# the gate shows it can see both exit lines before it believes a clean run.
#
# A Node made and never put in a tree nor freed is an ObjectDB instance at
# exit; the script it holds, loaded from a path, is a resource still in use.
# Not a test of its own: `make test-rts-exit` runs it in a child process.
extends SceneTree


func _init() -> void:
	var orphan := Node.new()
	orphan.set_meta("held", load("res://game/rts/rts_art.gd"))
	quit()
