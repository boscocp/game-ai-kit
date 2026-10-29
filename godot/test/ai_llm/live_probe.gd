# Sends player lines to a running local LLM server, through the game's own path.
#
# Not a test: `make check` never runs it, because it needs a model (tier 3).
# `scripts/llm smoke` runs it with one line and `scripts/llm bakeoff` with
# all of them (T93); both start the server first and stop it after. Each line
# goes through `HttpRuntime` at its default URL -- the port the game itself
# asks -- and `LlmConversation`, so what is timed and validated is what a
# game would get. Each line is a conversation of its own.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_llm/live_probe.gd -- \
#         LINES.json LANGUAGE COUNT OUTPUT.json
#
# LINES.json declares the intents, the secrets, each language's instructions
# and fallback line, and the lines; COUNT 0 sends them all. OUTPUT.json gets,
# per line, the reply as the validator ruled it, the seconds from `say` to
# `answered`, and the worst frame while the guard was thinking -- the frame
# must keep being drawn (invariant 7). Exit 0 when every line was answered,
# 1 when one was not, 2 on wrong usage.
extends SceneTree

## The longest a line may wait for its answer before the probe gives up.
const ANSWER_SECONDS: float = 120.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 4:
		printerr("live_probe: LINES.json LANGUAGE COUNT OUTPUT.json")
		quit(2)
		return
	var declared: Variant = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	var language: String = arguments[1]
	if not (declared is Dictionary) or not (declared["languages"] as Dictionary).has(language):
		printerr("live_probe: %s is not a lines file with language %s" % [arguments[0], language])
		quit(2)
		return
	var lines: Array = declared["lines"]
	var count: int = int(arguments[2]) if int(arguments[2]) > 0 else lines.size()
	var turns: Array[Dictionary] = []
	for index: int in mini(count, lines.size()):
		var turn: Dictionary = await _one_turn(declared, language, lines[index][language])
		turn["index"] = index
		turns.append(turn)
		print("live_probe: %d %s %s %.2f s" % [index, turn["intent"], turn["refusal_code"], turn["seconds"]])
	var report: Dictionary = {"language": language, "turns": turns}
	var output := FileAccess.open(arguments[3], FileAccess.WRITE)
	output.store_string(JSON.stringify(report, " ") + "\n")
	output.close()
	var unanswered: int = turns.filter(func(turn: Dictionary) -> bool: return turn["seconds"] < 0.0).size()
	quit(1 if unanswered > 0 else 0)


# One line, one fresh conversation: the reply as ruled, its time, the worst frame.
func _one_turn(declared: Dictionary, language: String, line: String) -> Dictionary:
	var runtime := HttpRuntime.new()
	root.add_child(runtime)
	var spoken: Dictionary = declared["languages"][language]
	var validator := LlmValidator.new(declared["intents"], spoken["fallback"],
		PackedStringArray(declared["secrets"]))
	var conversation := LlmConversation.new(runtime, validator, spoken["instructions"])
	var replies: Array[LlmReply] = []
	conversation.answered.connect(func(reply: LlmReply) -> void: replies.append(reply))
	var started: int = Time.get_ticks_usec()
	var last_frame: int = started
	var worst_frame_ms: float = 0.0
	if conversation.say(line) != OK:
		return _turn(line, null, -1.0, 0.0)
	while replies.is_empty() and Time.get_ticks_usec() - started < ANSWER_SECONDS * 1e6:
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst_frame_ms = maxf(worst_frame_ms, (now - last_frame) / 1000.0)
		last_frame = now
	var seconds: float = (Time.get_ticks_usec() - started) / 1e6
	runtime.queue_free()
	if replies.is_empty():
		return _turn(line, null, -1.0, worst_frame_ms)
	return _turn(line, replies[0], seconds, worst_frame_ms)


# What one turn is written down as. A reply of null means none came.
func _turn(line: String, reply: LlmReply, seconds: float, worst_frame_ms: float) -> Dictionary:
	if reply == null:
		return {"line": line, "speech": "", "intent": "", "argument": "",
			"refusal_code": "none", "refusal": "no answer", "seconds": seconds,
			"worst_frame_ms": worst_frame_ms}
	return {"line": line, "speech": reply.speech, "intent": reply.intent,
		"argument": reply.argument, "refusal_code": reply.refusal_code(),
		"refusal": reply.refusal, "seconds": snappedf(seconds, 0.001),
		"worst_frame_ms": snappedf(worst_frame_ms, 0.01)}
