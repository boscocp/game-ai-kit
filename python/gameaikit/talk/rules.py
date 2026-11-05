"""The guard at the door: what each act the player made does to his trust.

`gate.json` here is a byte-for-byte copy of `spec/talk/gate.json`, and its
"about" is these rules in words. The language model never reaches this
file: it said which act the player's words were, the validator ruled on
that (`gameaikit.llm`), and only the act -- an intent and its argument --
arrives here. A reply that was refused arrives as `unclear`, which moves
nothing but spends a turn.

The rules are a list read top to bottom, the first that fits deciding. An
act is written `intent:argument`, or the bare intent when it has none, and
a rule fits when its `act` is the act or the act's intent, and, if it has
`if_any`, when one of the acts named there -- other than this very act --
was made before. What it moves
is two numbers: trust, which opens the door at `open_at`, and suspicion,
which sounds the alarm at `alarm_at`. Saying the same thing twice wins no
trust the second time and costs its suspicion again -- except `unclear`,
which is nothing understood and is never "said before".

When not to use it: for a conversation whose outcome should be the model's
to judge. Here no sentence the model writes can open the door, and that is
the point -- the lesson of Facade's design (Mateas and Stern, 2004).
"""

from __future__ import annotations

import dataclasses
import json
import pathlib

from gameaikit.llm import Declaration

HERE = pathlib.Path(__file__).resolve().parent
SCENE = json.loads((HERE / "gate.json").read_text(encoding="utf-8"))

#: The outcomes. "playing" until one of the other three.
PLAYING = "playing"
OPEN = "open"
ALARM = "alarm"
SENT_AWAY = "sent_away"


@dataclasses.dataclass(frozen=True)
class Guard:
    """What the guard thinks of the player after some turns, and what was said."""

    trust: int = 0
    suspicion: int = 0
    turn: int = 0
    said: tuple[str, ...] = ()
    outcome: str = PLAYING


@dataclasses.dataclass(frozen=True)
class Ruling:
    """One act, the rule that fired on it, and the guard after it."""

    act: str
    rule: str
    trust: int
    suspicion: int
    guard: Guard


def act_of(intent: str, argument: str) -> str:
    """The act as the rules spell it: `intent:argument`, or the intent alone."""
    return f"{intent}:{argument}" if argument else intent


def rule_for(act: str, said: tuple[str, ...], scene: dict = SCENE) -> dict:
    """The first rule that fits `act`, given the acts already `said`.

    A KeyError when none does: `why_scene_is_wrong` refuses a scene where an
    act the guard understands has no rule, so a game never meets one.
    """
    intent = act.split(":")[0]
    for rule in scene["rules"]:
        if rule["act"] not in (act, intent):
            continue
        if "if_any" in rule and not any(_was_said(earlier, said, act) for earlier in rule["if_any"]):
            continue
        return rule
    raise KeyError(f"no rule for the act {act}")


def step(guard: Guard, intent: str, argument: str, scene: dict = SCENE) -> Ruling:
    """The guard after one more act. A guard whose outcome is decided stays so."""
    act = act_of(intent, argument)
    if guard.outcome != PLAYING:
        return Ruling(act, "", 0, 0, guard)
    rule = rule_for(act, guard.said, scene)
    trust, suspicion, fired = rule["trust"], rule["suspicion"], rule["id"]
    if act in guard.said and act not in scene["said_before"]["except"]:
        trust, fired = 0, scene["said_before"]["id"]
    after = Guard(guard.trust + trust, guard.suspicion + suspicion, guard.turn + 1,
                  guard.said + (act,))
    after = dataclasses.replace(after, outcome=outcome_of(after, scene))
    return Ruling(act, fired, trust, suspicion, after)


def outcome_of(guard: Guard, scene: dict = SCENE) -> str:
    """The alarm first, then the door, then the last turn; otherwise still playing.

    The alarm wins a tie: a guard both trusting and alarmed calls it in.
    """
    if guard.suspicion >= scene["alarm_at"]:
        return ALARM
    if guard.trust >= scene["open_at"]:
        return OPEN
    if guard.turn >= scene["turns"]:
        return SENT_AWAY
    return PLAYING


def declaration(language: str, scene: dict = SCENE) -> Declaration:
    """What the validator holds the model's replies to, in `language`."""
    return Declaration(
        intents={name: list(values) for name, values in scene["intents"].items()},
        fallback_speech=scene["languages"][language]["fallback"],
        secrets=tuple(scene["secrets"]),
    )


def why_scene_is_wrong(scene: dict = SCENE) -> str:
    """Why the scene cannot be played, or "": every act needs a rule, and the
    rules may name only acts the guard understands."""
    acts = every_act(scene)
    for act in acts:
        try:
            rule_for(act, tuple(acts), scene)
        except KeyError:
            return f"the act {act} has no rule"
    for rule in scene["rules"]:
        for named in [rule["act"], *rule.get("if_any", [])]:
            if named not in acts and named not in scene["intents"]:
                return f"the rule {rule['id']} names {named}, which is not an act"
    for language, words in scene["languages"].items():
        if any(secret.lower() in words["instructions"].lower() for secret in scene["secrets"]):
            return f"the {language} instructions contain a secret"
    return ""


def every_act(scene: dict = SCENE) -> list[str]:
    """Every act the guard understands: each intent with each of its arguments,
    or alone when it takes none."""
    acts = []
    for intent, arguments in scene["intents"].items():
        acts += [act_of(intent, argument) for argument in arguments] or [intent]
    return acts


def _was_said(earlier: str, said: tuple[str, ...], act: str) -> bool:
    """True when `earlier` -- an act, or a bare intent meaning any of its acts --
    was said as some act other than `act`: claiming the same role twice is
    not a second role."""
    return any(other != act and (other == earlier or other.split(":")[0] == earlier)
               for other in said)
