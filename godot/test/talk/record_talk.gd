# Records the guard's conversations from a running local model, through the
# game's own path. Not a test: `make check` never runs it, because it needs a
# model (tier 3). `make record-talk` runs it while `make llm-serve` is serving.
#
#     ./scripts/godot --headless --path godot -s res://test/talk/record_talk.gd -- \
#         LINES.json OUTPUT_DIR MODEL_NAME [CONVERSATION]
#
# For each conversation in LINES.json (data/talk/lines.json), in each
# language, a `TalkGuard` answers through a `RecordingRuntime` around an
# `HttpRuntime` -- the request, the prompt and the validator are the game's
# own -- line by line until the guard decides or the lines run out. The
# player's lines and the model's texts, untouched, go to
# OUTPUT_DIR/<conversation>.<language>.json, with the model that answered
# (named in tools/llm/runtime.json) and the day. A conversation the server
# failed to answer is not saved. Exit 0 when every conversation was saved,
# 1 when one was not, 2 on wrong usage.
extends SceneTree

## The longest a line may wait for its answer before the recording gives up.
const ANSWER_SECONDS: float = 120.0
const LANGUAGES: Array[String] = ["en", "pt_BR"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() < 3:
		printerr("record_talk: LINES.json OUTPUT_DIR MODEL_NAME [CONVERSATION]")
		quit(2)
		return
	var lines: Variant = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	var model: Dictionary = _model_named(arguments[2])
	if not (lines is Dictionary) or model.is_empty():
		printerr("record_talk: cannot read %s, or no model %s in tools/llm/runtime.json" % [
			arguments[0], arguments[2]])
		quit(2)
		return
	var only: String = arguments[3] if arguments.size() > 3 else ""
	var unsaved: int = 0
	for conversation: Dictionary in lines["conversations"]:
		if only == "" or conversation["name"] == only:
			unsaved += await _record_both(conversation, model, arguments[1])
	quit(1 if unsaved > 0 else 0)


# One conversation in each language; how many were not saved.
func _record_both(conversation: Dictionary, model: Dictionary, folder: String) -> int:
	var unsaved: int = 0
	for language: String in LANGUAGES:
		if await _record(conversation, language, model, folder) != OK:
			unsaved += 1
	return unsaved


# One conversation in one language, recorded and saved; the error, or OK.
func _record(conversation: Dictionary, language: String, model: Dictionary, folder: String) -> Error:
	var guard := TalkGuard.new(language)
	root.add_child(guard)
	guard.use_runtime(RecordingRuntime.new(HttpRuntime.new()))
	for line: String in conversation[language]:
		if guard.has_decided():
			break
		var started: float = Time.get_ticks_msec() / 1000.0
		if guard.say(line) != OK:
			break
		while guard.is_thinking() and Time.get_ticks_msec() / 1000.0 - started < ANSWER_SECONDS:
			await process_frame
		var turn: Dictionary = guard.turns.back() if not guard.turns.is_empty() else {}
		print("record_talk: %s %s %d %s %s %s %+d %+d %.2f s" % [conversation["name"], language,
			turn.get("turn", 0), turn.get("intent", ""), turn.get("argument", ""),
			turn.get("refusal_code", ""), turn.get("trust_moved", 0), turn.get("suspicion_moved", 0),
			turn.get("seconds", 0.0)])
	var path: String = folder.path_join("%s.%s.json" % [conversation["name"], language])
	var saved: Error = guard.save_recording(path, _about(conversation, language, model))
	print("record_talk: %s -> %s (%s)" % [path, error_string(saved), guard.state["outcome"]])
	guard.queue_free()
	return saved


func _about(conversation: Dictionary, language: String, model: Dictionary) -> Dictionary:
	return {
		"about": "A conversation with the guard at the door (T94), as a local model answered it: each line the player said and the model's text, untouched. Replayed by gameaikit.talk.replay and the game's recorded mode; see README.md beside this file for the model and its licence.",
		"conversation": conversation["name"],
		"language": language,
		"model": model,
		"recorded_on": Time.get_date_string_from_system(),
	}


# The model's entry in tools/llm/runtime.json: what answered, by file and sha256.
func _model_named(name: String) -> Dictionary:
	var manifest_path: String = ProjectSettings.globalize_path("res://").path_join(
		"../tools/llm/runtime.json").simplify_path()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not (manifest is Dictionary) or not (manifest["models"] as Dictionary).has(name):
		return {}
	var entry: Dictionary = manifest["models"][name]
	return {"name": name, "file": entry["file"], "sha256": entry["sha256"],
		"licence": entry["licence"], "server": "llama.cpp %s" % manifest["runtime"]["tag"]}
