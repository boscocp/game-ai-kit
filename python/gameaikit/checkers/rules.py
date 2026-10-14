"""The rules of English draughts -- checkers -- as `godot/game/checkers/` plays them.

A port, line for line where the order matters, of `checkers_board.gd` and
`checkers_rules.gd`, because self-play happens where training happens and
training happens here (invariant 6). The two cannot be allowed to drift, so
`spec/vectors/checkers/rules.json` lists positions with their legal moves, in
order, and both languages are read against it.

A position is immutable: `play` returns a new one. Squares are numbered row by
row from the top-left, `row * 8 + column`; red sits at the bottom and moves up,
white at the top and moves down, and only the dark squares, where column + row
is odd, are played on. The rules, and their sources, are the Godot file's:

* a man steps one square diagonally forward, a king either way;
* capturing is compulsory; any capture may be chosen, but a sequence once
  begun is completed;
* a man that reaches the far row is crowned, and crowning ends the move;
* a player with no legal move has lost;
* eighty plies with no capture and no man moved is a draw.

When not to use it: anything fast. This is the readable version: 28
microseconds for the opening's moves, measured; an engine uses bitboards.
"""

from __future__ import annotations

import dataclasses

SIZE = 8

EMPTY = 0
RED_MAN = 1
RED_KING = 2
WHITE_MAN = 3
WHITE_KING = 4

RED = 0
WHITE = 1

QUIET_PLIES_TO_DRAW = 80

#: The four diagonals as (column, row) steps, in the order the Godot side
#: tries them. The order of the legal moves follows from it, and the search's
#: tie-break follows from that.
DIAGONALS = ((-1, -1), (1, -1), (-1, 1), (1, 1))

COLUMNS = "abcdefgh"


@dataclasses.dataclass(frozen=True)
class Move:
    """One move: the squares the piece lands on, from the start, and what it takes."""

    path: tuple[tuple[int, int], ...]
    captured: tuple[tuple[int, int], ...] = ()
    crowns: bool = False

    def is_capture(self) -> bool:
        """True for a jump, single or multiple."""
        return bool(self.captured)

    def notation(self) -> str:
        """`c3-d4` for a step, `c3xe5xg3` for a jump: columns a-h from the
        left, rows 1-8 from red's side, as the Godot board labels them."""
        return ("x" if self.is_capture() else "-").join(square_name(square) for square in self.path)


@dataclasses.dataclass(frozen=True)
class Board:
    """Which piece stands on each square, whose turn it is, and the quiet count."""

    squares: tuple[int, ...]
    to_move: int = RED
    quiet_plies: int = 0

    def piece_at(self, column: int, row: int) -> int:
        """What stands on a square, or EMPTY off the board."""
        if not is_inside(column, row):
            return EMPTY
        return self.squares[row * SIZE + column]

    def squares_of(self, player: int) -> list[tuple[int, int]]:
        """Every square holding a piece of `player`, top row first, left to right."""
        return [(index % SIZE, index // SIZE) for index, piece in enumerate(self.squares)
                if owner_of(piece) == player]


def starting() -> Board:
    """Twelve men each on the three rows nearest each player, red to move."""
    squares = []
    for index in range(SIZE * SIZE):
        column, row = index % SIZE, index // SIZE
        dark = (column + row) % 2 == 1
        squares.append(WHITE_MAN if dark and row < 3 else RED_MAN if dark and row >= SIZE - 3 else EMPTY)
    return Board(tuple(squares))


def from_rows(rows: list[str], to_move: int) -> Board:
    """A position drawn as eight strings from the top: `r` `w` men, `R` `W`
    kings, anything else empty. Spaces are ignored, as in `CheckersBoard.from_rows`."""
    pieces = {"r": RED_MAN, "R": RED_KING, "w": WHITE_MAN, "W": WHITE_KING}
    squares = [EMPTY] * (SIZE * SIZE)
    for row, text in enumerate(rows[:SIZE]):
        for column, letter in enumerate(text.replace(" ", "")[:SIZE]):
            squares[row * SIZE + column] = pieces.get(letter, EMPTY)
    return Board(tuple(squares), to_move)


def is_inside(column: int, row: int) -> bool:
    """True when a square is on the board at all."""
    return 0 <= column < SIZE and 0 <= row < SIZE


def owner_of(piece: int) -> int:
    """RED, WHITE, or -1 for an empty square."""
    if piece in (RED_MAN, RED_KING):
        return RED
    if piece in (WHITE_MAN, WHITE_KING):
        return WHITE
    return -1


def is_king(piece: int) -> bool:
    """True for a crowned piece of either colour."""
    return piece in (RED_KING, WHITE_KING)


def opponent(player: int) -> int:
    """The other player."""
    return WHITE if player == RED else RED


def crowning_row(player: int) -> int:
    """The far row, where a man of `player` is crowned."""
    return 0 if player == RED else SIZE - 1


def forward(player: int) -> int:
    """Which way a man of `player` moves: up the board for red, down for white."""
    return -1 if player == RED else 1


def square_name(square: tuple[int, int]) -> str:
    """A square as the board's edges name it: `c3`."""
    return f"{COLUMNS[square[0]]}{SIZE - square[1]}"


def legal_moves(board: Board) -> list[Move]:
    """The captures if any piece has one, otherwise the steps, piece by piece
    top-left first and each piece's moves in the order of DIAGONALS."""
    captures, steps = [], []
    for square in board.squares_of(board.to_move):
        captures += jumps_from(board, square)
        steps += _steps_from(board, square)
    return captures if captures else steps


def jumps_from(board: Board, square: tuple[int, int]) -> list[Move]:
    """Every complete capture sequence the piece on `square` could make."""
    found: list[Move] = []
    _extend_jump(board, board.piece_at(*square), (square,), (), found)
    return found


def play(board: Board, move: Move) -> Board:
    """The position after `move`: moved, the jumped pieces gone, a man on the
    far row crowned, the other side to move and the quiet count updated."""
    squares = list(board.squares)
    start, end = move.path[0], move.path[-1]
    piece = board.piece_at(*start)
    squares[start[1] * SIZE + start[0]] = EMPTY
    for column, row in move.captured:
        squares[row * SIZE + column] = EMPTY
    if move.crowns:
        piece = RED_KING if piece == RED_MAN else WHITE_KING
    squares[end[1] * SIZE + end[0]] = piece
    reversible = is_king(board.piece_at(*start)) and not move.is_capture()
    return Board(tuple(squares), opponent(board.to_move), board.quiet_plies + 1 if reversible else 0)


def is_draw(board: Board) -> bool:
    """True when the 40-move rule has drawn the game."""
    return board.quiet_plies >= QUIET_PLIES_TO_DRAW


def winner(board: Board) -> int:
    """The winner, or -1: the side to move with no legal move has lost."""
    return opponent(board.to_move) if not legal_moves(board) else -1


def is_over(board: Board) -> bool:
    """True when nobody can move any more: a win, or a draw."""
    return is_draw(board) or not legal_moves(board)


def _steps_from(board: Board, square: tuple[int, int]) -> list[Move]:
    """The one-square diagonal steps of the piece on `square`."""
    piece = board.piece_at(*square)
    found = []
    for step_column, step_row in _directions_of(piece):
        landing = (square[0] + step_column, square[1] + step_row)
        if is_inside(*landing) and board.piece_at(*landing) == EMPTY:
            found.append(Move((square, landing), (), _crowns(piece, landing)))
    return found


def _extend_jump(board: Board, piece: int, path: tuple, taken: tuple, found: list[Move]) -> None:
    """Grow a capture one jump at a time, depth first, and record it once it
    can grow no further. Jumped pieces stay on the board until the move ends,
    so none is jumped twice and nothing lands on one."""
    here = path[-1]
    extended = False
    for step_column, step_row in _directions_of(piece):
        over = (here[0] + step_column, here[1] + step_row)
        landing = (here[0] + 2 * step_column, here[1] + 2 * step_row)
        if not _can_jump(board, piece, path[0], over, landing, taken):
            continue
        extended = True
        if _crowns(piece, landing):
            found.append(Move(path + (landing,), taken + (over,), True))
        else:
            _extend_jump(board, piece, path + (landing,), taken + (over,), found)
    if not extended and taken:
        found.append(Move(path, taken, False))


def _can_jump(board: Board, piece: int, start: tuple[int, int], over: tuple[int, int],
              landing: tuple[int, int], taken: tuple) -> bool:
    """Whether `piece` may jump `over` and land on `landing`. The square the
    piece started from counts as empty: it has left it."""
    if not is_inside(*landing) or over in taken:
        return False
    if owner_of(board.piece_at(*over)) != opponent(owner_of(piece)):
        return False
    return board.piece_at(*landing) == EMPTY or landing == start


def _directions_of(piece: int) -> tuple[tuple[int, int], ...]:
    """A man goes forward only; a king goes all four ways."""
    if is_king(piece):
        return DIAGONALS
    ahead = forward(owner_of(piece))
    return tuple(direction for direction in DIAGONALS if direction[1] == ahead)


def _crowns(piece: int, landing: tuple[int, int]) -> bool:
    """True when a man lands on its far row; a king is already crowned."""
    return not is_king(piece) and landing[1] == crowning_row(owner_of(piece))
