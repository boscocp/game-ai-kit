## The piece in your hand, and the squares you have clicked for it so far.
##
## A multi-jump is one move in the rules, but a person plays it the way it is
## played over a real board: one hop at a time. So the hand keeps a route --
## the piece's square, then each landing clicked -- and only the moves whose
## path starts with that route are still possible. When the route is a whole
## move, it is played. Clicking the last square straight away also works.
class_name CheckersHand
extends RefCounted

## The square of the piece in hand, then each landing clicked. Empty when
## nothing is in hand.
var route: Array[Vector2i] = []

## Why the last click did nothing, in words a player can act on, or "".
var refusal: String = ""


## True while a piece is in hand.
func is_holding() -> bool:
	return not route.is_empty()


## Put the piece down.
func drop() -> void:
	route.clear()


## Pick up the piece on `square`, if it has a legal move. A piece that has
## none stays where it is, and `refusal` says why.
func pick_up(board: CheckersBoard, square: Vector2i) -> void:
	drop()
	refusal = ""
	if CheckersRules.moves_of(board, square).is_empty():
		refusal = _why_it_cannot_move(board, square)
		return
	route = [square]


## The legal moves still possible with the route clicked so far.
func candidates(board: CheckersBoard) -> Array:
	if route.is_empty():
		return []
	return CheckersRules.moves_of(board, route[0]).filter(_follows_route)


## The squares the next click may land on: the next hop of every move still
## possible.
func targets(board: CheckersBoard) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for move: CheckersMove in candidates(board):
		if not found.has(move.path[route.size()]):
			found.append(move.path[route.size()])
	return found


## What a click on `square` does with the piece in hand: the move to play when
## the route is now complete, or null -- having taken one more hop, or having
## refused the square with the reason in `refusal`.
func click(board: CheckersBoard, square: Vector2i) -> CheckersMove:
	refusal = ""
	if targets(board).has(square):
		route.append(square)
		return _complete_move(board)
	# The last square straight away. Two jumps can end on the same square by
	# different routes; then the first is played, and hop by hop picks the
	# other. A capture that comes back to its own square is only hop by hop,
	# or a second click on the piece would play a move nobody chose.
	for move: CheckersMove in candidates(board):
		if move.to() == square and square != route[0]:
			return move
	if route.size() > 1:
		refusal = "the jump is not finished: click the next green square"
	else:
		refusal = CheckersRules.why_refused(board, route[0], square)
	return null


func _complete_move(board: CheckersBoard) -> CheckersMove:
	for move: CheckersMove in candidates(board):
		if move.path == route:
			return move
	return null


func _follows_route(move: CheckersMove) -> bool:
	return move.path.size() > route.size() and move.path.slice(0, route.size()) == route \
			or move.path == route


func _why_it_cannot_move(board: CheckersBoard, square: Vector2i) -> String:
	if CheckersRules.must_capture(board):
		return "a capture is compulsory, and this piece cannot capture: the ringed pieces can"
	return "that piece has no move from here: every square it could reach is taken"
