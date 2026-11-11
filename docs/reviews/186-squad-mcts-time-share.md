# Review: wave/186-squad-mcts-time-share

PR #144, task T117. In the scene, `MctsSquad` now searches a share of
each frame: after the frame in which a decision is asked, iterations run
one at a time until `frame_share_ms` (8.0, in `rules.json`'s `search`) is
spent. Matches, the duel and the vectors still run a decision's 1,000
iterations by count.

A fresh context reviewed the PR's first head. **Verdict: no blocker.**
It found two test gaps, one decision changed without being recorded, and
two nits.

## What was reviewed

- The whole diff against the task's decisions and CLAUDE.md invariants
  1, 3, 4, 11 and 13, and the traps about `-s` scripts and timing gates.
- **Determinism, by mutation.** Plants that let the clock change how
  many iterations a decision gets all went red: the digest test, the
  same-visits test, and the Enter test. So the claim holds that only how
  soon a decision is made depends on the machine.
- **Where the share applies.** Only `SquadRoster.for_the_scene` turns it
  on, through `spread_over_frames`. `SquadMatch`, the duel and the vectors
  never do.
- **`mini(count, _left)`.** This is not dead code. It turns `UNLIMITED`
  into the budget when a match runs a decision all at once. The
  implementer's sixth plant was equivalent only on the share path. Keep
  it.
- **Authorship.** The commits and the PR body carry no trailer and no
  tooling byline.

## Findings

### Should-fix

1. **P3: nothing holds the at-least-one-iteration rule.** Removing the
   unconditional first `_search_more` in `_search_for` left every test
   green. **Fix:** a deterministic test that `_search_for(0)` adds
   exactly one unit of work.
2. **P4: nothing holds the bound on overrun.** The docs and STATUS say a
   frame overruns its share by at most one iteration, but the tests only
   bound the overrun at +250 ms. Looping 20 units between looks at the
   clock went unseen. **Fix:** a deterministic hold on the units run
   between two looks at the clock.
3. **A decision changed without being recorded.** The task said
   `make measure-squad-mcts` keeps counting, but the measure now runs on
   the share. The `rules.json` `about` note also says "a match or a test
   counts them", which is no longer true of every test. **Fix:** record
   the change and its reason in the task file and the STATUS row, and
   make the note say what runs on the share.

### Nits

4. If `frame_share_ms` is 0 or negative, the scene falls back to
   counting without saying so. If it is missing, `_frame_share_usec`
   hits a SCRIPT ERROR and returns 0. Refuse it by name if that is cheap.
5. Badly wrapped lines in `mcts_squad.gd` (9-10),
   `squad_mcts_measure.gd` (11-13), and `docs/godot/squad.md` (about
   lines 180 and 490).

## What was done about them

All five were applied on the branch in one push, after a rebase on
68cebef9 (T165) that kept every STATUS row.

- **1.** New test
  `test_a_frame_on_its_share_searches_once_even_when_the_share_is_already_spent`.
  It calls `_search_for(0)` and expects `work_done` to grow by exactly
  one. Removing the first unconditional `_search_more` turns it red.
- **2.** New test `test_a_frame_on_its_share_reads_the_clock_after_every_iteration`.
  A recording subclass, `CountsItsSteps`, writes down every
  `_search_more` count during one `_search_for` call. Every count must
  be 1, and there must be more than one call. The planted
  `_search_more(CLOCK_SHARE * 20)` turns it red.
- **3.** The task file has a new section, "What wave 186 decided". It
  says the measure runs on the share because step 4 asks it to time the
  frames a person sees. Its wins are still a counted run's, since a
  decision is its iterations whatever the frames. The section also
  records the two decisions that were not in the proposal: the first
  frame keeps its count, and at least one iteration runs per frame. The
  STATUS row says the same. All three copies of the `about` note now say
  what runs a decision at once and what spreads it on the share.
- **4.** `_frame_share_usec` refuses a missing or non-positive value
  with a `push_error` that names `search.frame_share_ms`. The scene then
  counts its frames, and the error fails any gate that runs it.
- **5.** The lines were rewrapped.

Re-run after the changes: `make test-godot-some SUITES=test/squad`,
`make test-squad-search-vectors`, the `rules.json` copies unittest,
`lint-readability`, `lint-tasks`, `lint-status`, `lint-godot-checked`
and `lint-self-naming`. Exit codes are in the PR body.
