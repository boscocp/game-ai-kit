# Review: wave/127-the-rts-human-side

T55: the RTS's human side. `RtsHumanClock` wraps any `GakRtsController`
with a reaction delay (the enemy as it stood that long ago, own state
current) and a cap on commands in a window. `RtsClockMeasure` reads the
knob values from a person's recordings in `data/rts/` (`make record-rts`),
with AlphaStar's 350 ms and 22 in 5 s as stand-ins until there are any.
`RtsRoster` and `test/league/rts_league.gd` put T25's league on the RTS
board (`make test-rts-league`, in `make check`), and `RtsMeter` draws each
computer side's share of the frame (M in the demo).

A fresh context reviewed PR #70 at head 292a6d5 in a throwaway worktree.
It planted faults one at a time, ran only the narrow suite or a one-match
scratch script (kept outside the tree), and restored each plant. Nothing
was pushed, committed or commented.

**Verdict: changes requested, one blocker.** Turning K on after the owner
follows the PR's own recommendation 1 (record a match) freezes the demo:
the header replays every recording on every refreshed frame. Besides the
blocker there are three should-fix findings, four nits and five items for
the owner. The cap is enforced and the gate catches a broken cap. The
"hands nothing over" check is weaker than the PR says: it checks enemy
ids, not what the side sees of them.

## What was reviewed

The diff against main: `rts_human_clock.gd`, `rts_clock_measure.gd`,
`rts_meter.gd`, the hunks in `rts.gd`, `rts.tscn` and `rts_levels.gd`,
`rts_roster.gd`, `test/league/rts_league.gd`,
`test/rts/rts_human_clock_test.gd`, the Makefile hunks,
`modules/league.json`, `rts.csv`, the two concept pages and the task file.
The review also read `RtsMatch` (`_decide`, `give`, `recording`),
`RtsSnapshot.of` and `_frozen`, and `RtsOrders` (`_idle`, `_attack`,
`_strike_back`).

What holds, measured:

- **The cap is enforced.** With `_given_at.size() <= most_actions` at
  `rts_human_clock.gd:160`, one tight-cap match against the queues gives
  3 commands in 5 s, and `hands_over` refuses it ("3 commands in 5 s, over
  the cap of 2"). `test_the_cap_holds_in_every_window` fails as well. The
  window arithmetic in `_let_through` and in `RtsClockMeasure.busiest`
  agrees (`> now - window` and `>= window`).
- **Decision 4 is what the code does.** `RtsRoster.knobs()` pairs "tight
  cap" (2 in 5 s) with the commander. `hands_over` runs on every clocked
  side, so the cap claim is held at 2, where it binds (1060 held and 441
  dropped in one match). The 22 cap is only printed.
- **K off leaves the AI unchanged.** `_clocked` returns the side itself,
  `_keep_if_over` returns at once without `--record`, and the
  `RtsMatch`/`RtsSnapshot` addons are untouched. The one visible change
  with K off is the meter, which is drawn by default (nit 3).
- `check_readability.py`, `check_no_training.py`, `check_modules.py` and
  `check_translations_game.py` exit 0. Every new public function has a
  doc comment that says why. No function is over 40 lines, and no addon
  file changed.

## Mutation round

| plant | where | caught by |
|---|---|---|
| cap off by one (`<=` for `<`) | `rts_human_clock.gd:160` | `hands_over` on one tight-cap match; `test_the_cap_holds_in_every_window` |
| enemies known at `then` handed at their **current** position and health | `rts_human_clock.gd:132-135` | **nothing**: `hands_over` green on two late matches; all 13 cases of `rts_human_clock_test.gd` green |

The second plant is a real gift. On dice 0 the late side against the
queues lost unplanted (score 0.0, 66906 ticks) and won with the plant
(score 1.0, 9762 ticks). `costs_strength` would not see it either, because
it only asks that the late side score no more than the plain commander,
who won all four matches.

## Findings

1. **Blocker: K freezes the demo once there is a recording**
   (`rts.gd:493-499`, `rts.gd:160-161`). `_clock_text` calls
   `RtsHumanClock.knob_values()` on every `_refresh`, which runs on every
   physics frame that steps the match. `knob_values()` calls
   `RtsClockMeasure.measured_from`, which replays every recording in
   `data/rts/` tick by tick. *Measured:* one five-minute recording costs
   6910 ms per call (scratch `measure_cost.gd`). So with one recording and
   K on, each frame takes about 7 s. `restart()` pays it twice more
   (`_clocked` for each side). Today `data/rts/` is empty, so nothing
   shows, but recommendation 1 asks the owner to fill it. This also breaks
   invariant 7's spirit (nothing blocks a frame), even though no LLM is
   involved.
   *Fix:* measure once. Either read the values when the scene opens and
   keep them in a field, or (better, see owner item 1) have a make target
   measure the recordings offline and write a small values file that the
   game reads.
2. **Should-fix: "no enemy reaches the side early" checks ids, not what
   is seen** (`rts_league.gd:340-350`, `shown_early`, and
   `test/rts/rts_human_clock_test.gd`). The check asks only whether each
   enemy id was in some world view at least `delay` ticks earlier. A
   clock that hands the current position and health of an enemy it saw
   earlier passes. See the second plant: green on the gate's check and on
   the unit suite, and it turned a loss into a win. This is the claim
   decision 5 rests on, so the substitution is weaker than the wording it
   replaces.
   *Fix:* record each world view's enemies whole (id, position, health,
   complete), and require that the enemy set handed at a decision equals
   the set of one world view at or before `tick - delay`. `_late` already
   copies one snapshot's enemies, so the exact check is cheap. Add a
   planted case (current position for an old id) to `_planted_handing`,
   and a unit case on `_late` that asserts the position comes from `then`.
3. **Should-fix: the side's own units still carry current enemy ids**
   (`rts_human_clock.gd:129-131`, through `RtsSnapshot._frozen`'s
   `target`). Own units are handed as they are now, and a fighter that
   auto-acquires (`RtsOrders._idle`) or strikes back has `order = attack`
   and `target` = the enemy's id now. *Measured* (scratch
   `own_target.gd`, late commander against the queues): on dice 0, 25 of
   2231 decisions held an own unit attacking an enemy that the late view
   did not show (24 distinct ids). On dice 1 there were none. Own health
   falling is the same channel without an id. The gate cannot see this
   channel, because `Spy` reads only `view.enemies()`. Decision 2 accepts
   current own state, but the class header says the enemy arrives with
   "nothing seen since", and an id in `target` is something seen since.
   *Fix:* in `_late`, blank an own unit's `target` (and leave its order
   attacking) when that id is not among the late enemies. Or say in the
   header and in decision 2 that an own unit's fight is seen at once, and
   make `shown_early` read own targets too, so that the gate states the
   real boundary.
4. **Should-fix: every change to `rts`, `ai_rts_core` or `ai_planning`
   now pays for the RTS league** (`modules/league.json`). `affected.py
   --explain` for one path:
   - `godot/game/rts/squad.gd` selects `ai_planning, league, menu, rts`,
     with `test-rts-league` among the targets;
   - an `ai_planning` path selects eight modules, `test-rts-league`
     included.

   The gate took about 11 minutes under load. Alone it took
   423 s, about 7 minutes, at load average 3.7 (see "What was run"). That cost is now paid by every RTS or
   planning wave.
   *Fix (recommended):* keep `test-rts-league` in `make check`, which
   runs on main and before a release, and keep the claims that have to
   bite on every RTS change in a fast gate. That means the
   `hands_over` / `shown_early` / planted cases on one or two matches,
   and the unit suite, which already runs under `test/rts`. Alternatively,
   run it at `SEEDS=1` in the module gate and at 2 in `make check`.

## Nits

1. `hands_over`'s "no command it did not give" is a count
   (`rts_league.gd:330`, `given.size() > produced`). A clock that swapped
   one command for another, or sent a dropped command in place of a held
   one, passes. Comparing the commands as `to_dict()` multisets would make
   it exact. There was no plant for this one.
2. The "human clock" team is "late" plus a cap that never binds (22 in
   5 s; busiest 12 in the PR's table). As a knob pair it repeats "late",
   and its strength line is the same, +26. It is worth a line in the
   roster's doc comment, or the team could carry the tight cap instead.
3. With K off, the meter is now drawn by default (`rts.tscn` has no
   `visible = false`). That is the one visible change to the old demo. If
   that is intended, say so in the header comment. Otherwise start it
   hidden.
4. `RtsMeter._draw` prints `own_microseconds` before it measures the
   current draw (`rts_meter.gd:67-70`), so the figure is the previous
   frame's. That is fine, but the doc says "times its own drawing", so add
   "the previous one".

## For the owner

1. **Invariant 6 and the measured knobs.** `RtsClockMeasure.measured_from`
   reads saved recordings at game time and derives two parameters from
   them, a median and a maximum. That is estimation, not learning, and
   `check_no_training.py` does not flag it. Still, it is game-time fitting
   from saved data, and ADR 0016's exceptions say "never saved". The
   reviewer recommends treating it like the weights: a make target
   measures `data/rts/` and writes the values to a committed file, and
   the game only reads them. That also closes the blocker.
2. **Decision 5.** The reviewer agrees with the reasoning: counts compared
   across matches that diverge measure play, not gifts. But it is sound
   only if the three exact checks are complete, and today the first is
   id-level (finding 2) and blind to own-unit targets (finding 3).
   *Recommended:* ratify once findings 2 and 3 are applied. Until then,
   the departure weakens the guarantee.
3. **Decision 6 and the module cost.** See finding 4.
4. **Decisions 2, 3 and 7.** Decision 2, current own state, is reasonable,
   with finding 3's caveat. For decision 3, whole decisions are fine for a
   stand-in, since 350 ms is served as 500 ms. For decision 7, the
   reaction proxy reads more than a second even for the queues (a replay
   of a queue match measured 1100 ms), so the "reaction" column says
   little until there are recordings.
5. **Invariant 13.** The clocked side's thinking overlay is the inner
   commander's, so the person never sees that the clocked side is
   reacting to a stale enemy. A ghost of the late view, the enemies where
   the clocked side believes them, would show the decision. A follow-up,
   not this PR.

## What was run

- `make worktree-setup`, then a detached checkout of
  `292a6d53f2b7992316b83f8c404bd71645790e8b`.
- `make test-godot-some SUITES=test/rts/rts_human_clock_test.gd`: 13
  cases, green unplanted. Under the cap plant it fails at
  `test_the_cap_holds_in_every_window`. Under the position-leak plant it
  stays green.
- Scratch scripts outside the tree, run with `./scripts/godot --headless
  --path godot -s <abs path>`:
  - `one.gd`: one roster team against the queues, then `hands_over`;
  - `own_target.gd`: own-unit targets the late view hides;
  - `measure_cost.gd`: the cost of `measured_from` on one five-minute
    recording.

  None printed `SCRIPT ERROR`.
- `affected.py --paths <file> --explain/--targets` for one `rts` path and
  one `ai_planning` path.
- `check_readability.py`, `check_no_training.py`, `check_modules.py` and
  `check_translations_game.py` all exit 0.
- The gate script alone, once (`rts_league.gd -- 2`): exit 0, "0 failure(s)", 423 s wall at load average 3.7, with no `SCRIPT ERROR`. It matches the PR's table (late 2.0/4.0, tight cap 0.0/4.0, capped changed 0).
- Each plant was restored with `git checkout`. `git status` is clean.

## What was done about them

All four findings and the four nits were applied on the branch.

1. **Blocker, applied as recommended.** The game no longer measures.
   `make measure-rts-clock` (`test/rts/measure_clock.gd`) replays the
   recordings in `data/rts/` and writes the two values to
   `godot/game/rts/clock_reference.json`, to be committed. It exits 2 with
   a sentence when there is no recording. `RtsHumanClock.knob_values()`
   only reads that file, once, and gives the stand-in when the file is
   missing or incomplete. `RtsClockMeasure.measurements` counts every
   measurement. `test_the_game_reads_the_clocks_values_and_never_measures_them`
   mounts the scene, turns K on, steps it, and holds that count still.
   This also settles owner item 1: nothing is derived from saved play at
   game time.
2. **Should-fix 2, applied.** The audit moved to
   `test/league/rts_clock_audit.gd`. At each decision, the enemy handed on
   must equal the enemy of the newest view the match showed at least the
   delay before. Every field is compared, as text, so an enemy handed at
   its current place is refused. The reviewer's plant (known enemies at
   their current position) now fails `make test-rts-clock-limits` on its
   first match ("at tick 4500 the enemy handed on was not the enemy the
   world showed 21 ticks before"). `rts_clock_audit.gd`'s `planted()`
   refuses the same gift before any match is judged.
3. **Should-fix 3, applied.** `RtsHumanClock._late` forgets an own unit's
   target (0) when it names an enemy the late view does not show.
   `test_an_own_unit_does_not_tell_of_an_enemy_the_late_view_hides` pins
   it. The audit checks every own target against what that view exposed,
   and refuses a planted case. Undoing the forgetting fails the quick gate
   ("at tick 13110 an own unit's target named enemy 50").
4. **Should-fix 4, applied as far as M7 allows.** The league module's gate
   is now `test-rts-clock-limits`: one match each for the late and the
   tightly capped side, about thirty seconds. M7 requires every gate in
   `make check` to belong to one module, so the full league cannot stay in
   `make check` without that module running it on every `rts`,
   `ai_rts_core` or `ai_planning` change. It left `make check` instead and
   is `make test-rts-league`, as T25's `make league` is. The strength half
   of claim 4 is therefore held only when that command runs. This is for
   the owner: the other answer needs a "slow gate" kind in the manifests,
   a change to the selector.
5. **Nit 1, applied.** `not_given` compares the commands themselves, as
   text, with repeats counted.
6. **Nit 2, applied.** The doc and the PR say the human clock's row is the
   late row, because its cap never bound.
7. **Nit 3, applied.** The meter is hidden until M asks for it.
   `test_the_meter_waits_to_be_asked_for` covers it.
8. **Nit 4, applied.** The meter's figure is labelled as the last frame's
   drawing time.

Owner item 5, an overlay of the stale enemy the clocked side believes
in, is left as a recommended follow-up task.
