"""The maze as an MDP: T97's rules, made into states, actions and outcomes.

Nothing about the game is rewritten here. A ghost's ways, the Dossier's
choice and the chance of each way come from `gameaikit.maze.rules`, the
same functions the Python twin of the game plays by and the vectors hold
to Godot's -- so the model is the game, in the regime `mdp.json` names:
Blinky alone, chasing for ever (the owner's decision of 2026-10-29).

A state is (Pac-Man's cell, Blinky's cell, Blinky's heading, the pellets
left as a bit mask). Blinky's next move was chosen at the end of the last
step from exactly those, so it is not in the state: it is the chance in
each outcome. An action is one of Pac-Man's four moves. Only states the
game can reach are listed -- Blinky came from the cell behind him, so
that cell is floor; Pac-Man never stands on a pellet he has not eaten;
the two never share a cell, since that ended the game.

`index` numbers a state the way the published files are laid out, so
Godot finds a state's value and action by arithmetic, not by a search.

When not to use it: with Pinky too. A second ghost multiplies the states
by about 200, past what pure Python solves on a laptop in minutes.
"""

from __future__ import annotations

import json

from gameaikit.maze import rules
from gameaikit.mdp.model import Described, FiniteMdp

SPEC = json.loads((rules.HERE / "mdp.json").read_text())
REWARDS = SPEC["rewards"]
#: The one ghost of the solved game; the model below is written for him.
GHOST = "blinky"
#: Pac-Man's moves, in the order a tie between two is broken.
ACTIONS = rules.TIE_ORDER
#: Every floor cell, numbered as the published files number them.
CELLS = rules.floor_cells()
CELL_NUMBER = {cell: number for number, cell in enumerate(CELLS)}
PELLETS = [tuple(cell) for cell in rules.MAZE["pellets"]]
ALL_PELLETS = (1 << len(PELLETS)) - 1
if SPEC["ghosts"] != [GHOST] or rules.RULES["targets"][GHOST]["chase"] != "pacman":
    raise ValueError("the maze's MDP is written for Blinky alone, aiming at Pac-Man's cell")

#: (Pac-Man's cell, Blinky's cell, Blinky's heading, the pellets left as bits).
State = tuple[tuple[int, int], tuple[int, int], str, int]


def states() -> list[State]:
    """Every state the game can be in while it is on, in the files' order."""
    found = []
    for pacman in CELLS:
        for ghost in CELLS:
            for heading in ACTIONS:
                for pellets in range(1, ALL_PELLETS + 1):
                    state = (pacman, ghost, heading, pellets)
                    if is_possible(state):
                        found.append(state)
    return found


def is_possible(state: State) -> bool:
    """Whether the game can stand in `state` with nobody caught and a pellet left."""
    pacman, ghost, heading, pellets = state
    came_from = rules.moved(ghost, rules.reverse(heading))
    return (pacman != ghost and rules.is_open(came_from) and pellets != 0
            and not pellets & pellet_bit(pacman))


def pellet_bit(cell: tuple[int, int]) -> int:
    """The bit of the pellet on `cell`, or 0 where none was ever laid."""
    return 1 << PELLETS.index(cell) if cell in PELLETS else 0


def ghost_chances(state: State) -> dict[str, float]:
    """Blinky's next move and its probability, as the rules choose it: chase, aiming at Pac-Man.

    His chase target is Pac-Man's own cell, so the way Pac-Man faces --
    which is not in the state -- does not enter it (`rules.target`).
    """
    pacman, ghost, heading, _ = state
    return rules.chances(rules.ways(ghost, heading, pacman), rules.CHASE)


def transition(state: State, action: str) -> list[Described]:
    """What Pac-Man's `action` can lead to: (probability, reward, next state or None).

    In the order of a step in `rules.json`: he moves, is caught walking
    onto Blinky, eats, and wins with the last pellet; then Blinky takes
    his move, and catches him on his cell.
    """
    pacman, ghost, _, pellets = state
    after = rules.moved(pacman, action) if rules.is_open(rules.moved(pacman, action)) else pacman
    if after == ghost:
        return [(1.0, REWARDS["step"] + REWARDS["caught"], None)]
    reward = REWARDS["step"]
    if pellets & pellet_bit(after):
        reward += REWARDS["pellet"]
        pellets &= ~pellet_bit(after)
        if pellets == 0:
            return [(1.0, reward + REWARDS["cleared"], None)]
    outcomes = []
    for move, probability in ghost_chances(state).items():
        if probability == 0.0:
            continue
        ghost_after = rules.moved(ghost, move)
        if ghost_after == after:
            outcomes.append((probability, reward + REWARDS["caught"], None))
        else:
            outcomes.append((probability, reward, (after, ghost_after, move, pellets)))
    return outcomes


def build() -> FiniteMdp:
    """The maze's MDP, every reachable state's every action written out."""
    return FiniteMdp.from_model(states(), ACTIONS, transition, SPEC["discount"])


def index(state: State) -> int:
    """Where `state` sits in the published files: one slot per combination, possible or not."""
    pacman, ghost, heading, pellets = state
    row = (CELL_NUMBER[pacman] * len(CELLS) + CELL_NUMBER[ghost]) * len(ACTIONS) + ACTIONS.index(heading)
    return row * (ALL_PELLETS + 1) + pellets


def slots() -> int:
    """How many slots the published files have, possible states and not."""
    return len(CELLS) * len(CELLS) * len(ACTIONS) * (ALL_PELLETS + 1)
