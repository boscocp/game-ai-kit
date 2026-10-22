## Counts what the engine reports as an error while a perception check runs.
##
## A SCRIPT ERROR aborts the function it is in and an `-s` script still exits
## 0 (CLAUDE.md's trap), so the vectors runner and the properties count them
## through a `Logger` and fail on any. `self_check` is its planted case: an
## error pushed on purpose must be counted, or the counter is blind.
##
## When not to use it: inside a gdUnit suite, which reports errors itself.
class_name PerceptionErrors
extends Logger

var count: int = 0


func _log_error(_function: String, _file: String, _line: int, _code: String,
		_rationale: String, _editor_notify: bool, _error_type: int,
		_script_backtraces: Array[ScriptBacktrace]) -> void:
	count += 1


func _log_message(_message: String, _error: bool) -> void:
	pass


## The planted case: one pushed error must be counted once. "" when it was;
## the count is cleared after either way.
func self_check() -> String:
	count = 0
	push_error("PerceptionErrors self-check: this error is planted, and must be counted")
	var counted: int = count
	count = 0
	return "" if counted == 1 else "planted, an engine error: the counter saw %d of 1" % counted
