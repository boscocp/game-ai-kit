"""The validator's answers, held to the vectors `ai_llm`'s LlmValidator is held to.

`spec/vectors/llm/replies.json` names, for every raw reply in it, the code
of the first rule it breaks -- or the speech, intent and argument the game
may act on. `godot/test/ai_llm/llm_vectors_runner.gd` reads the same file
through `LlmValidator`; `make test-llm-vectors` runs both halves.
"""

import json
import pathlib
import unittest

from gameaikit.llm import validator
from gameaikit.llm.replay import declaration_from

VECTOR = (pathlib.Path(__file__).resolve().parents[2]
          / "spec" / "vectors" / "llm" / "replies.json")

# Every rule the validator has. A rule with no refusing case could be deleted
# from either language with both suites green.
EVERY_CODE = {f"R{number}" for number in range(1, 12)}


def load() -> tuple[validator.Declaration, list[dict]]:
    """The vector's game and its cases."""
    data = json.loads(VECTOR.read_text(encoding="utf-8"))
    return declaration_from(data["declaration"]), data["cases"]


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


if __name__ == "__main__":
    unittest.main()
