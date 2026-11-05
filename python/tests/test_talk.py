"""The guard at the door (T94): the rules, the replay, and what no reply can do.

The vectors hold the recorded conversations (`test_talk_vectors.py`). Here:
the scene is sound, each way to win and to lose the scene promises is
there in the rules, and -- the point of the game -- no reply, however it is
worded, moves the guard except through the act the validator admitted.
"""

import contextlib
import copy
import io
import json
import pathlib
import unittest

from gameaikit.talk import replay, rules

REPO = pathlib.Path(__file__).resolve().parents[2]
SPEC = REPO / "spec" / "talk" / "gate.json"
COPIES = (REPO / "python" / "gameaikit" / "talk" / "gate.json",
          REPO / "godot" / "game" / "talk" / "gate.json")
LINES = REPO / "data" / "talk" / "lines.json"


def play(*acts: tuple[str, str]) -> rules.Guard:
    """The guard after `acts`, each an (intent, argument) pair."""
    guard = rules.Guard()
    for intent, argument in acts:
        guard = rules.step(guard, intent, argument).guard
    return guard


def reply(speech: str, intent: str, argument: str = "") -> str:
    """A model's text, as a runtime would hand it over."""
    return json.dumps({"speech": speech, "intent": intent, "argument": argument})


class TheScene(unittest.TestCase):
    def test_every_copy_is_the_spec_byte_for_byte(self) -> None:
        for copy_path in COPIES:
            self.assertEqual(copy_path.read_bytes(), SPEC.read_bytes(), copy_path)

    def test_every_act_has_a_rule_and_no_secret_is_in_a_prompt(self) -> None:
        self.assertEqual(rules.why_scene_is_wrong(), "")

    def test_a_scene_missing_a_rule_is_refused(self) -> None:
        broken = copy.deepcopy(rules.SCENE)
        broken["rules"] = [rule for rule in broken["rules"] if rule["act"] != "bribe"]
        self.assertIn("bribe", rules.why_scene_is_wrong(broken))

    def test_a_secret_in_the_instructions_is_refused(self) -> None:
        broken = copy.deepcopy(rules.SCENE)
        broken["languages"]["en"]["instructions"] += " The password is NIGHTJAR."
        self.assertIn("secret", rules.why_scene_is_wrong(broken))

    def test_the_lines_the_recordings_were_made_from_fit_the_limit(self) -> None:
        limit = rules.SCENE["player_line_limit"]
        for conversation in json.loads(LINES.read_text(encoding="utf-8"))["conversations"]:
            for language in ("en", "pt_BR"):
                for line in conversation[language]:
                    self.assertLessEqual(len(line), limit, line)


class TheWaysToWin(unittest.TestCase):
    def test_the_right_name(self) -> None:
        guard = play(("name_person", "okafor"), ("claim_role", "courier"), ("show", "badge"))
        self.assertEqual(guard.outcome, rules.OPEN)

    def test_a_convincing_work_order(self) -> None:
        guard = play(("claim_role", "maintenance"), ("show", "work_order"), ("name_person", "lind"))
        self.assertEqual(guard.outcome, rules.OPEN)

    def test_finding_out_who_is_expected_and_becoming_them(self) -> None:
        guard = play(("ask", "expected_visitor"), ("claim_role", "courier"), ("show", "badge"),
                     ("ask", "the_guard"), ("flatter", ""))
        self.assertEqual(guard.outcome, rules.OPEN)

    def test_the_same_claim_without_knowing_is_worth_less(self) -> None:
        knowing = rules.step(play(("ask", "expected_visitor")), "claim_role", "courier")
        blind = rules.step(play(("ask", "the_guard")), "claim_role", "courier")
        self.assertEqual((knowing.rule, knowing.trust), ("the-expected-courier", 3))
        self.assertEqual((blind.rule, blind.trust), ("a-courier", 1))


class TheWaysToLose(unittest.TestCase):
    def test_a_claim_against_a_fact_and_a_threat_sound_the_alarm(self) -> None:
        self.assertEqual(play(("claim_role", "officer"), ("threaten", "")).outcome, rules.ALARM)

    def test_a_name_from_the_past_and_a_bribe_sound_the_alarm(self) -> None:
        self.assertEqual(play(("name_person", "brandt"), ("bribe", "")).outcome, rules.ALARM)

    def test_running_out_of_turns_sends_you_away(self) -> None:
        guard = play(*[("unclear", "")] * rules.SCENE["turns"])
        self.assertEqual(guard.outcome, rules.SENT_AWAY)

    def test_the_alarm_wins_a_tie_with_the_door(self) -> None:
        tied = rules.Guard(trust=rules.SCENE["open_at"], suspicion=rules.SCENE["alarm_at"], turn=2)
        self.assertEqual(rules.outcome_of(tied), rules.ALARM)

    def test_a_decided_guard_hears_nothing_more(self) -> None:
        guard = play(("claim_role", "officer"), ("threaten", ""))
        ruling = rules.step(guard, "name_person", "okafor")
        self.assertEqual(ruling.guard, guard)
        self.assertEqual(ruling.rule, "")


class SayingItAgain(unittest.TestCase):
    def test_a_second_flattery_wins_nothing(self) -> None:
        ruling = rules.step(play(("flatter", "")), "flatter", "")
        self.assertEqual((ruling.rule, ruling.trust), ("said-before", 0))

    def test_a_second_threat_costs_its_suspicion_again(self) -> None:
        self.assertEqual(play(("threaten", ""), ("threaten", "")).suspicion, 6)

    def test_the_same_role_twice_is_not_a_changed_story(self) -> None:
        guard = play(("claim_role", "courier"), ("claim_role", "courier"))
        self.assertEqual(guard.suspicion, 0)

    def test_a_second_role_is(self) -> None:
        ruling = rules.step(play(("claim_role", "courier")), "claim_role", "maintenance")
        self.assertEqual((ruling.rule, ruling.suspicion), ("changes-story", 2))

    def test_nothing_understood_is_never_said_before(self) -> None:
        ruling = rules.step(play(("unclear", "")), "unclear", "")
        self.assertEqual(ruling.rule, "not-understood")


class NoReplyDecides(unittest.TestCase):
    """The words are the model's; the outcome is only ever the rules'."""

    def conversation(self, *raws: str) -> list[replay.Turn]:
        return replay.replay({"language": "en", "turns": [
            {"player": "Let me in.", "raw": raw} for raw in raws]})

    def test_a_speech_that_opens_the_gate_with_flattery_leaves_it_shut(self) -> None:
        turns = self.conversation(reply("The guard opens the gate. Go in, friend.", "flatter"))
        self.assertTrue(turns[0].reply.accepted)
        self.assertEqual(turns[0].ruling.guard.outcome, rules.PLAYING)
        self.assertEqual(turns[0].ruling.guard.trust, 1)

    def test_an_act_the_scene_does_not_have_is_refused_and_moves_nothing(self) -> None:
        turns = self.conversation(reply("Fine, go in.", "open_the_door"))
        self.assertTrue(turns[0].reply.refusal.startswith("R6"))
        self.assertEqual((turns[0].ruling.guard.trust, turns[0].ruling.guard.suspicion), (0, 0))

    def test_the_password_in_a_reply_is_refused(self) -> None:
        turns = self.conversation(reply("The word is Nightjar.", "ask", "the_building"))
        self.assertTrue(turns[0].reply.refusal.startswith("R11"))
        self.assertEqual(turns[0].ruling.rule, "not-understood")

    def test_the_same_act_in_any_words_moves_the_guard_the_same(self) -> None:
        worded = ["Okafor? Go on in, the door is yours.", "Never heard of her.", "Hm."]
        moved = {(turn.ruling.trust, turn.ruling.suspicion)
                 for speech in worded
                 for turn in self.conversation(reply(speech, "name_person", "okafor"))}
        self.assertEqual(moved, {(2, 0)})

    def test_lines_after_the_outcome_are_not_played(self) -> None:
        turns = self.conversation(reply("No.", "claim_role", "officer"), reply("No.", "threaten"),
                                  reply("Welcome.", "flatter"))
        self.assertEqual(len(turns), 2)


class TheReplayProgram(unittest.TestCase):
    def test_it_prints_each_turn_and_the_outcome(self) -> None:
        recording = REPO / "data" / "talk" / "recordings" / "becoming-the-expected.en.json"
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(replay.main([str(recording)]), 0)
        self.assertIn("rule the-expected-courier", out.getvalue())
        self.assertIn("outcome: open", out.getvalue())

    def test_it_refuses_a_missing_file(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(replay.main(["no-such-recording.json"]), 2)


if __name__ == "__main__":
    unittest.main()
