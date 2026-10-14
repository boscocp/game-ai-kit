"""Alpha-beta to a fixed depth, as `ai_adversarial/alpha_beta.gd` searches.

Self-play and the match run here, so the search runs here too; it is the
Godot file's algorithm (Russell & Norvig, 4th edition, figure 5.7, with the
depth cutoff of section 5.3), and its tie-break: of equal moves, the first in
`rules.legal_moves` order wins. With a fixed order and a fixed depth a game
is a function of its opening, which is why `selfplay.py` randomises openings.

A won game is worth `WIN`, far above anything three counts can add up to,
and a drawn one 0, as in `checkers_game.gd`.

When not to use it: depth beyond 4 here. Python is the slow half of the kit;
the Godot game searches deeper in the same time.
"""

from __future__ import annotations

import math

from . import evaluation, rules

WIN = 1000.0


def best_move(board: rules.Board, depth: int, weights: tuple[float, ...]) -> rules.Move | None:
    """The move alpha-beta picks for the side to move, looking `depth` plies
    ahead and scoring the leaves with `weights`; None when there is no move."""
    player = board.to_move
    best, best_value, alpha = None, -math.inf, -math.inf
    for move in rules.legal_moves(board):
        value = _min_value(rules.play(board, move), alpha, math.inf, 1, max(depth, 1), player, weights)
        if value > best_value:
            best, best_value = move, value
        alpha = max(alpha, best_value)
    return best


def evaluate(board: rules.Board, player: int, weights: tuple[float, ...]) -> float:
    """A finished game by its result, an unfinished one by `weights`."""
    if rules.is_draw(board):
        return 0.0
    won_by = rules.winner(board)
    if won_by != -1:
        return WIN if won_by == player else -WIN
    return evaluation.score(board, player, weights)


def _max_value(board: rules.Board, alpha: float, beta: float, depth: int, limit: int, player: int,
               weights: tuple[float, ...]) -> float:
    """The player to search for is to move: take the best, stop at `beta`."""
    if rules.is_over(board) or depth >= limit:
        return evaluate(board, player, weights)
    value = -math.inf
    for move in rules.legal_moves(board):
        value = max(value, _min_value(rules.play(board, move), alpha, beta, depth + 1, limit, player, weights))
        if value >= beta:
            return value
        alpha = max(alpha, value)
    return value


def _min_value(board: rules.Board, alpha: float, beta: float, depth: int, limit: int, player: int,
               weights: tuple[float, ...]) -> float:
    """The opponent is to move: take the worst for the player, stop at `alpha`."""
    if rules.is_over(board) or depth >= limit:
        return evaluate(board, player, weights)
    value = math.inf
    for move in rules.legal_moves(board):
        value = min(value, _max_value(rules.play(board, move), alpha, beta, depth + 1, limit, player, weights))
        if value <= alpha:
            return value
        beta = min(beta, value)
    return value
