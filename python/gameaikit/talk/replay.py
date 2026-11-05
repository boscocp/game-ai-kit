"""Play a recorded conversation with the guard back to its outcome, with no model.

The tier-1 lesson of T94. A recording (`data/talk/recordings/`) holds what
the player said and what a local model answered, untouched. Each answer
goes through the validator first (`gameaikit.llm`), and only the act it
admits reaches the guard's rules (`rules`); a refused answer reaches them
as `unclear`. Nothing here asks a model, so the outcome is the same on
every machine -- which is what lets `spec/vectors/talk/` hold this file and
the Godot game to the same trust and suspicion after every line.

    PYTHONPATH=python python3 -m gameaikit.talk.replay data/talk/recordings/the-right-name.en.json

prints each turn: the line, the guard's answer, the act the validator
admitted (or why it refused), the rule that fired and the two numbers.
With `--vector` it prints the turns as a vector file holds them instead.

A recording is a JSON object: `language` (`en` or `pt_BR`), `turns` (each
`player`, what was typed, and `raw`, the model's text), and what made it
(`model`); `RecordedRuntime.from_file` reads the same files in Godot.
"""

from __future__ import annotations

import dataclasses
import json
import pathlib
import sys

from gameaikit.llm import Reply, validate

from . import rules


@dataclasses.dataclass(frozen=True)
class Turn:
    """One line, the reply as the validator ruled it, and what the rules made of it."""

    player: str
    reply: Reply
    ruling: rules.Ruling


def replay(recording: dict, scene: dict = rules.SCENE) -> list[Turn]:
    """Every turn of `recording` until the guard decides, in order.

    A turn after the outcome is not played: the game stops listening then,
    and a recording longer than its game would otherwise count lines nobody
    was asked.
    """
    declaration = rules.declaration(recording["language"], scene)
    guard = rules.Guard()
    turns = []
    for turn in recording["turns"]:
        if guard.outcome != rules.PLAYING:
            break
        reply = validate(turn["raw"], declaration)
        ruling = rules.step(guard, reply.intent, reply.argument, scene)
        guard = ruling.guard
        turns.append(Turn(turn["player"], reply, ruling))
    return turns


def vector_of(turns: list[Turn]) -> dict:
    """What a vector holds of a replay: each turn's act, rule and numbers, and the outcome."""
    return {
        "turns": [{
            "intent": turn.reply.intent,
            "argument": turn.reply.argument,
            "refusal_code": turn.reply.refusal.split(" ")[0] if turn.reply.refusal else "",
            "rule": turn.ruling.rule,
            "trust": turn.ruling.guard.trust,
            "suspicion": turn.ruling.guard.suspicion,
        } for turn in turns],
        "outcome": turns[-1].ruling.guard.outcome if turns else rules.PLAYING,
    }


def describe(turn: Turn, language: str = "en") -> str:
    """One turn as the game's reasoning panel shows it."""
    reply, ruling = turn.reply, turn.ruling
    heard = (f"act: {rules.act_of(reply.intent, reply.argument)}" if reply.accepted
             else f"refused: {reply.refusal}")
    return (f"player: {turn.player}\nguard: {reply.speech}\n  {heard}\n"
            f"  rule {ruling.rule} ({why_of(ruling.rule, language)}): trust {ruling.trust:+d}, "
            f"suspicion {ruling.suspicion:+d} -> {ruling.guard.trust}/{rules.SCENE['open_at']}, "
            f"{ruling.guard.suspicion}/{rules.SCENE['alarm_at']}")


def why_of(rule_id: str, language: str, scene: dict = rules.SCENE) -> str:
    """The rule's reason, in `language`."""
    if rule_id == scene["said_before"]["id"]:
        return scene["said_before"]["why"][language]
    for rule in scene["rules"]:
        if rule["id"] == rule_id:
            return rule["why"][language]
    return ""


def main(argv: list[str]) -> int:
    as_vector = "--vector" in argv
    paths = [argument for argument in argv if argument != "--vector"]
    if len(paths) != 1:
        print("usage: python3 -m gameaikit.talk.replay RECORDING.json [--vector]", file=sys.stderr)
        return 2
    try:
        recording = json.loads(pathlib.Path(paths[0]).read_text(encoding="utf-8"))
        turns = replay(recording)
    except (OSError, ValueError, KeyError) as error:
        print(f"replay: cannot play {paths[0]}: {error}", file=sys.stderr)
        return 2
    if as_vector:
        print(json.dumps(vector_of(turns), indent=2, ensure_ascii=False))
        return 0
    for turn in turns:
        print(describe(turn, recording["language"]))
    print(f"outcome: {vector_of(turns)['outcome']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
