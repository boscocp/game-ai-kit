"""Play a recorded conversation back through the validator and a game's rules.

The tier-1 lesson of `ai_llm`, with no model installed: a recording holds
what a model answered to each line the player typed, and this runs each
answer through the same rules a live game would -- the validator first,
then the game's own rules on what passed. Nothing here calls a model.

    PYTHONPATH=python python3 -m gameaikit.llm.replay spec/llm/recordings/the-gatekeeper.json

prints, for each turn, what the player typed, what the character says, and
either the intent and argument the game acts on or the reason the model's
reply was refused.

A recording is a JSON object: `declaration` (the game's intents, its
fallback line and its secrets, as `Declaration` holds them) and `turns`, a
list of `player` (what was typed) and `raw` (the model's text, untouched).
"""

from __future__ import annotations

import dataclasses
import json
import pathlib
import sys
from typing import Callable

from .validator import Declaration, Reply, validate, why_declaration_is_wrong

# A game's rules: given what the game knew and one validated reply, what it
# knows now. The reply is the only thing from the model a rule ever sees.
Rules = Callable[[dict, Reply], dict]


@dataclasses.dataclass(frozen=True)
class Turn:
    """One line the player typed, the reply the game acted on, and the state after."""

    player: str
    reply: Reply
    state: dict


def declaration_from(data: dict) -> Declaration:
    """A recording's `declaration`, as the validator takes it."""
    return Declaration(
        intents={name: list(values) for name, values in data["intents"].items()},
        fallback_speech=data["fallback_speech"],
        secrets=tuple(data.get("secrets", ())),
    )


def replay(recording: dict, rules: Rules | None = None,
           state: dict | None = None) -> list[Turn]:
    """Every turn of `recording`, validated and handed to `rules` in order.

    Without rules the state stays as given: what is left is the validator's
    verdict on each reply, which is the half of the lesson that needs no game.
    """
    declaration = declaration_from(recording["declaration"])
    wrong = why_declaration_is_wrong(declaration)
    if wrong:
        raise ValueError(f"the recording's declaration: {wrong}")
    current = dict(state or {})
    turns = []
    for turn in recording["turns"]:
        reply = validate(turn["raw"], declaration)
        if rules is not None:
            current = rules(current, reply)
        turns.append(Turn(turn["player"], reply, dict(current)))
    return turns


def describe(turn: Turn) -> str:
    """One turn in three lines, as the game would show it beside the character."""
    reply = turn.reply
    verdict = (f"acts on: {reply.intent} {reply.argument}".rstrip() if reply.accepted
               else f"refused: {reply.refusal}")
    return f"player: {turn.player}\ncharacter: {reply.speech}\n  {verdict}"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 -m gameaikit.llm.replay RECORDING.json", file=sys.stderr)
        return 2
    try:
        recording = json.loads(pathlib.Path(argv[0]).read_text(encoding="utf-8"))
        turns = replay(recording)
    except (OSError, ValueError, KeyError) as error:
        print(f"replay: cannot play {argv[0]}: {error}", file=sys.stderr)
        return 2
    for turn in turns:
        print(describe(turn))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
