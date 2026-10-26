# Review: wave/97-a-team-that-falls-back

T65, closed as measured. The owner picked proposals 1 and 2, then 3, and
wave 97 built and measured them: falling back weighed to cover near the
squad's point, and respawn waves. Never falling back still won 20-0, so
step 4 applied. The owner then chose to close T65 as measured, and the
three proposals were reverted. The record is in
`tasks/T65-a-coordinated-team-that-wins.md` and `docs/godot/botmatch.md`.

What stays in the code:

- the gate's counts of today's falling back and dying, printed and never
  claimed (`MatchFallBacks`);
- a guard so that a bot does not claim a hiding place over a teammate's
  claim;
- a fix for main's untranslated tactical-weights refusals, which wave 99
  had left outside `tr()`.

A fresh context reviewed PR #40 at head 415b4d0.

**Verdict: no blockers.** The code is sound. The findings were about the
docs and the PR text, plus one test, and every one was applied on the
branch.

## What the reviewer found sound

- The reviewer ran `make test-botmatch-effects` himself: exit 0, and every
  number cited in the docs was identical.
- The revert is complete: no fall-back errand, dying table or respawn wave
  is left, and `retreat_at`, `recover_at`, `fallback_metres` and
  `respawn_time` are back.
- The counting only observes. The baseline run with it reproduced wave 96
  exactly.
- The claim guard is a real fix, and its test fails without it.
- The `tactical_weights` fix is right:
  - `error` stays the English that the tests and the Python side compare;
  - `error_shown()` translates the prose and keeps the W code and the
    source untranslated;
  - `LearnedPolicy.why_unusable()` shows it.

## Findings, and what was done

1. **The PR body's "What was run" was stale.** It still said
   `check_translations_game.py` exits 1 and that the PR does not touch
   `tactical_weights.gd`.
   *Done:* the body now describes the fix commit, the suites that cover it
   and their exit-0 results, and the reviewer's own effects run.
2. **Two more hashes do not survive the squash.** `581820e` (the baseline,
   and the source of the dying table) and `c5a995a` (the reverted match)
   are branch commits, like `6523962` and `8739ed5`.
   *Done:* the task file and the bot match page describe all four as
   PR #40 branch commits that the squash drops. They say the reverted
   state is the squash-merge commit of PR #40 on main. No tag was made:
   that would need the owner's OK.
3. **"Fourteen" pull requests in STATUS.**
   *Done:* it now says fifteen, #26 to #40.
4. *Nit:* "always the head" moved with the guard too.
   *Done:* -170.9 to -187.0 is added to the bot match page and to the PR.
5. *Nit:* the task file used "option (a)" for two opposite choices.
   *Done:* the later one is now "the owner's 'close as measured' choice".
6. *Nit:* "every prediction was wrong" was too broad. Proposal 1 alone was
   never measured, and claims (a) and (b) held.
   *Done:* it now reads "every prediction that was measured was wrong", in
   the shooter AI page, STATUS and the PR body.
7. *Nit:* the no-commander comparison flipped sign with the guard.
   Everything is now 0.4 errors behind no commander, where it was 0.5
   ahead.
   *Done:* the bot match page says so and weakens what it says of the
   commander's help. It also notes that the effects gate's header numbers
   and the T51 and T68 tables predate the guard, to be refreshed at the
   next effects run.
8. *Nit:* `error_shown()` had no test of its own.
   *Done:* `learning_test.gd` has one case covering both languages:
   - under pt_BR, the prose is translated and the W6 code and the source
     are kept;
   - under en, it equals `error`.

   The locale is put back afterwards.

## Checks run after the fixes

- `make test-godot-some SUITES="test/tactical"`: 335 cases, 0 failures.
- `check_translations_game.py`: exit 0.
- `make lint-tasks lint-status`: exit 0.
- `check_links.py`, `check_doc_freshness.py`, `check_readability.py`:
  exit 0.
- `check_pr_message.py` on the new title and body: exit 0.

No match was replayed: the fixes change docs and one test, not play.
