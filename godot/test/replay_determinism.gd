# Replay the recorded input log twice and assert the two runs agree on every
# frame. Determinism is what T17 and T18 rest on -- they learn from a
# person's logged inputs -- and it is cheap to assert and expensive to
# discover missing (T16).
#
#     ./scripts/godot --headless --path godot -s res://test/replay_determinism.gd
#
# Before trusting itself, it checks it can see a difference: the same log
# with one input changed must be reported as differing on exactly the frame
# after the change. A comparison that only knew how to agree would pass any
# engine (invariant 4). It also checks the log exercises something -- a hit,
# a block, a counter-hit and a trade -- because a log in which nobody
# touched anybody would replay identically under almost any bug.
#
# Exit codes: 0 the runs agree, 1 they differ or the planted change went
# unseen, 2 the log or the frame data could not be read.
extends SceneTree

const LOG_PATH: String = "res://test/fight_log.json"
## Events the log must cause, each at least once.
const EXERCISED: Array[String] = ["hits", "is blocked by", "counter-hits", "trade"]
## The frame whose input the planted change alters.
const PLANTED_FRAME: int = 150


func _init() -> void:
	quit(_run())


func _run() -> int:
	var data := FightData.read()
	var log: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOG_PATH))
	if data.refusal != "" or not log is Dictionary or (log as Dictionary).get("inputs", []).is_empty():
		printerr("replay_determinism: no usable log at %s or frame data (%s)" % [LOG_PATH, data.refusal])
		return 2
	var problems: Array[String] = _planted_change_is_seen(log, data)
	problems += _log_exercises_every_resolution(log, data)
	var first: Array[String] = FightReplay.digests(log, data)
	var second: Array[String] = FightReplay.digests(log, data)
	var differs_at: int = FightReplay.first_difference(first, second)
	if differs_at != -1:
		problems.append("the two runs differ at frame %d:\n  %s\n  %s" % [differs_at, first[differs_at], second[differs_at]])
	for problem: String in problems:
		print(problem)
	print("replay determinism: %d frames replayed twice, %d problem(s)" % [first.size(), problems.size()])
	return 1 if not problems.is_empty() else 0


# The planted case: one input changed at PLANTED_FRAME. The input of frame
# k makes frame k + 1, so that is where the runs must first differ.
static func _planted_change_is_seen(log: Dictionary, data: FightData) -> Array[String]:
	var changed: Dictionary = log.duplicate(true)
	var pair: Array = changed["inputs"][PLANTED_FRAME]
	pair[0] = int(pair[0]) ^ FightInput.LIGHT
	var differs_at: int = FightReplay.first_difference(FightReplay.digests(log, data), FightReplay.digests(changed, data))
	if differs_at != PLANTED_FRAME + 1:
		return ["the planted change at frame %d was seen at %d: the comparison cannot be trusted" % [PLANTED_FRAME, differs_at]]
	return []


static func _log_exercises_every_resolution(log: Dictionary, data: FightData) -> Array[String]:
	var happened: String = FightReplay.events(log, data)
	var missing: Array[String] = []
	for event: String in EXERCISED:
		if not happened.contains(event):
			missing.append("the log never causes a '%s', so a bug there would replay the same twice" % event)
	return missing
