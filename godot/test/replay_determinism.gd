# Replay the recorded input log and assert it gives, frame by frame, the
# digests recorded beside it -- and the same digests twice in this run.
# Determinism is what T17 and T18 rest on, since they learn from a person's
# logged inputs, and it is cheap to assert and expensive to discover missing
# (T16).
#
#     ./scripts/godot --headless --path godot -s res://test/replay_determinism.gd
#     ./scripts/godot --headless --path godot -s res://test/replay_determinism.gd -- --record
#
# Two comparisons, because each misses what the other sees. Two runs in one
# process agree on anything fixed for the life of the process -- a seed, a
# process id, a cache filled at load -- so the run is also held to digests
# recorded by an earlier process, in `fight_log_digests.txt`. A change to the
# rules changes them, on purpose: `make record-replay` writes them again, and
# the diff shows which frames moved.
#
# Before trusting itself it checks it can see a difference: one input changed
# for each player must be reported on exactly the frame after, and the digest
# must change when any fighter's position does -- a digest that left a player
# out would agree about everything that player did. And it checks the log
# exercises something: a hit, a block, a counter-hit, a trade, a cancel, a
# low through a standing guard, an overhead through a crouching one, a
# throw, a high passing over a crouch -- and, since T38, a jump-in hitting,
# an anti-air knocking a jump out of the air, and a low passing under one;
# since T40, a strike and a throw passing through a backdash, and a strike
# catching one that can no longer guard.
#
# Exit codes: 0 the runs agree, 1 they differ or a planted change went unseen,
# 2 the log, the recorded digests or the frame data could not be read.
extends SceneTree

const LOG_PATH: String = "res://test/fight_log.json"
const DIGESTS_PATH: String = "res://test/fight_log_digests.txt"
## Events the log must cause, each at least once.
## " hits p", with its space, so that a counter-hit does not count as a hit.
const EXERCISED: Array[String] = [" hits p", "is blocked by", "counter-hits", "trade", "cancels",
		"(a low through a standing guard)", "(an overhead through a crouching guard)", "throws p", "passes over",
		"p1 hits p2 with flying_kick", "counter-hits p1 with uppercut", "passes under p1",
		"p1's sweep passes through p2 (evading)", "p2's throw passes through p1 (evading)",
		"(caught evading, which cannot guard)"]
## The frame whose input each planted change alters.
const PLANTED_FRAME: int = 150


func _init() -> void:
	quit(_run(OS.get_cmdline_user_args().has("--record")))


func _run(recording: bool) -> int:
	var data := FightData.read()
	var input_log: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOG_PATH))
	if data.refusal != "" or not input_log is Dictionary or (input_log as Dictionary).get("inputs", []).is_empty():
		printerr("replay_determinism: no usable log at %s or frame data (%s)" % [LOG_PATH, data.refusal])
		return 2
	var first: Array[String] = FightReplay.digests(input_log, data)
	if recording:
		FileAccess.open(DIGESTS_PATH, FileAccess.WRITE).store_string("\n".join(first) + "\n")
		print("replay determinism: recorded %d frames to %s" % [first.size(), DIGESTS_PATH])
		return 0
	var recorded: Array[String] = _recorded_digests()
	if recorded.is_empty():
		printerr("replay_determinism: no recorded digests at %s; run `make record-replay`" % DIGESTS_PATH)
		return 2
	var problems: Array[String] = _planted_changes_are_seen(input_log, data)
	problems += _log_exercises_every_resolution(input_log, data)
	problems += _differences("this run and the recorded digests", first, recorded)
	problems += _differences("two runs in this process", first, FightReplay.digests(input_log, data))
	for problem: String in problems:
		print(problem)
	print("replay determinism: %d frames against the record and replayed twice, %d problem(s)" % [first.size(), problems.size()])
	return 1 if not problems.is_empty() else 0


static func _recorded_digests() -> Array[String]:
	var lines: Array[String] = []
	# Split as written, one digest a line: a digest can end in a space, so
	# nothing is stripped but the newline after the last one.
	lines.assign(FileAccess.get_file_as_string(DIGESTS_PATH).split("\n"))
	if not lines.is_empty() and lines[lines.size() - 1] == "":
		lines.pop_back()
	return lines


static func _differences(what: String, first: Array[String], second: Array[String]) -> Array[String]:
	var at: int = FightReplay.first_difference(first, second)
	if at == -1:
		return []
	var one: String = first[at] if at < first.size() else "(no frame)"
	var other: String = second[at] if at < second.size() else "(no frame)"
	return ["%s differ at frame %d:\n  %s\n  %s" % [what, at, one, other]]


# The planted cases: one input changed at PLANTED_FRAME for each player in
# turn -- the input of frame k makes frame k + 1, so that is where the runs
# must first differ -- and a moved fighter, which the digest must show.
static func _planted_changes_are_seen(input_log: Dictionary, data: FightData) -> Array[String]:
	var problems: Array[String] = []
	var original: Array[String] = FightReplay.digests(input_log, data)
	for player: int in range(2):
		var changed: Dictionary = input_log.duplicate(true)
		changed["inputs"][PLANTED_FRAME][player] = int(changed["inputs"][PLANTED_FRAME][player]) ^ FightInput.LIGHT_PUNCH
		var at: int = FightReplay.first_difference(original, FightReplay.digests(changed, data))
		if at != PLANTED_FRAME + 1:
			problems.append("player %d's planted change at frame %d was seen at %d" % [player + 1, PLANTED_FRAME, at])
	var state: FightState = FightState.starting(data, input_log["characters"][0], input_log["characters"][1])
	for player: int in range(2):
		var moved: FightState = state.copy()
		moved.fighters[player].x += 1
		if moved.digest() == state.digest():
			problems.append("the digest does not change when player %d moves: it leaves something out" % (player + 1))
	return problems


static func _log_exercises_every_resolution(input_log: Dictionary, data: FightData) -> Array[String]:
	var happened: String = FightReplay.events(input_log, data)
	var missing: Array[String] = []
	for event: String in EXERCISED:
		if not happened.contains(event):
			missing.append("the log never causes a '%s', so a bug there would replay the same twice" % event)
	return missing
