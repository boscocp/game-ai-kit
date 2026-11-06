# T134: a side is never asked about a game that is over.
#
# Wave 136's duel saw `MctsSquad` search a board it believed already won
# while the game, it seemed, went on. The probe of wave 147 found the belief
# right: in every case the shot just played had destroyed the other side's
# last piece, and `BlueTurn` went on to ask the next waiting piece. The
# board below is one of those turns, recorded in a seeded match (dice seed
# 4, red the searcher at 400 iterations, blue the weighed enemy): red's
# shield, at (4, 3), shoots blue's last piece, a mortar with 2 health left,
# and red's mortar and wader are still waiting.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
# The recorded turn, as `spec/squad/duel.json` writes a position.
const RECORDED: Dictionary = {
	"turn": 16, "to_move": RED, "acting": 2, "phase": "shoot", "waiting": [3, 4],
	"pieces": [[2, RED, "shield", 4, 3, 7, 3], [3, RED, "mortar", 4, 2, 1, 4], [4, RED, "wader", 1, 4, 2, 6],
		[7, BLUE, "mortar", 7, 4, 2, 0]]}
const RECORDED_DICE: int = 190567314


## Red as it played that turn: every piece holds its ground, and the shield
## shoots the mortar. Each board it is asked about is kept.
class ShootsTheLastPiece extends BlueController:
	var asked_on: Array[BoardState] = []

	## Not on the roster: a name for the log only.
	func controller_name() -> String:
		return "shoots the last piece"

	## What it stands for, for the log only.
	func describe() -> String:
		return "the recorded turn's red"

	## A squad has no workshop; held, as a walk would be.
	func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
		return decide_move(state, workshop_id)

	## Holds, and keeps the board it was asked on.
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		asked_on.append(state)
		return TacticalDecision.hold(unit_id, [], state.unit_by_id(unit_id).cell)

	## The shield shoots the mortar; nobody else shoots. Keeps the board.
	func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
		asked_on.append(state)
		if unit_id != 2:
			return null
		var shot := TacticalDecision.hold(unit_id, [], state.unit_by_id(7).cell)
		shot.attack = Attack.new(unit_id, 7)
		return shot


func test_the_recorded_shot_ends_the_game_and_nobody_is_asked_after_it() -> void:
	var board: BoardState = SquadDuel.board_of(RECORDED)
	board.dice_seed = RECORDED_DICE
	var red := ShootsTheLastPiece.new()
	var turn := BlueTurn.new(red, SquadRuleset.new())
	turn.begin(board)
	while not turn.finished():
		board = turn.play(board)
	assert_int(SquadVictory.winner(board)).is_equal(RED)
	assert_int(red.asked_on.size()).is_equal(2)
	for asked: BoardState in red.asked_on:
		assert_int(SquadVictory.winner(asked)).is_equal(TacticalVictory.NOBODY)

