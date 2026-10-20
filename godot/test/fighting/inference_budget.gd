# T18: asking the cloned player what to do fits in a frame, many times over.
#
#     ./scripts/godot --headless --path godot -s res://test/fighting/inference_budget.gd
#
# Two things are timed. The lookup alone: a situation in words handed to
# the softmax model, or to the ghost's table, exactly or by the nearest case,
# about every situation the recordings met, `ROUNDS` times over. And the
# whole decision the game makes, through `FightCloneOpponent` -- the fight
# read into six words, the lookup, the draw, the inputs -- on every frame of
# a recorded fight, for each of its three sources. Each mean must stay under
# `BUDGET_MS`: a sixteenth of a 60 Hz frame, so that even an opponent
# deciding every frame leaves the frame to the game.
#
# Headless, not in the demo: the demo draws, and drawing is not what is
# being asked about. The number is the opponent's, measured alone.
#
# The numbers are written into T18's record, measured on the slowest machine
# available. Before trusting the clock, it times a planted decision that
# spends twice the budget on purpose; if that passes, the timing is wrong.
#
# Exit codes: 0 every way of deciding is inside the budget; 1 one is not, or
# the planted one was; 2 the cloned player could not be read.
extends SceneTree

## A sixteenth of a frame at 60 frames a second, in milliseconds.
const BUDGET_MS: float = 1.0
const ROUNDS: int = 20


func _init() -> void:
	quit(_run())


func _run() -> int:
	var cloned: ClonedPlayer = ClonedPlayer.load_from()
	if not cloned.is_loaded():
		printerr("inference_budget: " + cloned.error)
		return 2
	var situations: Array[Dictionary] = situations_of(cloned.cases)
	var failures: int = 0
	var planted: float = mean_ms(func(_situation: Dictionary) -> void: OS.delay_usec(int(BUDGET_MS * 2000.0)),
			situations.slice(0, 5), 1)
	var caught: bool = planted >= BUDGET_MS
	print("%s: planted, a decision that waits %.1f ms, measured %.3f ms (must be over %.1f)" % [
			"ok" if caught else "FAIL", BUDGET_MS * 2.0, planted, BUDGET_MS])
	failures += 0 if caught else 1
	var ways: Dictionary = {
		"clone (softmax)": func(situation: Dictionary) -> void: cloned.model.probabilities(situation),
		"ghost, exact": func(situation: Dictionary) -> void: cloned.cases.exact(situation),
		"ghost, nearest": func(situation: Dictionary) -> void: cloned.cases.nearest(situation),
	}
	for way: String in ways:
		var spent: float = mean_ms(ways[way], situations, ROUNDS)
		var inside: bool = spent < BUDGET_MS
		var verdict: String = "ok" if inside else "FAIL"
		print("%s: %s, %.4f ms a decision over %d situations (budget %.1f ms)" % [verdict, way, spent,
			situations.size(), BUDGET_MS])
		failures += 0 if inside else 1
	failures += whole_decisions_over_budget(cloned)
	return 1 if failures > 0 else 0


## How many sources take longer than the budget for a whole decision, each
## timed on every frame of a recorded fight, and said so.
func whole_decisions_over_budget(cloned: ClonedPlayer) -> int:
	var data := FightData.read()
	var states: Array[FightState] = recorded_states(data)
	var over: int = 0
	for source: String in FightCloneOpponent.SOURCES:
		var opponent := FightCloneOpponent.new(source, cloned, data)
		var started: int = Time.get_ticks_usec()
		for state: FightState in states:
			opponent._decide(state, 1)
		var spent: float = (Time.get_ticks_usec() - started) / 1000.0 / states.size()
		var inside: bool = spent < BUDGET_MS
		print("%s: a whole decision, %s, %.4f ms over %d frames (budget %.1f ms)" % ["ok" if inside else "FAIL",
			source, spent, states.size(), BUDGET_MS])
		over += 0 if inside else 1
	return over


## The frames of the first recording, to decide on.
func recorded_states(data: FightData) -> Array[FightState]:
	var refused: Array[String] = []
	var recordings: Dictionary = FightRecording.read_all(FightRecording.directory(), refused)
	return FightRecording.states_of(recordings.values()[0], data)


## Every situation the recorded player met, rebuilt from the table's keys.
func situations_of(cases: CaseTable) -> Array[Dictionary]:
	var situations: Array[Dictionary] = []
	for key: String in cases.cases:
		var words: PackedStringArray = key.split(CaseTable.JOINER)
		var situation: Dictionary = {}
		for index: int in range(cases.features.size()):
			situation[cases.features[index]] = words[index]
		situations.append(situation)
	return situations


## The mean milliseconds `decide` takes over `situations`, `rounds` times.
func mean_ms(decide: Callable, situations: Array[Dictionary], rounds: int) -> float:
	var started: int = Time.get_ticks_usec()
	for _repeat: int in range(rounds):
		for situation: Dictionary in situations:
			decide.call(situation)
	return (Time.get_ticks_usec() - started) / 1000.0 / (rounds * situations.size())
