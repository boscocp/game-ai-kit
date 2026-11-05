# The guard's conversations, turn by turn

One file per recording in `data/talk/recordings/` (T94): `recording`, its
path from the repository's root; `turns`, each the act the validator
admitted (`intent`, `argument`) or the code it refused the reply with
(`refusal_code`, the act then `unclear`), the rule of `spec/talk/gate.json`
that fired, and trust and suspicion after it; and `outcome`, `open`,
`alarm`, `sent_away`, or `playing` when the lines ran out first.

Read by both languages: `python/tests/test_talk_vectors.py` replays each
recording through `gameaikit.talk`, and `make test-talk-vectors` also plays
it through the Godot game's own `TalkGuard`, `RecordedRuntime` and
`LlmConversation`. No model in either.

Written by `write.py` from the Python replay, then read by hand against
the rules, turn by turn: they hold the Godot game to the Python one, and a
person holds both to `gate.json`.
