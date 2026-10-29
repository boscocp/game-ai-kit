"""What to do now: every action scored by its considerations, the highest taken.

The tier-1 half of `godot/addons/ai_utility/action_choice.gd`: a
consideration reads one percept through a curve -- a line clamped to [0, 1],
or a step at a threshold -- and an action's score is its weight times every
answer, so one answer of 0 vetoes it. The highest score wins, the first of
equal scores, and nothing is chosen when none is above zero. A percept not
given counts as 0.
"""

from __future__ import annotations

import dataclasses

LINEAR, STEP = "linear", "step"
CURVES = (LINEAR, STEP)
ACTION_KEYS = {"name", "weight", "considerations"}
CONSIDERATION_KEYS = {"percept", "curve", "slope", "intercept", "at", "below", "above"}


@dataclasses.dataclass
class Consideration:
    """A percept, by name, and the curve that turns it into an answer."""

    percept: str
    curve: str = LINEAR
    slope: float = 1.0
    intercept: float = 0.0
    at: float = 0.5
    below: float = 0.0
    above: float = 1.0


@dataclasses.dataclass
class Action:
    """Something the agent can do, how much it matters, and its reasons."""

    name: str
    weight: float = 1.0
    considerations: list[Consideration] = dataclasses.field(default_factory=list)


def answer(consideration: Consideration, percepts: dict[str, float]) -> float:
    """How much `consideration` favours its action, 0 to 1."""
    value = float(percepts.get(consideration.percept, 0.0))
    if consideration.curve == STEP:
        return consideration.above if value >= consideration.at else consideration.below
    return min(max(consideration.slope * value + consideration.intercept, 0.0), 1.0)


def choose(actions: list[Action], percepts: dict[str, float]) -> tuple[list[float], list[list[float]], int]:
    """Every action's score and answers, and the index taken (-1: none)."""
    scores, answers, chosen, best = [], [], -1, 0.0
    for index, action in enumerate(actions):
        found = [answer(each, percepts) for each in action.considerations]
        score = action.weight
        for value in found:
            score *= value
        answers.append(found)
        scores.append(score)
        if score > best:
            best, chosen = score, index
    return scores, answers, chosen


def why_not_actions(data: list) -> str:
    """Why `data` is not a list of actions, or "" when it is."""
    for entry in data:
        if not isinstance(entry, dict) or "name" not in entry:
            return f"an action must be a dict with a name: {entry!r}"
        if set(entry) - ACTION_KEYS:
            return f"action {entry['name']} has an unknown key, {sorted(set(entry) - ACTION_KEYS)[0]}"
        for fields in entry.get("considerations", []):
            if not isinstance(fields, dict) or "percept" not in fields:
                return f"action {entry['name']}: a consideration must be a dict with a percept: {fields!r}"
            if set(fields) - CONSIDERATION_KEYS:
                return f"action {entry['name']}: an unknown key, {sorted(set(fields) - CONSIDERATION_KEYS)[0]}"
            if fields.get("curve", LINEAR) not in CURVES:
                return f"action {entry['name']}: no curve called {fields['curve']}"
    return ""


def actions_from(data: list[dict]) -> list[Action]:
    """Actions from plain data, as the JSON files write them; ValueError on data `why_not_actions` objects to."""
    objection = why_not_actions(data)
    if objection:
        raise ValueError(objection)
    return [Action(entry["name"], float(entry.get("weight", 1.0)),
                   [Consideration(**fields) for fields in entry.get("considerations", [])]) for entry in data]
