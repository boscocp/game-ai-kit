"""The rest of `gameaikit.llm`: the game's declaration, the schema, the replay.

The validator's answer to each reply is the vectors' (`test_llm_vectors.py`).
Here: a declaration that cannot be validated against is refused when the
game is built; the schema a runtime is handed is the committed one narrowed;
and a recorded conversation, replayed, reaches the game's rules only through
replies that passed.
"""

import contextlib
import io
import json
import pathlib
import re
import unittest

from gameaikit.llm import validator
from gameaikit.llm.replay import describe, main, replay

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "spec" / "llm" / "reply.schema.json"
RECORDING = ROOT / "spec" / "llm" / "recordings" / "the-gatekeeper.json"

GUARD = validator.Declaration({"greet": [], "claim": ["merchant"]}, "Again?", ("owl-eyes",))


def trust_rules(state: dict, reply: validator.Reply) -> dict:
    """A game's rules, as small as rules get: a claim earns trust, a threat loses it.

    The model said which act the player's words were; what that act is worth
    is decided here, by the game, and the model is never asked.
    """
    trust = state.get("trust", 0)
    if reply.intent == "claim":
        trust += 1
    elif reply.intent == "threaten":
        trust -= 2
    return {"trust": trust}


class TheDeclaration(unittest.TestCase):

    def test_a_sound_declaration_is_taken(self) -> None:
        self.assertEqual(validator.why_declaration_is_wrong(GUARD), "")

    def test_a_declaration_with_no_intents_is_refused(self) -> None:
        empty = validator.Declaration({}, "Again?")
        self.assertIn("no intents", validator.why_declaration_is_wrong(empty))

    def test_an_empty_secret_is_refused_because_it_is_in_every_speech(self) -> None:
        careless = validator.Declaration({"greet": []}, "Again?", ("",))
        self.assertIn("empty secret", validator.why_declaration_is_wrong(careless))

    def test_an_empty_argument_is_refused(self) -> None:
        careless = validator.Declaration({"claim": [""]}, "Again?")
        self.assertIn("empty argument", validator.why_declaration_is_wrong(careless))

    def test_a_fallback_that_breaks_the_rules_it_stands_in_for_is_refused(self) -> None:
        # The fallback is what the player reads when the model is overruled,
        # so it is held to the same speech rules -- markup, length, secrets.
        for line in ("*sighs* Again?", "", "The word is owl-eyes."):
            with self.subTest(line):
                careless = validator.Declaration({"greet": []}, line, ("owl-eyes",))
                self.assertIn("fallback", validator.why_declaration_is_wrong(careless))


class TheSchema(unittest.TestCase):

    def test_the_games_schema_is_the_committed_one_once_per_intent(self) -> None:
        committed = json.loads(SCHEMA.read_text(encoding="utf-8"))
        shapes = validator.json_schema(GUARD)["anyOf"]
        self.assertEqual([shape["properties"]["intent"]["enum"] for shape in shapes],
                         [["claim"], ["greet"]])
        for shape in shapes:
            self.assertEqual(shape["required"], committed["required"])
            self.assertEqual(shape["additionalProperties"], committed["additionalProperties"])
            self.assertEqual(set(shape["properties"]), set(committed["properties"]))
            speech = dict(committed["properties"]["speech"])
            del speech["description"]
            self.assertEqual(shape["properties"]["speech"], speech)

    def test_each_intent_is_offered_only_its_own_arguments(self) -> None:
        shapes = validator.json_schema(GUARD)["anyOf"]
        self.assertEqual([shape["properties"]["argument"]["enum"] for shape in shapes],
                         [["merchant", ""], [""]])

    def test_the_committed_schema_names_the_validators_keys(self) -> None:
        committed = json.loads(SCHEMA.read_text(encoding="utf-8"))
        self.assertEqual(tuple(committed["required"]), validator.REPLY_KEYS)
        self.assertEqual(committed["properties"]["speech"]["maxLength"], validator.SPEECH_LIMIT)

    def test_the_speech_pattern_turns_away_markup_and_keeps_the_limit(self) -> None:
        # llama.cpp drops maxLength beside a pattern, so the pattern carries
        # the limit; and it reads the JSON text, so the quote and the
        # backslash stay out (T116, docs/local-llm/server.md).
        plain = ("Evening. State your business.", "Não, senhor.", "H" * validator.SPEECH_LIMIT,
                 "You're not on the list.", "Evening,\u00a0sir.")
        for speech in plain:
            with self.subTest(speech):
                self.assertIsNotNone(re.fullmatch(validator.SPEECH_PATTERN, speech))
        marked = [f"Halt {character} there." for character in validator.MARKUP]
        marked += ["", "H" * (validator.SPEECH_LIMIT + 1), "Two\nlines", 'He said "no".',
                   "a \\ b", "Evening.\x7f", "Evening.\x85", "Two\u2028lines",
                   "Two\u2029lines", "Soft\u00adhyphen", "owl\u200d-eyes", "Back\u202ewards",
                   "Tagged\U000e0041"]
        for speech in marked:
            with self.subTest(speech):
                self.assertIsNone(re.fullmatch(validator.SPEECH_PATTERN, speech))


class TheReplay(unittest.TestCase):

    def recording(self) -> dict:
        return json.loads(RECORDING.read_text(encoding="utf-8"))

    def test_the_game_decides_and_only_on_replies_that_passed(self) -> None:
        turns = replay(self.recording(), trust_rules, {"trust": 0})
        verdicts = [(turn.reply.accepted, turn.reply.intent) for turn in turns]
        self.assertEqual(verdicts, [
            (True, "greet"), (True, "claim"), (False, "unclear"),
            (False, "unclear"), (True, "threaten"),
        ])
        # One claim that passed (+1), the refused royal claim never counted,
        # one threat (-2).
        self.assertEqual([turn.state["trust"] for turn in turns], [0, 1, 1, 1, -1])

    def test_a_refused_turn_says_why_where_the_game_shows_it(self) -> None:
        turns = replay(self.recording())
        self.assertIn("refused: R11", describe(turns[2]))
        self.assertIn("acts on: claim messenger", describe(turns[1]))

    def test_a_recording_whose_declaration_is_unsound_is_refused(self) -> None:
        broken = self.recording()
        broken["declaration"]["intents"] = {}
        with self.assertRaises(ValueError):
            replay(broken)

    def test_the_program_plays_the_recording_and_refuses_a_missing_one(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(main([str(RECORDING)]), 0)
        self.assertIn("character: Say that again, slower.", out.getvalue())
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main([str(ROOT / "no-such-recording.json")]), 2)
            self.assertEqual(main([]), 2)


if __name__ == "__main__":
    unittest.main()
