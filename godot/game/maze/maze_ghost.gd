## A ghost, deciding the way the arcade's ghosts do: a target tile, and the
## shortest straight line to it from the cell beyond each way.
##
## Pittman's Pac-Man Dossier (2009) found that the four ghosts differ in one
## thing only: the tile each aims at. The rest is one rule for all of them.
## At a fork a ghost never takes the way back; it looks one cell beyond each
## other way, measures the straight line from there to its target, and takes
## the shortest, a tie going up, then left, then down, then right. No search,
## no path: a ghost can be led away by a wall between it and its target, and
## that is a large part of why the arcade game is playable.
##
## The target is the personality. In scatter it is the ghost's home corner,
## outside the walls, so it circles the block nearest it. In chase Blinky's
## is Pac-Man's own cell; Pinky's is four cells ahead of where he faces, and
## four to the left too when he faces up -- an overflow bug in the arcade's
## code that the Dossier documents and this keeps.
##
## One rule is the kit's, not the arcade's, written in `rules.json`: in
## chase, at a fork, the ghost keeps the Dossier's way with a fixed
## probability and otherwise takes any way evenly. That chance is what makes
## the maze an MDP for T98, and stating it as a rule makes T98's model of a
## ghost's turn exact -- all but the timed schedule, whose mode changes and
## forced reversals depend on the step count (T98's task file weighs that).
##
## Complexity: constant per decision -- at most three ways to measure.
##
## When not to use it: a ghost that must corner a player who knows the rule.
## It never looks past one cell, so a player can lead it into a loop.
class_name MazeGhost
extends RefCounted

## How a ghost came by its next move, as the vectors and the screen write it.
const REVERSAL: String = "reversal"  # not shown: an identifier, worded by MazePanel
const ONLY_WAY: String = "only way"  # not shown: an identifier, worded by MazePanel
const NEAREST: String = "nearest"  # not shown: an identifier, worded by MazePanel
const DICE: String = "dice"  # not shown: an identifier, worded by MazePanel

## Which ghost: "blinky" or "pinky", the key of its corner and its target.
var name: String = ""
## Where it stands.
var cell: Vector2i = Vector2i.ZERO
## The direction of its last move: the way it may not turn back.
var heading: String = ""
## The move it chose for the next step, on show before it takes it.
var next_move: String = ""
## Everything that went into that choice: the mode, the target, each way
## with the cell beyond and its squared distance, the Dossier's way, the
## way chosen and how -- and the dice, when they were rolled.
var decision: Dictionary = {}


## The ghost `ghost_name` where `maze.json` starts it.
func _init(ghost_name: String = "blinky") -> void:
	name = ghost_name
	var start: Dictionary = MazeRules.maze()["ghosts"][ghost_name]
	cell = MazeRules.cell_of(start["cell"])
	heading = start["heading"]


## Its target tile in `mode`, with Pac-Man on `pacman` facing `facing`.
func target(mode: String, pacman: Vector2i, facing: String) -> Vector2i:
	if mode == MazeRules.SCATTER:
		return MazeRules.cell_of(MazeRules.maze()["ghosts"][name]["corner"])
	var personality: Dictionary = MazeRules.rules()["targets"][name]
	if personality["chase"] == "pacman":
		return pacman
	var tiles: int = int(personality["tiles"])
	var ahead: Vector2i = pacman + MazeRules.step_of(facing) * tiles
	if facing == "up" and personality["up_also_left"]:  # not shown: a direction's identifier
		ahead += MazeRules.step_of("left") * tiles  # not shown: a direction's identifier
	return ahead


## The ways it may take from where it stands, in tie order, each with the
## cell beyond it and that cell's squared distance to `goal`. Never the way
## back, unless it is the only way.
func ways(goal: Vector2i) -> Array[Dictionary]:
	var back: String = MazeRules.reverse(heading)
	var found: Array[Dictionary] = []
	for direction: String in MazeRules.rules()["tie_order"]:
		if direction != back and MazeRules.is_open(MazeRules.moved(cell, direction)):
			found.append(_way(direction, goal))
	if found.is_empty():
		found.append(_way(back, goal))
	return found


## The Dossier's way: the shortest, and on a tie the first in the tie order
## -- up, left, down, right -- asked here rather than left to the order the
## ways were listed in.
static func nearest(open_ways: Array[Dictionary]) -> String:
	var best: Dictionary = open_ways[0]
	for way: Dictionary in open_ways:
		if _rank(way) < _rank(best):
			best = way
	return best["direction"]


# A way's place in the Dossier's order: by distance, then by the tie order.
static func _rank(way: Dictionary) -> Vector2i:
	var order: Array = MazeRules.rules()["tie_order"]
	return Vector2i(way["squared"], order.find(way["direction"]))


## Choose the next move, at the end of a step, and keep why in `decision`.
## On a mode change the move is back the way it came, chosen by nobody --
## the Dossier's forced reversal. Otherwise the Dossier's way, or, at an
## imprecise fork, whatever the dice say.
func decide(mode: String, pacman: Vector2i, facing: String, reversing: bool, dice: Xorshift) -> void:
	var goal: Vector2i = target(mode, pacman, facing)
	var back: String = MazeRules.reverse(heading)
	var open_ways: Array[Dictionary] = [_way(back, goal)] as Array[Dictionary]
	var choice: Dictionary = {"chosen": back, "best": back, "kind": REVERSAL}
	if not reversing:
		open_ways = ways(goal)
		choice = choose(open_ways, mode, dice)
	next_move = choice["chosen"]
	decision = {"mode": mode, "target": goal, "ways": open_ways}
	decision.merge(choice)


## Which of `open_ways` to take in `mode`, and how: one way without a draw;
## at a fork the Dossier's way, unless the mode is imprecise and a uniform
## draw comes out at or above the precision -- then a second draw picks any
## way evenly.
static func choose(open_ways: Array[Dictionary], mode: String, dice: Xorshift) -> Dictionary:
	var best: String = nearest(open_ways)
	if open_ways.size() == 1:
		return {"chosen": best, "best": best, "kind": ONLY_WAY}
	if not MazeRules.imprecise_in(mode):
		return {"chosen": best, "best": best, "kind": NEAREST}
	var roll: float = dice.uniform()
	if roll < MazeRules.precision():
		return {"chosen": best, "best": best, "kind": NEAREST, "roll": roll}
	var pick: int = dice.index(open_ways.size())
	return {"chosen": open_ways[pick]["direction"], "best": best, "kind": DICE, "roll": roll, "pick": pick}


## The probability of each of `open_ways` in `mode`, as `choose` takes
## them: precision x [it is the Dossier's way] + (1 - precision) / ways at
## an imprecise fork, and certainty for the Dossier's way everywhere else.
## T98's MDP is built on these numbers; the MDP's lookahead asks them here.
static func chances(open_ways: Array[Dictionary], mode: String) -> Dictionary:
	var best: String = nearest(open_ways)
	var found: Dictionary = {}
	var imprecise: bool = open_ways.size() > 1 and MazeRules.imprecise_in(mode)
	for way: Dictionary in open_ways:
		var keeps: float = 1.0 if way["direction"] == best else 0.0
		if imprecise:
			found[way["direction"]] = (1.0 - MazeRules.precision()) / open_ways.size() + MazeRules.precision() * keeps
		else:
			found[way["direction"]] = keeps
	return found


## Take the move it chose: one cell along `next_move`.
func move() -> void:
	cell = MazeRules.moved(cell, next_move)
	heading = next_move


func _way(direction: String, goal: Vector2i) -> Dictionary:
	var beyond: Vector2i = MazeRules.moved(cell, direction)
	return {"direction": direction, "beyond": beyond, "squared": MazeRules.squared_distance(beyond, goal)}
