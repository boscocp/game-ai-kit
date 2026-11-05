# Review: wave/126-talk-your-way-past-the-guard

T94: talk your way past the guard. In this text game a local language
model reads each line the player types as one of the scene's declared acts
and voices Bram, the night guard. The rules in `spec/talk/gate.json` move
trust and suspicion and decide whether the door opens. The PR also changes
the shared `ai_llm` addon. `json_schema()` becomes an `anyOf` with one
shape per intent, in both languages, and there is a new `RecordingRuntime`.

A fresh context reviewed PR #68 at head e818d9f, in a detached checkout in
a throwaway worktree. It read the code and planted faults one at a time,
restoring each one. Nothing was pushed, committed or commented.

**Verdict: changes requested, one blocker.** The validator admits a reply
that the talk rules have no rule for. When that happens the Python twin
crashes and the GDScript game spends a turn under an empty rule, so the two
disagree on input that has already passed validation. There are also two
should-fix findings, four nits and three items for the owner.

## What was reviewed

The diff against main:

- `ai_llm`: `llm_validator.gd`, `recording_runtime.gd`, `validator.py`, the
  description in `reply.schema.json`, and their tests.
- `godot/game/talk/` (all six scripts), `python/gameaikit/talk/` (`rules.py`,
  `replay.py`), `gate.json` and its two copies, `test_talk*.py`,
  `talk_test.gd`, `talk_vectors_runner.gd`, `record_talk.gd`.
- The Makefile targets, `modules/talk.json`, the task file and the PR body.

For context the review also read `llm_conversation.gd` (`system_prompt`,
`say`), `llm_validator.gd`'s `instructions()` and R7, `http_runtime.gd`'s
request body, and `check_llm_validated.py`'s V0-V3.

What holds:

- **No model output reaches an action without the validator.** Every path
  goes `runtime -> LlmConversation._on_replied -> LlmValidator.validate ->
  answered(LlmReply) -> TalkGuard._on_answered -> TalkRules.step`, and
  `step` sees only `intent` and `argument`. The speech is never parsed.
  When the guard decides, the speech is replaced by the scene's ending
  (`talk_guard.gd:118-119`). `TalkBook` loads `raw` strings from the
  recording files and hands them, unread, to a `RecordedRuntime`, so they
  too pass through the validator. `check_llm_validated.py` exits 0.
- **The password never reaches a prompt.** The system prompt is the
  language's `instructions` plus `LlmValidator.instructions()`, which lists
  the intents and their arguments. `secrets` appears in neither, and
  `why_scene_is_wrong` (Python) refuses a scene whose instructions contain
  a secret. See owner item 1 about the awaited name.
- **Nothing waits on the frame.** `talk.gd` redraws in `_process`, and has
  no `while` loop and no poll. `TalkGuard.say` returns at once. The only
  `await` loop is in the headless vector runner, and it yields each frame.
  `RecordingRuntime.save` writes one small file once a conversation is
  over. `test_the_answer_comes_frames_later_and_the_frame_never_waits`
  holds this.
- **The twins agree on every act in `every_act()`.** The order of the
  rules, `if_any`, `said_before` with its `unclear` exception, and the tie
  that goes to the alarm are written the same way in `rules.py` and
  `talk_rules.gd`. `json_schema` matches too: the names are sorted, the
  arguments keep their declared order, and `[""]` stands for an intent
  with no arguments.
- **The vectors bind both twins.** The Godot runner compares intent,
  argument, refusal code, rule, trust and suspicion on every turn, plus the
  outcome, and the Python test compares the same vector object field for
  field.
- **Every acceptance criterion is a command.** The task's ten lines are
  all commands with exit codes. The rest is under `## Manual check`.
- `check_demos.py`, `check_readability.py` and `check_modules.py` exit 0,
  and so does the baseline `make test-godot-some SUITES="test/talk test/ai_llm"`
  (42 cases, no `SCRIPT ERROR`).

## Mutation round

Each fault below was planted alone. After each one the review ran only the
command named, then ran `git checkout` on the file. After the Python plant
it also cleared `__pycache__`.

| plant | where | caught by |
|---|---|---|
| `_on_failed` / `_on_refused` no longer count `_missed` | `recording_runtime.gd:79,84` | **nothing**: `test/ai_llm` green (29 cases) |
| `_was_said` drops `other != act` (one role twice becomes a changed story) | `talk_rules.gd:286` | `test/talk` (1 failure); **not** `make test-talk-vectors` |
| the ending no longer replaces the model's last line | `talk_guard.gd:118` | `test_the_last_line_is_the_scenes_never_the_models` |
| `said_before` no longer zeroes trust (GDScript) | `talk_rules.gd:215` | `make test-talk-vectors` (1 failure) |
| `said_before` no longer zeroes trust (Python) | `rules.py` `step` | `test_talk*.py` (2 failures) |
| a reply `{"intent": "claim_role", "argument": ""}`, which the validator admits | probe, not a code change | **Python: KeyError**; GDScript: rule `""`, nothing moved |

## Findings

1. **Blocker: an act the validator admits has no rule, and the twins split
   on it.** In both languages the validator accepts an empty argument for
   any intent (R7 refuses only an argument that is "not empty and not one
   of its intent's values", `llm_validator.gd:24`). Its own `instructions()`
   tells the model "argument: one of its values, or empty"
   (`llm_validator.gd:234`). So `claim_role`, `show`, `name_person` or `ask`
   with `""` is an accepted act, spelled with the bare intent. No rule fits
   it unless an earlier `claim_role` makes `changes-story` fit.
   - Python: `rules.rule_for` raises `KeyError` (`rules.py:84`). The
     replay CLI exits 2 with "cannot play" on a recording a model really
     could produce.
   - GDScript: `TalkRules.rule_for` returns `{}` (`talk_rules.gd:190`). The
     turn is spent with rule `""`, and the reasoning panel prints "rule :".
     That is a gap in invariant 13 as well.
   - Both twins claim this cannot happen: "`why_scene_is_wrong` refuses a
     scene where an act the guard understands has no rule, so a game never
     meets one" (`rules.py:78-79`, `talk_rules.gd:183-184`). But
     `every_act()` (`rules.py:142`, `talk_rules.gd:271`) lists a bare
     intent only for intents that take no arguments.

   The anyOf schema hides this from a server that constrains its output.
   It is reachable through any runtime that does not, including recorded
   files. *Reproduce:* `validate('{"speech": "Hm.", "intent": "claim_role",
   "argument": ""}', rules.declaration("en"))` is accepted, and then
   `rules.step(rules.Guard(), "claim_role", "")` raises KeyError. The same
   holds for `show`, `name_person` and `ask`.
   *Fix (recommended):* let `every_act()` also yield the bare intent for
   every intent, so the existing scene check fails, then add one bare-intent
   rule per argument-taking intent to `gate.json`, for example "a role, but
   not which" with suspicion 1. Add a Python test and a gdUnit test with an
   empty argument. Two alternatives, both weaker:
   - Make `rule_for` fall back to `not-understood` in both twins.
   - Change R7 in `ai_llm` to refuse an empty argument for an intent that
     takes arguments. This touches T92's vectors and every game.

2. **Should-fix: nothing tests that `RecordingRuntime` refuses to save a
   recording with an unanswered turn.** `test_a_turn_with_no_text_is_never_saved`
   (`recording_runtime_test.gd:36-45`) has only the failed turn, so
   `_turns.is_empty()` already returns `ERR_INVALID_DATA` and `_missed` is
   never tested. With both `_missed += 1` lines removed, `test/ai_llm`
   stays green. Without the check, a live recording with one failed turn
   would be saved without that player's line, and it would then replay as
   a conversation that never happened.
   *Fix:* answer one turn, fail the next (a `RecordedRuntime` with one
   text and two lines said), and assert `ERR_INVALID_DATA` and no file.

3. **Should-fix: `json_schema()`'s doc comment (both twins) no longer says
   it disagrees with `instructions()`.** The schema now offers no empty
   argument for an intent that takes one. The prompt still says "or
   empty", and the validator still accepts it. These are three statements
   about one reply, and finding 1 comes from the gap between them. Either
   the prompt line changes ("argument: one of its values; empty when the
   act has none"), or the doc comment says outright that the schema is
   stricter than the validator and why. This is in the shared addon, so
   the owner should decide it (owner item 2).

4. **Nit: the vectors do not bind `_was_said`'s "other than this act".**
   With that clause removed from `talk_rules.gd:286`, the vectors stay
   green and only `talk_test.gd` catches it. The PR body says so (two
   GDScript mutants were caught only by gdUnit). One recorded conversation
   that claims the same role twice would put this rule in the cross-twin
   vectors.

5. **Nit: the GDScript `why_scene_is_wrong` (`talk_rules.gd:261-267`)
   checks only that every act has a rule.** The Python twin also refuses a
   rule that names a non-act and a secret in the instructions
   (`rules.py:126-134`). The byte-for-byte copy test makes this safe
   today, but the doc comment ("as `gameaikit.talk` checks it") claims
   parity it does not have.

6. **Nit: `TalkBook`'s header says "this file never reads it"
   (`talk_book.gd:276`) while it loads `turn["raw"]` into `texts`
   (`talk_book.gd:336-338`).** It only forwards the text, which is fine
   under V2. The sentence should say "never interprets it", or something
   like it, so a reader does not wonder why `RecordingRuntime` exists "because no game
   may read" that same text.

7. **Nit: the PR body says `test_talk*.py` has 31 tests.** The command in
   the task runs 30 at this head.

## For the owner

1. **The awaited name is in the prompt, but its role is not.** "okafor"
   is one of `name_person`'s four values, so it appears in
   `LlmValidator.instructions()` and in the anyOf schema. The prompt does
   not say that Okafor is the one the guard is waiting for. The scene's
   `about` and the PR body say the name "is only in the rules". More
   exactly, *that it is the awaited one* is only in the rules. The reviewer
   finds the design sound and the wording a little strong.
   *Recommended:* reword `about` and the PR body.
2. **A root-level `anyOf` in a shared addon.** It is measured on the pinned
   llama.cpp server and helps there. `HttpRuntime` sends it with
   `"strict": true`, and some OpenAI-compatible servers require a strict
   schema's root to be an object. `ai_llm` targets the local server, so
   this is acceptable today.
   *Recommended:* ratify (PR decision 3), and add one line in
   `http_runtime.gd` or `docs/godot/talk.md` naming the server it was
   measured on. Decide finding 3 at the same time.
3. **PR decisions 1, 2 and 4-12.** The reviewer agrees with the
   recommendations. On decision 5 (recordings kept as recorded), the menu
   branch that wins where no single recording won is held by
   `test_the_menu_branches_into_a_win_no_single_recording_had`, so it is
   not an accident of file order.

## What was run

- Setup: `make worktree-setup`. `gh pr checkout 68` refused, because
  another worktree has the branch, so the review fetched `pull/68/head` and
  checked it out detached at e818d9f.
- `./scripts/godot --headless --path godot --import`, then
  `make test-godot-some SUITES="test/talk test/ai_llm"` (42 cases, 0
  failures, no `SCRIPT ERROR`).
- `python3 -m unittest discover -s python/tests -t python -p "test_talk*.py"`
  (30, OK).
- `check_llm_validated.py`, `check_demos.py`, `check_readability.py` and
  `check_modules.py` all exit 0.
- The plants above, against `test/ai_llm`, `test/talk`,
  `make test-talk-vectors` or `test_talk*.py`. After each one the
  worktree's `git status` was clean.
- A scratch probe for finding 1:
  `review-68/probe.py` runs the validator and then `rules.step` on an empty
  argument for each of the four intents. `review-68/empty-claim.json`
  through `python3 -m gameaikit.talk.replay` exits 2.
- Whole suites the author already ran were not rerun.

## What was done about them

All seven findings were handled on the branch; nit 4 by a test, not a vector.

1. **Blocker, applied.** `every_act()` now lists each intent alone as well
   as with each argument, in both twins (23 acts), and `gate.json` has a
   rule for each bare act: a role nobody can place and a name nobody knows
   (suspicion +1), something shown and a stray question (nothing). A rule
   names "any act of this intent with an argument" as `intent:*`, so the
   second-role rule no longer catches a bare claim. Tests in both twins run
   the four bare replies through the validator and the rules; on the old
   code Python raised KeyError and GDScript ruled under "". The reviewer's
   probe now prints a rule for each.
2. **Should-fix, applied.** `recording_runtime_test.gd` gains an answered
   turn followed by an unanswered one, which must not save. Checked: with
   both `_missed += 1` lines deleted, two cases fail.
3. **Should-fix, applied, with an owner decision.** The schema now offers
   the empty argument to every intent, as the prompt and the validator
   (R7) already allow, in both languages: the least change to T92's
   contract. Measured again on the 30 bake-off lines (three rounds a
   language): still no R7; valid 25/28/28 (en) and 28/29/30 (pt-BR); act
   and argument right 14/17/18 and 16/15/16. The model used the empty
   argument on 0-3 lines a round. `docs/godot/talk.md` has both rows.
   Tightening the validator instead (no empty argument for an intent that
   takes values) is left to the owner, in the PR body.
4. **Nit, applied as tests.** The vectors come from real recordings, and a
   hand-written one would enter the dialogue menu, so the "other than this
   act" clause is held by the unit tests in both twins (the same role twice
   is not a second role; a bare claim then a role is not either). The
   mutation round already showed the gdUnit suite catches its removal.
5. **Nit, applied.** GDScript's `why_scene_is_wrong` runs the same three
   checks as Python's: an act with no rule, a rule naming no act, a secret
   in the instructions.
6. **Nit, applied.** `talk_book.gd` says it loads the text and passes it
   on, never looking inside it.
7. **Nit, applied.** The PR body's counts are the run's.

The PR body also now says Okafor is one of the four names in the prompt
and the schema, and only that she is the awaited name is in the rules; and
that the root `anyOf` under `strict: true` was measured on the pinned
llama.cpp server only.
