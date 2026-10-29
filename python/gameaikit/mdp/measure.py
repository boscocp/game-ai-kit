"""How the published policy plays, against two controllers that do not plan;
why it is never caught; and value iteration against policy iteration.

    PYTHONPATH=python python3 -m gameaikit.mdp.measure [--episodes 1000]
    PYTHONPATH=python python3 -m gameaikit.mdp.measure --compare

All three play `gameaikit.maze.game` -- the game, not the model -- in the
regime the MDP was solved for (Blinky alone, chasing for ever), each
episode from seed 1, 2, 3 ... so the dice are the same for each. The
MDP reads its action from the published `policy.json`, as Godot does.
The greedy controller walks the shortest path to the nearest pellet,
found by A* with the Manhattan distance, and never looks at Blinky. The
safe greedy one walks the same path but refuses any move onto a cell
Blinky could stand on after the step, taking the first safe move in tie
order instead -- one rule, no planning.

Never being caught is not luck, and `catch_from_start` shows why: with one
ghost at Pac-Man's own speed and no dead end, every state has a move with
no catch in the next step, so a careful Pac-Man is never caught. What
value iteration adds over the safe greedy rule is the weighing of waiting
against running: fewer steps to the last pellet.

An episode ends won, caught, or after `STEP_LIMIT` steps, which counts as
neither: a policy that runs from the ghost for ever is a policy too.
"""

from __future__ import annotations

import argparse
import heapq
import json
import pathlib
import resource
import sys
import time

from gameaikit.maze import game, rules
from gameaikit.mdp import maze, publish, solve

REPOSITORY = pathlib.Path(__file__).resolve().parents[3]
PUBLISHED = REPOSITORY / "data" / "maze"
STEP_LIMIT = 400
EPISODES = 1000
WORDS = {letter: word for word, letter in publish.LETTERS.items()}


def read_policy(folder: pathlib.Path = PUBLISHED) -> list[str]:
    """The published policy, one letter a slot, laid out by `maze.index`."""
    rows = json.loads((folder / publish.POLICY_FILE).read_text(encoding="utf-8"))["actions"]
    return list("".join(rows))


def state_of(played: game.Game) -> maze.State:
    """The MDP's state of a game in progress."""
    blinky = played.ghosts[0]
    pellets = sum(maze.pellet_bit(cell) for cell in played.pellets)
    return (played.pacman, blinky.cell, blinky.heading, pellets)


def mdp_move(played: game.Game, policy: list[str]) -> str:
    """The published policy's move in this game's state."""
    return WORDS[policy[maze.index(state_of(played))]]


def a_star(start: tuple[int, int], goal: tuple[int, int]) -> list[tuple[int, int]]:
    """The shortest path of cells from `start` to `goal`, both included."""
    frontier = [(_manhattan(start, goal), 0, start)]
    came_from = {start: start}
    cost = {start: 0}
    while frontier:
        _, so_far, cell = heapq.heappop(frontier)
        if cell == goal:
            break
        for direction in rules.TIE_ORDER:
            beyond = rules.moved(cell, direction)
            if rules.is_open(beyond) and so_far + 1 < cost.get(beyond, so_far + 2):
                cost[beyond], came_from[beyond] = so_far + 1, cell
                heapq.heappush(frontier, (so_far + 1 + _manhattan(beyond, goal), so_far + 1, beyond))
    path = [goal]
    while path[-1] != start:
        path.append(came_from[path[-1]])
    return path[::-1]


def _manhattan(first: tuple[int, int], second: tuple[int, int]) -> int:
    return abs(first[0] - second[0]) + abs(first[1] - second[1])


def greedy_move(played: game.Game) -> str:
    """The first step towards the nearest pellet by A*, Blinky ignored."""
    paths = [a_star(played.pacman, pellet) for pellet in played.pellets]
    nearest = min(paths, key=len)
    for direction in rules.TIE_ORDER:
        if rules.moved(played.pacman, direction) == nearest[1]:
            return direction
    raise ValueError(f"no step from {played.pacman} along {nearest}")


def risks_a_catch(state: maze.State, move: str) -> bool:
    """Whether `move` can end in a catch this step: onto Blinky, or onto a cell he may take."""
    # An episode ends caught (a loss, even with a pellet eaten on the way) or cleared (a gain).
    return any(after is None and reward < 0.0
               for _, reward, after in maze.transition(state, move))


def safe_greedy_move(played: game.Game) -> str:
    """The greedy move, unless it risks a catch; then the first move in tie order that does not."""
    state = state_of(played)
    first = greedy_move(played)
    if not risks_a_catch(state, first):
        return first
    return next((move for move in rules.TIE_ORDER if not risks_a_catch(state, move)), first)


CONTROLLERS = {"greedy": lambda played, policy: greedy_move(played),
               "safe greedy": lambda played, policy: safe_greedy_move(played),
               "mdp": mdp_move}


def episode(seed: int, controller: str, policy: list[str]) -> dict:
    """One game from `seed`, played to its end or to `STEP_LIMIT`."""
    played = game.Game(seed, maze.SPEC["ghosts"], maze.SPEC["schedule"])
    while played.outcome == game.PLAYING and played.steps < STEP_LIMIT:
        played.step(CONTROLLERS[controller](played, policy))
    eaten = len(maze.PELLETS) - len(played.pellets)
    return {"outcome": played.outcome, "pellets": eaten, "steps": played.steps}


def summary(controller: str, episodes: int, policy: list[str]) -> dict:
    """Mean pellets, catches, wins and unfinished games over seeds 1 to `episodes`."""
    played = [episode(seed, controller, policy) for seed in range(1, episodes + 1)]
    return {
        "controller": controller,
        "episodes": episodes,
        "mean_pellets": sum(one["pellets"] for one in played) / episodes,
        "caught": sum(one["outcome"] == game.CAUGHT for one in played),
        "won": sum(one["outcome"] == game.WON for one in played),
        "unfinished": sum(one["outcome"] == game.PLAYING for one in played),
        "mean_steps_to_win": _mean([one["steps"] for one in played if one["outcome"] == game.WON]),
        "mean_steps_won_or_lost": _mean([one["steps"] for one in played]),
    }


def catch_from_start(policy: list[str]) -> dict:
    """Every state the published policy can reach from the start, and how many could end in a catch.

    Over the model's outcomes, every way Blinky's dice may fall: if no
    reachable state's chosen move has a catch among its outcomes, the
    policy's chance of being caught is exactly 0. Also: how many of all
    the states have no move free of a catch next step -- 0 means a
    careful Pac-Man can always step aside.
    """
    start = (tuple(maze.rules.MAZE["pacman"]["cell"]), tuple(maze.rules.MAZE["ghosts"]["blinky"]["cell"]),
             maze.rules.MAZE["ghosts"]["blinky"]["heading"], maze.ALL_PELLETS)
    seen, waiting, risky = {start}, [start], 0
    while waiting:
        state = waiting.pop()
        move = WORDS[policy[maze.index(state)]]
        risky += risks_a_catch(state, move)
        for _, _, after in maze.transition(state, move):
            if after is not None and after not in seen:
                seen.add(after)
                waiting.append(after)
    cornered = sum(all(risks_a_catch(state, move) for move in maze.ACTIONS) for state in maze.states())
    return {"reached": len(seen), "reached_with_a_catch_possible": risky, "states_with_no_safe_move": cornered}


def _mean(numbers: list[int]) -> float:
    return sum(numbers) / len(numbers) if numbers else 0.0


def compare() -> dict:
    """Both solvers on the maze: seconds, sweeps, Q-values computed, and where they agree.

    Seconds are this machine's; the counts are the same on every machine.
    Peak memory is the process's, model and both solutions together.
    """
    started = time.perf_counter()
    mdp = maze.build()
    built = time.perf_counter()
    by_values = solve.value_iteration(mdp, maze.SPEC["epsilon"])
    valued = time.perf_counter()
    by_policy = solve.policy_iteration(mdp, maze.SPEC["epsilon"])
    finished = time.perf_counter()
    differ = [state for state in range(len(mdp.states)) if by_values.policy[state] != by_policy.policy[state]]
    gap = max((abs(solve.q_value(mdp, by_values.values, state, by_values.policy[state])
                   - solve.q_value(mdp, by_values.values, state, by_policy.policy[state])) for state in differ),
              default=0.0)
    return {"states": len(mdp.states), "build_seconds": round(built - started, 1),
            "value_iteration": {"seconds": round(valued - built, 1), "sweeps": by_values.sweeps,
                                "backups": by_values.backups},
            "policy_iteration": {"seconds": round(finished - valued, 1), "improvements": by_policy.improvements,
                                 "sweeps": by_policy.sweeps, "backups": by_policy.backups},
            "largest_value_difference": max(abs(one - other) for one, other in zip(by_values.values, by_policy.values)),
            "states_choosing_differently": len(differ), "largest_q_gap_where_they_differ": gap,
            "peak_megabytes": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss // 1024}


def main(argv: list[str]) -> int:
    """Print both controllers' summaries, one line each; or, with --compare, the two solvers."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--episodes", type=int, default=EPISODES)
    parser.add_argument("--compare", action="store_true")
    arguments = parser.parse_args(argv)
    if arguments.compare:
        print(json.dumps(compare(), indent=1))
        return 0
    policy = read_policy()
    for controller in CONTROLLERS:
        print(json.dumps(summary(controller, arguments.episodes, policy)))
    print(json.dumps(catch_from_start(policy)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
