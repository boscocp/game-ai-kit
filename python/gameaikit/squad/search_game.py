"""The XCOM-style mode as a game a search can read, as `squad_search_game.gd` reads it.

Read the Godot file for the why. A position is one question -- the piece
about to act, whether it walks or shoots, the pieces still to act after it
-- and its answers are hold, then the walks row by row or the shots by
target id. A question with only "hold" is skipped. A shot has two
outcomes, hit and miss, with T84's hit chance; `evaluate` is the result
once the game is over, and the health difference over a full squad's
before that.

This is a second copy of the squad's rules -- the walk, the line of
sight, the turn, the end -- written only for the search, so that
`spec/squad/positions.json` can hold `MonteCarloSearch` in both languages
to the same visit counts on the same positions. It keeps no routes, no
fog and no dice seed: what a search needs and nothing a scene shows.

A cell is a pair (column, row), row 0 at the top. When not to use it:
playing the game. The game is `godot/game/squad/`; this is its arithmetic.
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace

from gameaikit.adversarial.game import AdversarialGame
from gameaikit.adversarial.mcts import MctsResult, MonteCarloSearch
from gameaikit.squad.shot import RULES, cover_of, hit_chance

RED, BLUE = 0, 1
SIDES = 2
WALK, SHOOT = 0, 1
UNREACHED = 1 << 30
#: The four steps beside a cell, in `GakGridGraph.DIRECTIONS`' order.
STEPS = ((0, -1), (1, 0), (0, 1), (-1, 0))
#: What entering each letter costs on foot; `None` is a wall. `TacticalRules`.
GROUND_COSTS = {".": 1, "=": 1, "T": 3, "f": 3, "#": None, "~": None}
#: The pieces that wade, for whom water and fords cost 1 (`TacticalRules`).
WADERS = frozenset({"wader"})
BLOCKERS = frozenset({"#", "T"})


@dataclass(frozen=True)
class Piece:
    """One piece on the board: who, whose, what, where, and what it has left."""

    id: int
    side: int
    kind: str
    cell: tuple[int, int]
    health: int
    movement: int


@dataclass(frozen=True)
class Board:
    """The pieces in the board's own order, whose turn it is, and the turn's number."""

    pieces: tuple[Piece, ...]
    to_move: int
    turn: int

    def piece(self, piece_id: int) -> Piece | None:
        """The piece with this id, or None once it is gone."""
        return next((piece for piece in self.pieces if piece.id == piece_id), None)

    def of(self, side: int) -> list[Piece]:
        """The side's pieces, in the board's order."""
        return [piece for piece in self.pieces if piece.side == side]


@dataclass
class Position:
    """One question: the board, the piece to act, walk or shoot, who acts after."""

    board: Board
    unit_id: int
    phase: int
    waiting: list[int]
    answers: list = field(default_factory=list)


def number(kind: str, name: str) -> int:
    """One of a piece's numbers from the rules, such as `number("mortar", "aim")`."""
    return int(RULES["pieces"][kind][name])


def full_movement(kind: str) -> int:
    """A piece's movement at the start of its turn: two actions."""
    return 2 * number(kind, "action")


def can_shoot(piece: Piece) -> bool:
    """True while it has walked no more than one action."""
    return piece.movement >= number(piece.kind, "action")


class SquadSearchGame(AdversarialGame):
    """The squad mode on the map written in `rows`, for `MonteCarloSearch`."""

    def __init__(self, rows: list[str]) -> None:
        self.rows = list(rows)
        self.width, self.height = len(rows[0]), len(rows)

    def question(self, board: Board, unit_id: int, phase: int, after: list[int]) -> Position:
        """The question `unit_id` is asked first, or the next worth asking."""
        asked = Position(board, unit_id, phase, list(after))
        if self.winner(board) is not None or len(self._answers(asked)) > 1:
            return asked
        return self._next_question(asked)

    def to_move(self, state: Position) -> int:
        return state.board.to_move

    def actions(self, state: Position) -> list:
        return [] if self.is_terminal(state) else self._answers(state)

    def result(self, state: Position, action: tuple) -> Position:
        if action[0] == "shoot":
            possible = self.outcomes(state, action)
            likelier = possible[0]
            for outcome in possible:
                if outcome[0] > likelier[0]:
                    likelier = outcome
            return likelier[1]
        board = state.board
        if action[0] == "walk":
            board = self.walked(board, state.unit_id, action[2], action[3])
        return self._next_question(Position(board, state.unit_id, state.phase, list(state.waiting)))

    def is_terminal(self, state: Position) -> bool:
        return self.winner(state.board) is not None

    def evaluate(self, state: Position, player: int) -> float:
        won = self.winner(state.board)
        if won == "draw":
            return 0.0
        if won is not None:
            return 1.0 if won == player else -1.0
        mine, theirs = health_left(state.board, player), health_left(state.board, SIDES - 1 - player)
        return float(mine - theirs) / full_health()

    def outcomes(self, state: Position, action: tuple) -> list[tuple[float, Position]]:
        if action[0] != "shoot":
            return [(1.0, self.result(state, action))]
        shooter, target = state.board.piece(state.unit_id), state.board.piece(action[2])
        chance = self.chance_of(shooter, target)
        found = []
        if chance > 0:
            found.append((chance / 100.0, self._after_shot(state, action[2], True)))
        if chance < 100:
            found.append((1.0 - chance / 100.0, self._after_shot(state, action[2], False)))
        return found

    def answers(self, board: Board, unit_id: int, phase: int) -> list:
        """Hold, then the piece's walks or its shots."""
        found: list = [("hold", unit_id)]
        unit = board.piece(unit_id)
        if unit is None:
            return found
        found.extend(self.walks(board, unit) if phase == WALK else self.shots(board, unit))
        return found

    def walks(self, board: Board, unit: Piece) -> list:
        """("walk", id, cell, cost) for every cell `unit` reaches this turn, row by row."""
        spent = self.reach(board, unit)
        return [("walk", unit.id, (column, row), spent[(column, row)])
                for row in range(self.height) for column in range(self.width)
                if (column, row) in spent and (column, row) != unit.cell]

    def reach(self, board: Board, unit: Piece) -> dict[tuple[int, int], int]:
        """Cell -> the cheapest walk's cost within the movement left, round every piece."""
        taken = {piece.cell for piece in board.pieces}
        spent = {unit.cell: 0}
        frontier = [unit.cell]
        while frontier:
            here = min(frontier, key=lambda cell: spent[cell])
            frontier.remove(here)
            for step in STEPS:
                cell = (here[0] + step[0], here[1] + step[1])
                cost_in = self.cost_at(unit.kind, cell)
                if cost_in is None or cell in taken:
                    continue
                cost = spent[here] + cost_in
                if cost <= unit.movement and cost < spent.get(cell, UNREACHED):
                    spent[cell] = cost
                    frontier.append(cell)
        return spent

    def cost_at(self, kind: str, cell: tuple[int, int]) -> int | None:
        """What `kind` pays to enter `cell`, or None for a wall or off the board."""
        column, row = cell
        if not (0 <= row < self.height and 0 <= column < self.width):
            return None
        letter = self.rows[row][column]
        if kind in WADERS and letter in ("~", "f"):
            return 1
        return GROUND_COSTS[letter]

    def shots(self, board: Board, unit: Piece) -> list:
        """("shoot", id, target id) for every enemy `unit` may shoot now, by target id."""
        if unit.side != board.to_move or not can_shoot(unit):
            return []
        return [("shoot", unit.id, enemy.id) for enemy in sorted(board.pieces, key=lambda piece: piece.id)
                if enemy.side != unit.side and self.reaches(unit, enemy.cell)]

    def reaches(self, shooter: Piece, cell: tuple[int, int]) -> bool:
        """Within its sight and its range, with the line clear."""
        apart = steps(shooter.cell, cell)
        return (apart <= number(shooter.kind, "sight") and apart <= number(shooter.kind, "range")
                and self.line_clear(shooter.cell, cell))

    def line_clear(self, one: tuple[int, int], other: tuple[int, int]) -> bool:
        """Nothing blocks the line, except cover beside either end (`SquadSight`)."""
        start, end = (one, other) if one <= other else (other, one)
        for cell in line(start, end):
            beside_an_end = steps(cell, start) == 1 or steps(cell, end) == 1
            if self.rows[cell[1]][cell[0]] in BLOCKERS and not beside_an_end:
                return False
        return True

    def chance_of(self, shooter: Piece, target: Piece) -> int:
        """The hit chance from where both stand."""
        cover = cover_of(self.rows, shooter.cell, target.cell)["cover"]
        return hit_chance(number(shooter.kind, "aim"), number(target.kind, "defence"), cover)

    @staticmethod
    def walked(board: Board, unit_id: int, goal: tuple[int, int], cost: int) -> Board:
        """`unit_id` on `goal`, `cost` spent; a dash spends it all."""
        walker = board.piece(unit_id)
        moved = replace(walker, cell=tuple(goal), movement=walker.movement - cost)
        if not can_shoot(moved):
            moved = replace(moved, movement=0)
        return replace(board, pieces=tuple(moved if piece.id == unit_id else piece for piece in board.pieces))

    def winner(self, board: Board) -> int | str | None:
        """The side left standing; at the round limit the healthier; "draw"; or None."""
        red_gone, blue_gone = not board.of(RED), not board.of(BLUE)
        if red_gone and blue_gone:
            return "draw"
        if red_gone or blue_gone:
            return BLUE if red_gone else RED
        if board.turn >= RULES["round_limit"] * SIDES:
            red, blue = health_left(board, RED), health_left(board, BLUE)
            return "draw" if red == blue else (RED if red > blue else BLUE)
        return None

    def _answers(self, state: Position) -> list:
        if not state.answers:
            state.answers = self.answers(state.board, state.unit_id, state.phase)
        return state.answers

    def _after_shot(self, state: Position, target_id: int, hit: bool) -> Position:
        board = state.board
        pieces = []
        for piece in board.pieces:
            if piece.id == state.unit_id:
                piece = replace(piece, movement=0)
            elif piece.id == target_id and hit:
                damage = number(board.piece(state.unit_id).kind, "damage")
                piece = replace(piece, health=max(0, piece.health - damage))
            if piece.health > 0:
                pieces.append(piece)
        after = replace(board, pieces=tuple(pieces))
        return self._next_question(Position(after, state.unit_id, state.phase, list(state.waiting)))

    def _next_question(self, asked: Position) -> Position:
        while self.winner(asked.board) is None:
            self._step_on(asked)
            if self.winner(asked.board) is None and len(self._answers(asked)) > 1:
                return asked
        asked.unit_id = -1
        return asked

    @staticmethod
    def _step_on(asked: Position) -> None:
        asked.answers = []
        if asked.phase == WALK:
            asked.phase = SHOOT
            return
        asked.phase = WALK
        if not asked.waiting:
            asked.board = end_turn(asked.board)
            asked.waiting = [piece.id for piece in asked.board.of(asked.board.to_move)]
        asked.unit_id = asked.waiting.pop(0) if asked.waiting else -1


def end_turn(board: Board) -> Board:
    """The other side to move, its pieces' movement refilled."""
    side = (board.to_move + 1) % SIDES
    pieces = tuple(replace(piece, movement=full_movement(piece.kind)) if piece.side == side else piece
                   for piece in board.pieces)
    return Board(pieces, side, board.turn + 1)


def health_left(board: Board, side: int) -> int:
    """The side's health, summed over its pieces."""
    return sum(piece.health for piece in board.of(side))


def full_health() -> int:
    """A full squad's health: what `evaluate` divides by."""
    return sum(number(kind, "health") for kind in RULES["squad"])


def steps(one: tuple[int, int], other: tuple[int, int]) -> int:
    """Steps between two cells, no diagonals."""
    return abs(one[0] - other[0]) + abs(one[1] - other[1])


def line(start: tuple[int, int], end: tuple[int, int]) -> list[tuple[int, int]]:
    """The cells strictly between the two on Bresenham's line, as `SquadSight.line`."""
    cells = []
    delta = (abs(end[0] - start[0]), -abs(end[1] - start[1]))
    step = ((end[0] > start[0]) - (end[0] < start[0]), (end[1] > start[1]) - (end[1] < start[1]))
    error = delta[0] + delta[1]
    column, row = start
    while (column, row) != tuple(end):
        doubled = 2 * error
        if doubled >= delta[1]:
            error += delta[1]
            column += step[0]
        if doubled <= delta[0]:
            error += delta[0]
            row += step[1]
        if (column, row) != tuple(end):
            cells.append((column, row))
    return cells


def described(action: tuple) -> str:
    """An answer as both languages write it: "1 holds", "1 walks to 5,3 for 4", "3 shoots 6"."""
    if action[0] == "walk":
        return "%d walks to %d,%d for %d" % (action[1], action[2][0], action[2][1], action[3])
    if action[0] == "shoot":
        return "%d shoots %d" % (action[1], action[2])
    return "%d holds" % action[1]


def position_from(rows: list[str], written: dict) -> tuple[SquadSearchGame, Position]:
    """The game and the root question one entry of `spec/squad/positions.json` writes."""
    game = SquadSearchGame(rows)
    pieces = tuple(Piece(entry[0], entry[1], entry[2], (entry[3], entry[4]), entry[5], entry[6])
                   for entry in written["pieces"])
    board = Board(pieces, written["to_move"], written["turn"])
    phase = WALK if written["phase"] == "walk" else SHOOT
    return game, game.question(board, written["acting"], phase, list(written["waiting"]))


def searched(rows: list[str], written: dict) -> MctsResult:
    """The entry's search, run: its iterations from its seed, with `rules.json`'s numbers."""
    game, root = position_from(rows, written)
    search = MonteCarloSearch(game, root, written["seed"], float(RULES["search"]["exploration"]),
                              int(RULES["search"]["playout_limit"]))
    return search.step(written["iterations"])


def root_visits(found: MctsResult) -> list[list]:
    """`[answer, visits]` for every answer at the root, in the game's order."""
    return [[described(entry["action"]), entry["visits"]] for entry in found.considered]
