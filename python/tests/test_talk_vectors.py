"""The guard's recorded conversations in `spec/vectors/talk/`, against `gameaikit.talk`.

Each vector names a recording a local model really made and states, turn
by turn, the act the validator admitted (or its refusal), the rule that
fired, trust and suspicion, and the outcome. The Python replay must
reproduce every one; the other half is `make test-talk-vectors`, the same
files through the Godot game's own path.
"""

import json
import pathlib
import unittest

from gameaikit.talk import replay

REPO = pathlib.Path(__file__).resolve().parents[2]
VECTORS = REPO / "spec" / "vectors" / "talk"
RECORDINGS = REPO / "data" / "talk" / "recordings"
# T94 asks for five recorded conversations at least; each is recorded in
# both languages.
FEWEST_CONVERSATIONS = 5


class TheVectors(unittest.TestCase):
    def test_there_are_enough_conversations_in_both_languages(self) -> None:
        names = [path.name for path in VECTORS.glob("*.json")]
        for language in ("en", "pt_BR"):
            self.assertGreaterEqual(sum(name.endswith(f".{language}.json") for name in names),
                                    FEWEST_CONVERSATIONS, language)

    def test_every_recording_has_its_vector(self) -> None:
        self.assertEqual(sorted(path.name for path in RECORDINGS.glob("*.json")),
                         sorted(path.name for path in VECTORS.glob("*.json")))

    def test_the_recordings_include_replies_the_validator_refused(self) -> None:
        codes = {turn["refusal_code"] for path in VECTORS.glob("*.json")
                 for turn in json.loads(path.read_text(encoding="utf-8"))["turns"]}
        self.assertTrue(codes - {""}, "no recorded reply was refused")

    def test_every_turn_is_the_vectors(self) -> None:
        for path in sorted(VECTORS.glob("*.json")):
            vector = json.loads(path.read_text(encoding="utf-8"))
            recording = json.loads((REPO / vector["recording"]).read_text(encoding="utf-8"))
            found = replay.vector_of(replay.replay(recording))
            self.assertEqual(len(found["turns"]), len(vector["turns"]), path.name)
            for index, (got, wanted) in enumerate(zip(found["turns"], vector["turns"])):
                self.assertEqual(got, wanted, f"{path.name}, turn {index + 1}")
            self.assertEqual(found["outcome"], vector["outcome"], path.name)


if __name__ == "__main__":
    unittest.main()
