## The rules of English draughts -- checkers -- as the game's, not the kit's.
##
## Sources: the World Checkers Draughts Federation's rules,
## https://www.wcdf.net/rules.htm, as summarised in
## https://en.wikipedia.org/wiki/English_draughts (read 2026-10-14). The rules
## played here, and the tests in `test/checkers_rules_test.gd` that hold them:
##
## * 8x8, dark squares only. The darker pieces, red here, move first;
## * a man steps one square diagonally forward; a king steps either way;
## * capturing is compulsory. When several captures exist the player may
##   choose any of them -- there is no rule to take the most -- but a capture
##   sequence, once begun, must be completed;
## * a man that reaches the far row is crowned, and **crowning ends the move**,
##   even in the middle of a jump;
## * a player with no legal move has lost;
## * a draw by the 40-move rule: forty moves by each side with no capture and
##   no man moved. The count is this task's statement of the rule; the
##   federation's page was not reachable to quote it line by line.
class_name CheckersRules
extends RefCounted

const DIAGONALS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]


## Every legal move for the side to move: the captures if there are any,
## otherwise the steps. Pieces are taken top row first, left to right, and
## each piece's moves in the order of `DIAGONALS`, so the list never changes
## for the same position.
static func legal_moves(board: CheckersBoard) -> Array:
	if board.moves_are_known:
		return board.known_moves
	var captures: Array = []
	var steps: Array = []
	for square: Vector2i in board.squares_of(board.to_move):
		captures += jumps_from(board, square)
		steps += _steps_from(board, square)
	board.known_moves = captures if not captures.is_empty() else steps
	board.moves_are_known = true
	return board.known_moves


## Every complete capture sequence the piece on `square` could make.
static func jumps_from(board: CheckersBoard, square: Vector2i) -> Array:
	var found: Array = []
	var start: Array[Vector2i] = [square]
	_extend_jump(board, board.piece_at(square), start, [] as Array[Vector2i], found)
	return found


## The position after `move`: the piece moved, what it jumped removed, a man
## on the far row crowned, the other side to move and the quiet count updated.
static func play(board: CheckersBoard, move: CheckersMove) -> CheckersBoard:
	var next: CheckersBoard = board.copy()
	var piece: int = board.piece_at(move.from())
	next.set_piece(move.from(), CheckersBoard.EMPTY)
	for square: Vector2i in move.captured:
		next.set_piece(square, CheckersBoard.EMPTY)
	if move.crowns:
		piece = CheckersBoard.RED_KING if piece == CheckersBoard.RED_MAN else CheckersBoard.WHITE_KING
	next.set_piece(move.to(), piece)
	var reversible: bool = CheckersBoard.is_king(board.piece_at(move.from())) and not move.is_capture()
	next.quiet_plies = board.quiet_plies + 1 if reversible else 0
	next.to_move = CheckersBoard.opponent(board.to_move)
	return next


## True when the 40-move rule has drawn the game.
static func is_draw(board: CheckersBoard) -> bool:
	return board.quiet_plies >= CheckersBoard.QUIET_PLIES_TO_DRAW


## The winner, or -1 while the game goes on or ends drawn. The side to move
## loses when it has no legal move, whether it has no pieces or none can move.
static func winner(board: CheckersBoard) -> int:
	if legal_moves(board).is_empty():
		return CheckersBoard.opponent(board.to_move)
	return -1


## True when nobody can move any more: a win, or a draw.
static func is_over(board: CheckersBoard) -> bool:
	return is_draw(board) or legal_moves(board).is_empty()


## The legal moves of the piece on `square`. Empty when it has none -- or when
## it has steps, but some other piece must capture.
static func moves_of(board: CheckersBoard, square: Vector2i) -> Array:
	return legal_moves(board).filter(func(move: CheckersMove) -> bool: return move.from() == square)


## True when the side to move has a capture, and so must take one.
static func must_capture(board: CheckersBoard) -> bool:
	var moves: Array = legal_moves(board)
	return not moves.is_empty() and (moves[0] as CheckersMove).is_capture()


## Why moving from `from` to `to` is not allowed, in a sentence a player can
## act on, or "" when some legal move does exactly that.
static func why_refused(board: CheckersBoard, from: Vector2i, to: Vector2i) -> String:
	var piece: int = board.piece_at(from)
	if CheckersBoard.owner_of(piece) != board.to_move:
		return "that is not one of your pieces"
	for move: CheckersMove in moves_of(board, from):
		if move.to() == to:
			return ""
	var compulsory: bool = must_capture(board)
	if compulsory and jumps_from(board, from).is_empty():
		return "a capture is compulsory, and this piece cannot capture: the ringed pieces can"
	if compulsory:
		return "a capture is compulsory: jump over a piece, and finish every jump that follows"
	if not CheckersBoard.is_dark(to) or board.piece_at(to) != CheckersBoard.EMPTY:
		return "pieces move only to an empty dark square"
	if not CheckersBoard.is_king(piece) and signi(to.y - from.y) != CheckersBoard.forward(board.to_move):
		return "a man moves only forward; it can move back once it is crowned"
	return "a piece steps one square diagonally"


# The one-square diagonal steps of the piece on `square`.
static func _steps_from(board: CheckersBoard, square: Vector2i) -> Array:
	var found: Array = []
	var piece: int = board.piece_at(square)
	for direction: Vector2i in _directions_of(piece):
		var landing: Vector2i = square + direction
		if CheckersBoard.is_inside(landing) and board.piece_at(landing) == CheckersBoard.EMPTY:
			var path: Array[Vector2i] = [square, landing]
			var crowned: bool = _crowns(piece, landing)
			found.append(CheckersMove.new(path, [] as Array[Vector2i], crowned))
	return found


# Grow a capture sequence one jump at a time, depth first, and record it once
# it can grow no further. A jumped piece stays on the board until the move is
# over, so it cannot be jumped twice and nothing can land on it.
static func _extend_jump(board: CheckersBoard, piece: int, path: Array[Vector2i],
		taken: Array[Vector2i], found: Array) -> void:
	var here: Vector2i = path[path.size() - 1]
	var extended: bool = false
	for direction: Vector2i in _directions_of(piece):
		var over: Vector2i = here + direction
		var landing: Vector2i = here + direction * 2
		if not _can_jump(board, piece, path[0], over, landing, taken):
			continue
		extended = true
		var longer: Array[Vector2i] = path.duplicate()
		longer.append(landing)
		var more_taken: Array[Vector2i] = taken.duplicate()
		more_taken.append(over)
		if _crowns(piece, landing):
			found.append(CheckersMove.new(longer, more_taken, true))
		else:
			_extend_jump(board, piece, longer, more_taken, found)
	if not extended and taken.size() > 0:
		found.append(CheckersMove.new(path, taken, false))


# Whether `piece` may jump the square `over` and land on `landing`. The square
# the piece started from counts as empty: it has left it.
static func _can_jump(board: CheckersBoard, piece: int, start: Vector2i, over: Vector2i,
		landing: Vector2i, taken: Array[Vector2i]) -> bool:
	if not CheckersBoard.is_inside(landing) or taken.has(over):
		return false
	var mover: int = CheckersBoard.owner_of(piece)
	if CheckersBoard.owner_of(board.piece_at(over)) != CheckersBoard.opponent(mover):
		return false
	return board.piece_at(landing) == CheckersBoard.EMPTY or landing == start


# A man goes forward only; a king goes all four ways.
static func _directions_of(piece: int) -> Array[Vector2i]:
	if CheckersBoard.is_king(piece):
		return DIAGONALS
	var ahead: int = CheckersBoard.forward(CheckersBoard.owner_of(piece))
	return DIAGONALS.filter(func(direction: Vector2i) -> bool: return direction.y == ahead)


# True when a man lands on its far row; a king is already crowned.
static func _crowns(piece: int, landing: Vector2i) -> bool:
	return not CheckersBoard.is_king(piece) \
			and landing.y == CheckersBoard.crowning_row(CheckersBoard.owner_of(piece))
