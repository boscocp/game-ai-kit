# Review: wave/181-boss-director

PR #141, task T158. The wave adds a director that paces the boss fight's
waves through build-up, peak and relief (`BossDirector`). It also adds
three levels the person chooses (`difficulty.json`, `BossDifficulty`).
Each level sets the token pools and delays, how fast the tells are and
their minimum, and the wave and cap for each kind.

A fresh context reviewed head a01dade. **Verdict: no blocker.** There is
one finding that should be fixed (malformed level data was accepted), two
minor findings, three nits, and one note. This record was written by the
implementer from the findings the coordinator passed on. The reviewer's
own text is in the coordinator's message on the PR, not quoted here.

## What was reviewed

- The diff against T158, its decisions and the wave's changes to them,
  CLAUDE.md invariants 1, 3, 4, 6 and 13, "Readable by a person", and the
  trap about an aborted typed function.
- **The difficulty file, by planting.** Wrong shapes and wrong types were
  put in `difficulty.json`. Wrong values were put in `boss_fight.json`'s
  `director` section.
- **The director's overlay and its timing:** what `waits_for()` says
  during a heavy blow, and a summon that comes late in a peak.
- **Size:** `boss_fight.gd` is now 444 lines. The 400-line limit covers
  only `godot/addons/`.
- The "Child is not a child of this node" error in the menu suites is
  already on main, so it is not this wave's.

## Findings

1. **Should fix (confirmed).** `_why_not_one` in `boss_difficulty.gd`
   chained `.get()` calls on values it had not checked. With
   `"tokens": 5` or `"wave": [3, 2]`, the typed function aborted with a
   SCRIPT ERROR and returned "". The file was then **accepted**. The same
   chained `.get()` was in `BossFightRules.apply`.
2. **Minor (confirmed).** Values of the wrong type were converted instead
   of refused. `"delays": {"melee": "fast"}` became 0 s, and
   `"wave": {"melee": 2.9}` became 2. The rest of the kit refuses rather
   than clamps.
3. **Minor (confirmed).** The director's numbers in `boss_fight.json` were
   never checked. `wave_every: 0` sends a wave every step, and a negative
   `peak_seconds` ends every peak at once.
4. **Nit.** A summon during a peak did not restart the peak's seconds. A
   summon at 14 s into a peak was followed by a relief about 1 s later.
5. **Nit.** `waits_for()` answered "heavy" whenever a heavy blow was
   underway in build-up, even when the next wave was not due for seconds.
   The overlay then said the wrong thing.
6. **Nit.** The default for `BossDirector.relief_at` in the code was 1,
   while the data says 2.
7. **Note.** `boss_fight.gd` is 444 lines. Split it only if that is cheap.

## What was done about them

All applied on the branch, in one commit, after a rebase on main 24762663
with no conflict:

- **Finding 1.** A new `_why_not_shape` checks each level's fields before
  reading them. `tokens` and its `pools` and `delays`, `wave` and
  `wave_cap` must each be an object. One function now checks each section
  (`_why_not_section`). `BossFightRules.apply` reads every section through
  `_object()`, which turns anything that is not an object into an empty
  one, so an unchecked level cannot crash it. New planted cases in
  `test_the_file_s_other_mistakes_are_refused_by_name`: a number for
  `tokens` and a list for `wave`. Both are refused, and the refusal names
  the level. The suite output has no SCRIPT ERROR.
- **Finding 2.** `BossDifficulty.is_number(value, whole)` refuses any
  value that is not a number. Counts (pools, wave, cap) must also be
  whole numbers. Seconds, speed and minimum may be any number. New
  planted cases: `"fast"` as a delay is refused, naming `delays.melee`.
  `2.9` as a wave is refused, naming `wave.melee` and "whole".
- **Finding 3.** `BossDirector.why_not_numbers` requires `wave_every`,
  `peak_seconds` and `relief_seconds` to be numbers above 0, and
  `relief_at` to be a whole number, 0 or more. `BossFightRules.shared()`
  sets the rules' `refusal` from it, so a bad director refuses the fight
  and the refusal names the field. New planted cases: `wave_every: 0`,
  `peak_seconds: -1`, `relief_seconds: "soon"`, `relief_at: 1.5`, and a
  missing `wave_every`. The shipped numbers pass.
- **Finding 4.** A summon now re-enters the peak even from the peak
  (`_enter(PEAK, true)`). The peak's seconds start over, and the move is
  logged as a pacing event. There is a test: a summon at 14 s into a peak
  still leaves the director in the peak at 16.5 s. The docs page says so.
- **Finding 5.** `waits_for()` answers "heavy" only when a summon is
  waiting or a build-up wave is due. There is a test: during a heavy blow
  at 2 s the answer is "time"; at 8.5 s, when a wave is due, it is "heavy".
- **Finding 6.** The code default for `relief_at` is now 2.
- **Note 7.** `boss_fight.gd` is left as it is. The limit covers addons,
  and a split would move code that this wave does not otherwise change.

Re-run after the changes:

- `make test-godot-some SUITES="test/bossfight"`: 56 cases, 0 failures,
  no SCRIPT ERROR.
- Exit 0 each: `make test-demo-overlays`, `lint-readability`,
  `lint-tasks`, `lint-status`, `lint-self-naming`, `lint-godot-checked`,
  `lint-demos`, `lint-catalogue`, `lint-translations-game`, `lint-links`.
  The overlay run's SCRIPT ERROR lines are its own planted crash.
