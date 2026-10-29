## You, at the keys, as a controller that gives Pac-Man one move a step.
##
## The arcade's Pac-Man keeps running the way he faces until a wall stops
## him, and a direction pressed early is remembered and taken at the first
## cell where it is open -- which is what makes him easy to steer round a
## corner. The rules (`MazeGame.step`) know nothing of that: they take one
## of four moves a step, and a move into a wall stands still. Keeping the
## remembering here keeps the rules small, and T98's MDP, which chooses a
## move a step, plays by the same rules as you.
##
## When not to use it: a game that wants Pac-Man to stop when the key is let
## go. He never does here, as he never does in the arcade.
class_name MazePerson
extends RefCounted

## The direction last pressed, or "" before any key: the one taken as soon
## as it is open.
var wanted: String = ""


## Remember `direction`, to take as soon as it is open.
func press(direction: String) -> void:
	wanted = direction


## Pac-Man's move in `game`: the direction pressed if it is open from his
## cell, otherwise on the way he faces -- into a wall, which stands still.
func move_for(game: MazeGame) -> String:
	if wanted != "" and MazeRules.is_open(MazeRules.moved(game.pacman, wanted)):
		return wanted
	return game.facing
