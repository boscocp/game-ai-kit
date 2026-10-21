## Counts what the engine reports as an error while a racing check runs.
##
## A SCRIPT ERROR aborts the function it is in and the script still exits 0
## (CLAUDE.md's trap), so every `-s` check here counts them through a
## `Logger` and fails on any. One message is let through, by its text: under
## `--fixed-fps` Jolt warns once a run that its job system "exceeded the
## maximum number of jobs" and is "waiting for jobs to become available".
## Measured on 4.7.2: T50's own floor test prints it too when run that way,
## and nothing it checks changes. It is a warning, not an error, and only
## that one warning is forgiven.
class_name Racing3DErrors
extends Logger

const FORGIVEN: String = "Jolt Physics job system exceeded the maximum number of jobs"

var errors: int = 0
## The first few messages counted, to print with the failure.
var seen: Array[String] = []


func _log_error(_function: String, _file: String, _line: int, code: String,
		rationale: String, _editor_notify: bool, error_type: int,
		_script_backtraces: Array[ScriptBacktrace]) -> void:
	var text: String = "%s %s" % [code, rationale]
	if error_type == Logger.ERROR_TYPE_WARNING and FORGIVEN in text:
		return
	errors += 1
	if seen.size() < 5:
		seen.append(text)


func _log_message(_message: String, _error: bool) -> void:
	pass


## The planted case every script runs first (invariant 4): an error pushed
## with a marker must be counted exactly once, or the counter is blind. The
## count is cleared after, so the marker's printed ERROR line is the only
## trace it leaves. Returns the finding, or "" when the counter saw it.
func self_check() -> String:
	errors = 0
	seen.clear()
	push_error("Racing3DErrors self-check: this error is planted, and must be counted")
	var counted: int = errors
	errors = 0
	seen.clear()
	if counted != 1:
		return "planted, an engine error: the counter saw %d of 1" % counted
	return ""


## The finding to report, or "" when nothing was counted.
func finding(during: String) -> String:
	if errors == 0:
		return ""
	return "%d engine error(s) during %s: %s" % [errors, during, "; ".join(seen)]
