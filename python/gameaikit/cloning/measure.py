"""Split by recording, fit on one part, and score every method on the other.

The split is the whole of the honesty here. Training accuracy is not a
result: a ghost that has met every training situation scores well on them by
looking them up, and says nothing about the next fight. So whole recordings
are held out -- every fourth, counting back from the last -- and every
number in the comparison is measured on those, which nothing was fitted on.

The n-gram is the exception, and on purpose: T17's table starts empty every
fight and learns *during* it. Scored on a held-out recording it guesses each
action from what it had seen by then -- every action that began at least
`reaction` frames before -- as the learner, seated behind the same delay,
does in the game. So it is asked the same question as the others, as late:
what the player will do next, from the fight a quarter of a second ago. The
others were fitted on other fights and learn nothing during this one. That
is the difference being measured.
"""

from __future__ import annotations

import time
from collections import Counter
from collections.abc import Callable
from dataclasses import dataclass

from ..ngram import NGramPredictor
from . import softmax
from .ghost import CaseTable, likeliest
from .rows import Session, Situation

#: T17's settings, as the game's learner uses them.
NGRAM_ORDER = 2
NGRAM_DECAY = 0.8
NGRAM_PRIOR = 1.0
#: One recording in this many is held out.
HOLD_OUT_EVERY = 4


@dataclass
class Score:
    """One method, measured on the held-out rows."""

    method: str
    right: int
    rows: int
    size: int
    seconds: float
    how: str

    def accuracy(self) -> float:
        """How often its likeliest action was the one taken."""
        return self.right / self.rows if self.rows else 0.0


def split(sessions: list[Session]) -> tuple[list[Session], list[Session]]:
    """Training and held-out recordings: every fourth held out, the last first.

    With fewer than two recordings nothing can be held out, and the held-out
    list is empty -- which `compare.py` refuses to report on.
    """
    if len(sessions) < 2:
        return list(sessions), []
    last = len(sessions) - 1
    held = [session for index, session in enumerate(sessions) if (last - index) % HOLD_OUT_EVERY == 0]
    return [session for session in sessions if session not in held], held


def rows_of(sessions: list[Session]) -> list[tuple[Situation, str]]:
    """Every row of `sessions`, in order."""
    return [row for session in sessions for row in session.rows]


def scored(method: str, guess: Callable[[Situation], str], held: list[Session], size: int, seconds: float,
           how: str) -> Score:
    """`guess` asked about every held-out row, and how often it was right."""
    rows = rows_of(held)
    right = sum(1 for situation, action in rows if guess(situation) == action)
    return Score(method, right, len(rows), size, seconds, how)


def ngram_score(held: list[Session], actions: list[str], reaction: int) -> Score:
    """T17's n-gram, empty at the start of every held-out fight, learning as it sees."""
    right, rows = 0, 0
    for session in held:
        predictor = NGramPredictor(NGRAM_ORDER, actions, NGRAM_DECAY, NGRAM_PRIOR)
        seen = 0
        for action, frame in zip(session.actions(), session.frames):
            while seen < len(session.frames) and session.frames[seen] <= frame - reaction:
                predictor.observe(session.actions()[seen])
                seen += 1
            right += predictor.likeliest() == action
            rows += 1
    size = len(actions) * len(actions)
    how = f"order {NGRAM_ORDER}, decay {NGRAM_DECAY}; learns during the fight, {reaction} frames late"
    return Score("n-gram (T17)", right, rows, size, 0.0, how)


def timed(build: Callable[[], object]) -> tuple[object, float]:
    """What `build` returns, and how many seconds it took."""
    started = time.perf_counter()
    built = build()
    return built, time.perf_counter() - started


def every_score(training: list[Session], held: list[Session], features: list[str],
                actions: list[str], reaction: int = 15) -> tuple[list[Score], softmax.Softmax, CaseTable]:
    """Every method, fitted on `training` and scored on `held`; and the model and table to publish."""
    rows = rows_of(training)
    commonest = likeliest(Counter(action for _, action in rows), actions)
    table, counting = timed(lambda: CaseTable(features, rows))
    sequence, fitting_sequence = timed(lambda: softmax.fit(rows, ["last"], actions))
    model, fitting = timed(lambda: softmax.fit(rows, features, actions))
    scores = [
        scored("always the commonest", lambda _: commonest, held, 1, 0.0, f"always {commonest}: the floor"),
        ngram_score(held, actions, reaction),
        scored("ghost, exact", lambda situation: likeliest(table.exact(situation) or table.everything(), actions),
               held, table.size(), counting, f"{len(table.cases)} situations met; all its play when unmet"),
        scored("ghost, nearest", lambda situation: likeliest(table.nearest(situation)[1], actions), held,
               table.size(), counting, "the cases fewest features away, pooled"),
        scored("model, last action only", sequence.likeliest, held, sequence.size(), fitting_sequence,
               "softmax over what the n-gram sees, fitted beforehand"),
        scored("model, the situation", model.likeliest, held, model.size(), fitting,
               f"softmax over {len(features)} features"),
    ]
    return scores, model, table


def leave_one_out(sessions: list[Session], features: list[str], actions: list[str],
                  reaction: int = 15) -> list[Score]:
    """Every method scored on every recording in turn, fitted on all the others, pooled.

    A held-out set of three fights can be decided by one of them. Holding
    each recording out once uses every fight for scoring and none for
    scoring itself; the n-gram, which fits nothing beforehand, scores the
    same either way.
    """
    pooled: dict[str, Score] = {}
    for index, held in enumerate(sessions):
        others = sessions[:index] + sessions[index + 1:]
        scores, _, _ = every_score(others, [held], features, actions, reaction)
        for score in scores:
            total = pooled.setdefault(score.method, Score(score.method, 0, 0, 0, 0.0, "left out one at a time"))
            total.right += score.right
            total.rows += score.rows
    return list(pooled.values())
