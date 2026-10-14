"""Noughts and crosses, and the eight ways of turning the board.

A board is a string of nine characters, row by row from the top left: `X`,
`O`, or `.` for an empty square. Strings because they are what the published
bead file uses as keys, and a key a person can read is a key a person can
check.

Michie's MENACE kept one matchbox for each position *up to symmetry*: a board
and its mirror image or rotation are the same position, so they share a box.
Folding them is what brings the positions MENACE can face down to 304.
"""

from __future__ import annotations

EMPTY = "."
CROSS = "X"
NOUGHT = "O"
DRAW = "draw"

#: The eight lines that win.
LINES = (
    (0, 1, 2), (3, 4, 5), (6, 7, 8),
    (0, 3, 6), (1, 4, 7), (2, 5, 8),
    (0, 4, 8), (2, 4, 6),
)

#: The eight symmetries of the square, each as a permutation: the turned board
#: has, on square `i`, what the original had on square `SYMMETRIES[k][i]`. The
#: order is fixed and the Godot side copies it, because which turn is found
#: first decides how a move in the box maps back onto the real board.
SYMMETRIES = (
    (0, 1, 2, 3, 4, 5, 6, 7, 8),  # as it is
    (6, 3, 0, 7, 4, 1, 8, 5, 2),  # a quarter turn clockwise
    (8, 7, 6, 5, 4, 3, 2, 1, 0),  # a half turn
    (2, 5, 8, 1, 4, 7, 0, 3, 6),  # a quarter turn anticlockwise
    (2, 1, 0, 5, 4, 3, 8, 7, 6),  # mirrored left to right
    (6, 7, 8, 3, 4, 5, 0, 1, 2),  # mirrored top to bottom
    (0, 3, 6, 1, 4, 7, 2, 5, 8),  # mirrored on the main diagonal
    (8, 5, 2, 7, 4, 1, 6, 3, 0),  # mirrored on the other diagonal
)

START = EMPTY * 9


def to_move(board: str) -> str:
    """Whose turn it is. Crosses move first, as MENACE did."""
    return CROSS if board.count(CROSS) == board.count(NOUGHT) else NOUGHT


def winner(board: str) -> str | None:
    """`X` or `O` for a won game, `draw` for a full board, None otherwise."""
    for first, second, third in LINES:
        if board[first] != EMPTY and board[first] == board[second] == board[third]:
            return board[first]
    return DRAW if EMPTY not in board else None


def moves(board: str) -> list[int]:
    """The empty squares, in order, while the game is not over."""
    if winner(board) is not None:
        return []
    return [square for square in range(9) if board[square] == EMPTY]


def play(board: str, square: int) -> str:
    """The board after the player to move takes `square`."""
    return board[:square] + to_move(board) + board[square + 1:]


def turned(board: str, symmetry: int) -> str:
    """The board turned by one of the eight symmetries."""
    return "".join(board[source] for source in SYMMETRIES[symmetry])


def canonical(board: str) -> tuple[str, int]:
    """The position's matchbox, and the first symmetry that turns the board
    into it.

    The box is the smallest of the eight turned boards, compared as strings
    (`.` sorts before `O`, which sorts before `X`). Any rule that picks one of
    the eight would do; this one is easy to do by hand and in two languages.
    """
    best = min(turned(board, symmetry) for symmetry in range(8))
    return best, next(symmetry for symmetry in range(8) if turned(board, symmetry) == best)


def representatives(box: str) -> list[int]:
    """The empty squares of a box that each stand for a different move.

    A symmetric position has moves that are the same move turned: on the empty
    board the four corners are one move, the four edges another, and the
    centre a third. Michie's first box held three colours of bead, not nine,
    and so does this one. Each move is stood for by the lowest square that
    plays it.
    """
    keeps_it = [symmetry for symmetry in range(8) if turned(box, symmetry) == box]
    chosen = []
    for square in moves(box):
        if square == min(SYMMETRIES[symmetry][square] for symmetry in keeps_it):
            chosen.append(square)
    return chosen
