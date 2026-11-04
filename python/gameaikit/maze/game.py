"""One game in the maze, a step at a time, as `godot/game/maze/maze_game.gd` plays it.

A step is the six moments `rules.json`'s "about" lists, in that order:
Pac-Man moves, is caught walking into a ghost, eats; the ghosts take the
moves they chose last step, and catch him on his cell; then
each ghost chooses its next move. A ghost's next move is chosen at the end
of a step so that it is on the screen before it is taken -- and that is the
Dossier's own order too, where a ghost decides a tile ahead of a turn.

The game is a pure function of its seed and Pac-Man's moves: the dice are
the only chance in it, and they are drawn only at an imprecise fork.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from gameaikit.maze import rules
from gameaikit.core.xorshift import Xorshift

PLAYING = "playing"
WON = "won"
CAUGHT = "caught"


@dataclass
class Ghost:
    """A ghost: where it is, its last move, and the move it chose next."""

    name: str
    cell: tuple[int, int]
    heading: str
    next_move: str = ""
    decision: dict = field(default_factory=dict)


class Game:
    """The maze, Pac-Man, the ghosts and the pellets, from a seed.

    `schedule` is the ghosts' modes over time: None for the arcade's in
    `rules.json`, or another, as T98's MDP plays chase for ever.
    """

    def __init__(self, seed: int, ghost_names: list[str] | None = None,
                 schedule: list[dict] | None = None) -> None:
        self.dice = Xorshift(seed)
        self.schedule = schedule
        self.pacman = tuple(rules.MAZE["pacman"]["cell"])
        self.facing = rules.MAZE["pacman"]["facing"]
        self.pellets = [tuple(cell) for cell in rules.MAZE["pellets"]]
        self.steps = 0
        self.outcome = PLAYING
        names = ghost_names if ghost_names is not None else rules.RULES["ghosts"]
        self.ghosts = [Ghost(name, tuple(rules.MAZE["ghosts"][name]["cell"]), rules.MAZE["ghosts"][name]["heading"])
                       for name in names]
        for ghost in self.ghosts:
            self._decide(ghost, reversing=False)

    def mode(self) -> str:
        """The mode the ghosts are in for the step about to be played."""
        return rules.mode_at(self.steps, self.schedule)

    def step(self, move: str) -> None:
        """Play one step with Pac-Man's `move`. A finished game stays as it is."""
        if self.outcome != PLAYING:
            return
        if rules.is_open(rules.moved(self.pacman, move)):
            self.pacman = rules.moved(self.pacman, move)
            self.facing = move
        if any(ghost.cell == self.pacman for ghost in self.ghosts):
            self.outcome = CAUGHT
            return
        if self.pacman in self.pellets:
            self.pellets.remove(self.pacman)
            if not self.pellets:
                self.outcome = WON
                return
        self._ghosts_move()
        if self.outcome == PLAYING:
            self._ghosts_choose()

    # Every ghost moves, even after one has caught him. Passing through him
    # is not a case: he moved first, and walking onto a ghost was a catch.
    def _ghosts_move(self) -> None:
        for ghost in self.ghosts:
            ghost.cell = rules.moved(ghost.cell, ghost.next_move)
            ghost.heading = ghost.next_move
            if ghost.cell == self.pacman:
                self.outcome = CAUGHT

    def _ghosts_choose(self) -> None:
        reversing = rules.mode_at(self.steps + 1, self.schedule) != rules.mode_at(self.steps, self.schedule)
        self.steps += 1
        for ghost in self.ghosts:
            self._decide(ghost, reversing)

    def _decide(self, ghost: Ghost, reversing: bool) -> None:
        mode = self.mode()
        goal = rules.target(ghost.name, mode, self.pacman, self.facing)
        open_ways = rules.ways(ghost.cell, ghost.heading, goal)
        if reversing:
            back = rules.reverse(ghost.heading)
            open_ways = [{"direction": back, "beyond": rules.moved(ghost.cell, back),
                          "squared": rules.squared_distance(rules.moved(ghost.cell, back), goal)}]
            choice = {"chosen": back, "best": back, "kind": rules.REVERSAL}
        else:
            choice = rules.choose(open_ways, mode, self.dice)
        ghost.next_move = choice["chosen"]
        ghost.decision = {"mode": mode, "target": goal, "ways": open_ways, **choice}

    def snapshot(self) -> dict:
        """Where everything is, as a vector records it after each step."""
        return {
            "pacman": list(self.pacman),
            "facing": self.facing,
            "ghosts": [[ghost.cell[0], ghost.cell[1], ghost.next_move, ghost.decision["kind"],
                        ghost.decision["target"][0], ghost.decision["target"][1]] for ghost in self.ghosts],
            "pellets": len(self.pellets),
            "mode": self.mode(),
            "outcome": self.outcome,
        }


def replay(seed: int, moves: list[str], ghost_names: list[str] | None = None) -> list[dict]:
    """The snapshot before the first move and after every move of `moves`."""
    game = Game(seed, ghost_names)
    seen = [game.snapshot()]
    for move in moves:
        game.step(move)
        seen.append(game.snapshot())
    return seen
