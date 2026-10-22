# Review: wave/76-health-that-comes-back

A fresh context reviewed T68 at `b796c3e`: health that comes back after
10 s without a hit, the base healing whole, and hiding to heal weighed
beside going home in `ErrandChoice`. It was not allowed to edit the
worktree. It ran `make test-teamwork-vectors` (52 files, 0 failures), the
gdUnit suites of `test/botmatch` and `test/ai_teamwork` (75 cases, no
SCRIPT ERROR), `check_readability`, `check_modules` and
`check_doc_freshness`, all green; it did not run the effects gate, and
reproduced finding 1 with a scratch probe over five seeds.

**Verdict: fix before merge.**

## What was reviewed

- `CLAUDE.md`, T68's task, `docs/godot/botmatch.md`,
  `docs/concepts/shooter-ai.md`, and the diff against the merge base.
- Regeneration end to end: the delay's edge, the cap, a hit, death and
  respawn, the person's bot, the order of a step's kill, heal and supply.
- Whether the weighing is a cost and a gain the bot perceives, or a
  threshold in disguise -- the owner's standing rule.
- The two speed fixes, the Python twins line by line, each new claim's
  planted case, and every quoted source against its page.

## Findings

1. **The base resurrected a bot from a lethal hit** (high): a bot shot to
   0 at its base still got `supply.touch` before the kill was counted, so
   it ended the step at 100 ("no commander seed 3 t=89.25 bot 11 health
   before 4 now 100"), and `healed_at_base` was inflated.
2. **Claim 10 could not reject a weighing that does nothing** (medium):
   "at least as long" passes when the weigher behaves like never healing.
3. **The weighing was a threshold in disguise** (medium): a constant cost
   to leave made it "hide below ~67 holding, ~44 attacking", nothing
   perceived entering; and the gain counted health that comes back while
   staying anyway.
4. **Healing is a team errand, not in T67's selector** (low-medium), and
   the deviation was not recorded.
5. **The cached hiding place could go stale** (low) for a second while
   enemies moved.
6. **`health_worth` was pinned by no vector** (low).
7. **The no-commander shift to 19-1 was unexplained** (low).
8. **An over-long doc line, and an Upcomer timing attributed to "one
   player"** the page does not name (nit).

## What was done about them

All eight applied on the branch (`898f62a`, `6d0b2b4`), rebased on main
with waves 75 and 77, the effects gate run again (0 failures, 2757 s):

1. The dead are counted before the base or regeneration heals; a
   `health_test` case fails with the old order planted back.
2. **The stronger claim was measured and did not hold**: weighing is 0.5
   errors behind never healing and 2.1 ahead of breaking off below half,
   short of 2.5. The gate keeps "at least as long" and both it and
   `botmatch.md` say outright that it passes a weighing that does nothing;
   the strong comparison is printed, not claimed -- the owner's rule.
3. The health gained is multiplied by exposure: 1 when hit in the last
   2 s, else the share of known enemies with a line to the bot, 0 when it
   knows of none. The break-even is in `botmatch.md` (under fire, hiding
   pays below 44 holding, 22 attacking; going home 4 s away, below 50).
   The reviewer's case -- 25 health, no enemy known -- now stays, pinned
   by a vector. Priced so, a bot hides 4.3 s a match: little, which is why
   claim 2 does not hold.
4. Left where it is, with the reason recorded in the task and the doc:
   `ActionChoice` multiplies scores in 0..1 and cannot weigh a gain
   against a cost in one unit, and an errand is the team's to carry out.
5. The place is asked again when the set of known enemies changes.
6. A vector with `health_worth` 0.5; eight mutations of the Python twin,
   all caught.
7. Measured: not the resurrection (planting it back moved the margins by
   about a second) but the first cut's weighing; after the fixes the team
   without a commander is -4.1 ± 13.5 s, 9-11. Why that cut favoured it
   is a guess, and the doc says so. The yards mirror is now 1.5 errors.
8. Fixed.
