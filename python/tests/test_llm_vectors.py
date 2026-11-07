"""The validator's answers, held to the vectors `ai_llm`'s LlmValidator is held to.

`spec/vectors/llm/replies.json` names, for every raw reply in it, the code
of the first rule it breaks -- or the speech, intent and argument the game
may act on. `godot/test/ai_llm/llm_vectors_runner.gd` reads the same file
through `LlmValidator`; `make test-llm-vectors` runs both halves.
"""

import json
import pathlib
import re
import unicodedata
import unittest

from gameaikit.llm import validator
from gameaikit.llm.replay import declaration_from

VECTOR = (pathlib.Path(__file__).resolve().parents[2]
          / "spec" / "vectors" / "llm" / "replies.json")

# Every rule the validator has. A rule with no refusing case could be deleted
# from either language with both suites green.
EVERY_CODE = {f"R{number}" for number in range(1, 12)}


def load_vector() -> dict:
    """The whole vector file."""
    return json.loads(VECTOR.read_text(encoding="utf-8"))


def load() -> tuple[validator.Declaration, list[dict]]:
    """The vector's game and its cases."""
    data = load_vector()
    return declaration_from(data["declaration"]), data["cases"]


def format_controls_of_the_vector() -> tuple[str, list[int]]:
    """The Unicode version the vector's format controls follow, and every code point in them."""
    controls = load_vector()["format_controls"]
    codes = []
    for first, last in controls["runs"]:
        codes.extend(range(int(first, 16), int(last, 16) + 1))
    return controls["unicode"], codes


def answer(case: dict, declaration: validator.Declaration) -> str:
    """What this side makes of one case: a code, or what the game acts on."""
    reply = validator.validate(case["raw"], declaration)
    if not reply.accepted:
        return reply.refusal.split(" ", 1)[0]
    return json.dumps([reply.speech, reply.intent, reply.argument], ensure_ascii=False)


def claimed(case: dict) -> str:
    """What the vector says about the same case, in the same string."""
    if "refused" in case:
        return case["refused"]
    accepted = case["accepted"]
    return json.dumps([accepted["speech"], accepted["intent"], accepted["argument"]],
                      ensure_ascii=False)


class TheVectors(unittest.TestCase):

    def test_the_vector_game_is_one_the_validator_takes(self) -> None:
        declaration, _ = load()
        self.assertEqual(validator.why_declaration_is_wrong(declaration), "")

    def test_every_case_gets_the_answer_the_vector_claims(self) -> None:
        declaration, cases = load()
        self.assertGreater(len(cases), 30)
        for case in cases:
            with self.subTest(case["why"]):
                self.assertEqual(answer(case, declaration), claimed(case))

    def test_a_wrong_claim_is_caught(self) -> None:
        # The planted case for the comparison itself: a vector whose every
        # claim this side meets is worth something only if a wrong one fails.
        declaration, cases = load()
        refused = next(case for case in cases if "refused" in case)
        accepted = next(case for case in cases if "accepted" in case)
        wrong_code = dict(refused, refused="R4")
        wrong_intent = dict(accepted, accepted=dict(accepted["accepted"], intent="threaten"))
        accepted_as_refused = {"why": "planted", "raw": accepted["raw"], "refused": "R1"}
        for wrong in (wrong_code, wrong_intent, accepted_as_refused):
            with self.subTest(wrong["why"]):
                self.assertNotEqual(answer(wrong, declaration), claimed(wrong))

    def test_every_rule_has_a_case_that_it_refuses(self) -> None:
        _, cases = load()
        covered = {case["refused"] for case in cases if "refused" in case}
        self.assertEqual(covered, EVERY_CODE)

    def test_every_refused_case_becomes_the_games_fallback(self) -> None:
        # Never a retry and never a stall: a refusal is answered at once, with
        # the game's line and the one intent its rules always handle.
        declaration, cases = load()
        for case in cases:
            if "refused" not in case:
                continue
            reply = validator.validate(case["raw"], declaration)
            with self.subTest(case["why"]):
                self.assertEqual(reply.speech, declaration.fallback_speech)
                self.assertEqual(reply.intent, validator.FALLBACK_INTENT)
                self.assertEqual(reply.argument, "")

    def test_a_refusal_never_quotes_a_secret_or_markup_the_model_wrote(self) -> None:
        # A game shows the refusal beside its line. R4, R6 and R7 used to
        # quote the model's key, intent or argument, which R10 and R11 never
        # read; three cases plant a secret and `[b]` there (T93's review).
        declaration, cases = load()
        for case in cases:
            reply = validator.validate(case["raw"], declaration)
            folded = reply.refusal.translate(validator.ASCII_LOWER)
            with self.subTest(case["why"]):
                self.assertNotIn("[b]", reply.refusal)
                for secret in declaration.secrets:
                    self.assertNotIn(secret.translate(validator.ASCII_LOWER), folded)

    def test_the_schemas_speech_pattern_refuses_what_r8_r9_and_r10_refuse(self) -> None:
        # The pattern asks a constraining runtime for what these rules check
        # (T116). Each case the vector refuses for its speech's length, a
        # control character or markup must be one the pattern turns away too,
        # or the schema asks for less than the validator wants.
        _, cases = load()
        speech_cases = [case for case in cases if case.get("refused") in ("R8", "R9", "R10")]
        self.assertGreaterEqual(len(speech_cases), 8)
        for case in speech_cases:
            speech = json.loads(case["raw"], strict=False)["speech"]
            with self.subTest(case["why"]):
                self.assertIsNone(re.fullmatch(validator.SPEECH_PATTERN, speech))

    def test_r9_refuses_what_unicode_calls_a_control_separator_or_format(self) -> None:
        # Controls and separators come from Unicode's own table, not from the
        # validator's ranges (T129): a control (Cc) breaks or hides something,
        # and a line or paragraph separator (Zl, Zp) is a line break. Format
        # controls come from the vector's runs, the list both validators are
        # held to (T139); the next test holds those runs to the table. Every
        # other code point is left to the other rules, and the pattern turns
        # these away too. Surrogates are not characters a speech can hold.
        format_codes = set(format_controls_of_the_vector()[1])
        refused = 0
        for code in range(0x110000):
            if 0xD800 <= code <= 0xDFFF:
                continue
            speech = f"Halt{chr(code)}there"
            is_r9 = validator.why_speech_is_wrong(speech, ()).startswith("R9")
            breaks_or_hides = (unicodedata.category(chr(code)) in ("Cc", "Zl", "Zp")
                               or code in format_codes)
            self.assertEqual(is_r9, breaks_or_hides, hex(code))
            if breaks_or_hides:
                refused += 1
                self.assertIsNone(re.fullmatch(validator.SPEECH_PATTERN, speech), hex(code))
        # 65 controls (32 C0, DEL, 32 C1), the two separators and 170 format
        # controls in 21 runs.
        self.assertEqual(refused, 67 + 170)

    def test_the_format_controls_are_the_vectors_runs_and_unicodes_cf(self) -> None:
        # The validator names its runs by hand, and so does LlmValidator; both
        # are compared to the vector's. The vector's are compared here to
        # Unicode's own Cf: exactly, on the version the vector names. On
        # another table -- CI's Python 3.12 has 15.0 -- a character a newer
        # version added is unassigned (Cn) there, so the check is weaker:
        # every Cf on this table is in the runs, and every code point in the
        # runs is Cf or still unassigned here.
        version, codes = format_controls_of_the_vector()
        runs = load_vector()["format_controls"]["runs"]
        self.assertEqual(validator.FORMAT_CONTROLS,
                         tuple((int(first, 16), int(last, 16)) for first, last in runs))
        cf = [code for code in range(0x110000) if unicodedata.category(chr(code)) == "Cf"]
        if unicodedata.unidata_version == version:
            self.assertEqual(codes, cf)
            return
        self.assertLessEqual(set(cf), set(codes))
        for code in codes:
            self.assertIn(unicodedata.category(chr(code)), ("Cf", "Cn"), hex(code))


if __name__ == "__main__":
    unittest.main()
