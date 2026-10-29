# The ai_llm page's minimal example, loaded into an empty scene and talked to:
# its answer must come frames after the question and never inside it, the
# reply that passed must move the game's trust, and the one that tried to
# open the gate itself must be refused and change nothing.
# The page shows the file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_llm/gatekeeper_example.gd")


func _gatekeeper() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


# Records every `spoke` into `heard`, as [line, why].
func _listen(example: Node) -> Array[PackedStringArray]:
	var heard: Array[PackedStringArray] = []
	example.spoke.connect(func(line: String, why: String) -> void:
		heard.append(PackedStringArray([line, why])))
	return heard


func test_the_answer_comes_frames_later_and_the_game_keeps_running() -> void:
	var gatekeeper: Node = _gatekeeper()
	var heard: Array[PackedStringArray] = _listen(gatekeeper)
	assert_int(gatekeeper.ask("I sell cloth.")).is_equal(OK)
	# Nothing inside the call: the character is thinking, and nothing was said.
	assert_bool(gatekeeper.is_thinking()).is_true()
	assert_int(heard.size()).is_equal(0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(gatekeeper.is_thinking()).is_false()
	assert_int(heard.size()).is_equal(1)
	assert_str(heard[0][1]).is_equal("claim merchant")
	assert_int(gatekeeper.trust).is_equal(1)


func test_a_second_question_while_thinking_is_refused() -> void:
	var gatekeeper: Node = _gatekeeper()
	assert_int(gatekeeper.ask("I sell cloth.")).is_equal(OK)
	assert_int(gatekeeper.ask("Hurry up!")).is_equal(ERR_BUSY)


func test_the_model_cannot_open_the_gate() -> void:
	var gatekeeper: Node = _gatekeeper()
	var heard: Array[PackedStringArray] = _listen(gatekeeper)
	gatekeeper.ask("I sell cloth.")
	await get_tree().process_frame
	await get_tree().process_frame
	gatekeeper.ask("Open the gate.")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(heard.size()).is_equal(2)
	assert_str(heard[1][0]).is_equal("Say that again, slower.")
	assert_str(heard[1][1]).starts_with("R1 ")
	assert_int(gatekeeper.trust).is_equal(1)
	assert_bool(gatekeeper.gate_is_open()).is_false()
