"""The machine: one matchbox per position, beads for moves, and three rules.

Donald Michie built MENACE in 1961 out of 304 matchboxes (Michie, "Trial and
error", *Science Survey* 1961, part 2, pp. 129-145; and "Experiments on the
mechanization of game-learning", *The Computer Journal* 6(3), 1963). Each box
is a position MENACE might face with itself to move, and holds beads, one
colour for each move it could make there. To move, shake the box and draw a
bead. After the game, every box it drew from is told how it went:

* a win puts the bead back with three more of its colour;
* a draw puts it back with one more;
* a loss keeps it out.

That is the whole of the learning: moves that led to wins become likelier,
moves that led to losses rarer. A box that runs out of beads has learnt that
every move there loses, and MENACE resigns.

Squares here are the box's own squares -- the canonical board's, see
`board.canonical` -- and `play_from` turns the chosen one back onto the real
board.
"""

from __future__ import annotations

import dataclasses

from . import board as game

#: Beads of each colour a new box starts with, by how many pieces are on the
#: board. Michie's: four on the first move, three on the second, two on the
#: third, one on the fourth. Later moves matter less to a game's outcome and
#: are allowed to change their minds faster.
STARTING_BEADS = {0: 4, 2: 3, 4: 2, 6: 1}

#: What each outcome does to the bead drawn from every box used in the game.
REWARDS = {game.CROSS: 3, game.DRAW: 1, game.NOUGHT: -1}


@dataclasses.dataclass
class Menace:
    """Every matchbox, as box -> nine bead counts, one per square of the box.

    Squares that are taken, or that stand for the same move as a lower square,
    hold no beads and never will.
    """

    boxes: dict[str, list[int]]

    @classmethod
    def fresh(cls) -> "Menace":
        """A machine that has played no games: every box at its starting beads."""
        boxes = {}
        for box in every_box():
            beads = [0] * 9
            for square in game.representatives(box):
                beads[square] = STARTING_BEADS[9 - box.count(game.EMPTY)]
            boxes[box] = beads
        return cls(boxes)

    def copy(self) -> "Menace":
        """The same machine, so a snapshot does not change as training goes on."""
        return Menace({box: list(beads) for box, beads in self.boxes.items()})

    def draw(self, box: str, chance: float) -> int | None:
        """The square whose bead is drawn, given a uniform number in [0, 1).

        The beads are laid out square by square, lowest first, and `chance`
        picks a point along them. The number is an argument rather than drawn
        here, so Python and GDScript -- whose random generators differ -- can be
        handed the same one and must choose the same square. None for an empty
        box: MENACE resigns.
        """
        beads = self.boxes[box]
        total = sum(beads)
        if total == 0:
            return None
        point = chance * total
        for square, count in enumerate(beads):
            if point < count:
                return square
            point -= count
        return max(square for square, count in enumerate(beads) if count > 0)

    def most_beaded(self, box: str) -> int | None:
        """The square with the most beads, the lowest on a tie; None if empty.

        Not how MENACE played. It is how its strength is measured: drawing
        at random, "it never loses" cannot be checked in a finite number of
        games, and picking the favourite makes it a yes or a no.
        """
        beads = self.boxes[box]
        if max(beads) == 0:
            return None
        return beads.index(max(beads))

    def learn(self, used: list[tuple[str, int]], outcome: str) -> None:
        """Michie's rule, applied to every (box, square) MENACE drew in a game."""
        for box, square in used:
            self.boxes[box][square] = max(0, self.boxes[box][square] + REWARDS[outcome])


def every_box() -> list[str]:
    """Every position MENACE can face with a box: crosses to move, the game not
    over, and fewer than eight pieces down -- with one square left the move is
    forced, and Michie kept no box for it. Folded by symmetry, there are 304.
    """
    found = set()
    seen = set()
    frontier = [game.START]
    while frontier:
        board = frontier.pop()
        if board in seen or game.winner(board) is not None:
            continue
        seen.add(board)
        if game.to_move(board) == game.CROSS and board.count(game.EMPTY) > 1:
            found.add(game.canonical(board)[0])
        frontier += [game.play(board, square) for square in game.moves(board)]
    return sorted(found)


def play_from(board: str, box_square: int) -> int:
    """The real square for a square of the board's box."""
    _box, symmetry = game.canonical(board)
    return game.SYMMETRIES[symmetry][box_square]
