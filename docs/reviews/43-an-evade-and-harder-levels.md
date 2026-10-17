# Review: wave/43-an-evade-and-harder-levels

One fresh context reviewed it, in the main worktree, at 4352766.

What it read: CLAUDE.md, T40 (its "Decided on the way" in full), the wave
42 record, the diff, and the fighting files around it (`fight_rules.gd`,
`fight_backdash.gd`, `fight_opponent.gd`, `fight_model_opponent.gd`,
`fight_clone_opponent.gd`, `fight_situation.gd`, `fight_action.gd`, the
view, the sprites, the panel, the stand-ins), `opponent_levels.gd`,
`compare.py` and the behaviour-cloning concept page.

What it ran: `make test-godot` (785 cases, 0 failures); `make test-replay`
(1078 frames, 0 problems); `make test-clone-rows` (matches the 33
recordings); `compare.py --report` (exit 0, the evade line as T40 quotes
it); `make test-opponent-levels` (exit 0: hard beats the ghost 80 and 80,
medium 36 and 32); `make test-python` (283 OK); `make check`'s script
gates (every one ok; the run was stopped during `test-python`, which was
then run alone). Probes, from the scratchpad and not committed: hard against
each ghost, the clone and the three stand-ins on `opponent_levels.gd`'s
seeds and on seeds offset by 1000; every decision hard makes in "it
evaded", followed to its outcome, over 100 hard-against-hard mirrors per
character; hard against medium with equal reaction at 15, 22 and 30; the
gate with T37's weights restored; 15 mutations. Every mutation was undone
and `git status` was clean afterwards.

## What was reviewed

Commit 4352766: `FightBackdash`, the backdash in `FightRules`,
`FightInput`, `FightData`, `FightAction`, `FightSituation`, the frame data
and its README, the two new situations, "long" and the evade in
`FightOpponent`, the learner's answers, the view, sprites, panel and
overlay, the replay log and digests, `opponent_levels.gd`, the stand-in
fallback, `compare.evades`, the regenerated rows, clone weights and win
rates, and T40, T41, T42 and STATUS.

## Checked and true

- **The backdash, frame by frame.** Pressed on frame N, it occupies N to
  N+frames-1 and the fighter acts on N+frames; it travels on frames 1 to
  `travel` (84 and 96 units); `invulnerable` is checked after step 2, so
  frame 1 is already protected. Mutating the length by one, the travel
  bound, or the invulnerable bound either way each fails
  `fight_backdash_test.gd`.
- **Buffering.** An evade waits through a move's recovery and comes out the
  frame the move ends; never a cancel (allowing it fails 26 cases); never
  in the air (allowing it fails 24). A strike button pressed during the
  backdash is buffered and comes out when it ends, as with any stun.
- **What finds it.** Strikes and throws pass through on the invulnerable
  frames; after them a strike is a plain hit and a throw lands, as the
  resolution text in `characters.json` says. No `stun > 0` reading
  elsewhere misbehaves: `situation_of`, `FightAction.of`,
  `FightSituation.condition_of`, the panel and the sprites all test
  "evade" before the generic stun. The two copies of `characters.json`
  are byte-identical.
- **Old logs.** `fight_log_digests.txt` gains 98 lines and loses none; the
  first 980 are main's. No input below bit 512 can read as an evade, and
  the test goes through every one.
- **The equal-reaction numbers.** With both levels at reaction 22, hard
  beats medium 80 (lancer) and 92 (dancer), as `fight_opponent.gd` says.
- **The gate's own numbers.** 80 and 80 against the ghost; hard beats medium
  90 and 99; medium beats easy 100 and 100.
- `compare.py --report` prints "evades: 0 of 450 decisions, in 9
  recording(s) -- none ..." and its test holds both branches.
- The stand-in fallback: reverting it fails 12 cases of the new test.

## Findings

### Must fix

1. **"Long" does not do what it is there for: with a 15-frame reaction it
   cannot reach a backdash before the backdash is over.**
   `godot/game/fighting/fight_opponent.gd:56-59, 66, 217-219`, the T40
   bullet "a backdash is still recovering from when it arrives", and
   `fight_model_opponent.gd:32-34` ("a backdash to its longest strike,
   which arrives as the backdash stops"). The arithmetic: hard sees the
   fight 15 frames late, so the earliest it can see "it evaded" is the
   backdash's frame 1 at real frame N+15. The lancer's backdash ends at
   N+24 and the thrust (startup 13) is first active at N+28; the dancer's
   ends at N+20 and the straight (startup 7) is active at N+22. In a
   mirror the long strike always comes after the evader is free again.
   `_reaches` also judges reach from where the two stood at the backdash's
   frame 1, before most of the 84 or 96 units of travel. Measured over
   100 hard-against-hard mirrors per character, every "it evaded"
   decision followed to its outcome: the lancer chose "long" about 800
   times; 370 were "out of reach: steps in", and **5 caught the evader**
   during its backdash. The dancer: 637 out of reach, **0 caught**. Of
   every "caught evading" event in those fights (about 70 per character),
   "it evaded / long" accounts for 8 (lancer) and 0 (dancer). Lows and
   mids thrown in neutral account for most of the rest. So T40's step 3,
   "an answer to a player who evades too often", is not there. The answer
   that exists is that a hit after a backdash lands on a fighter who is not
   holding guard, which is not a read. Nothing tests the answer works:
   replacing "long" with the quickest high (`long_is_quickest`) survives
   `make test-godot`. *Reproduced.*
   *Fix:* either make the answer reachable inside the rules (an option
   played on prediction rather than sight, e.g. "long" in "it blocked"
   timed for the end of blockstun, which is where the backdash comes out;
   or the learner's prediction, which is not limited by sight), or say
   plainly that at a human reaction the backdash cannot be punished on
   sight, and drop the claim. In either case, add a test that seats hard
   against a scripted backdasher and counts "caught evading".

### Should fix

2. **The independent check does not hold hard to the bar, and its numbers
   cannot be reproduced by any command.** T40, "the check is T18's
   stand-ins ... Against the rushdown it went from 61 to 92, the jumper
   stayed at 100, and the turtle went from 87 to 84", and
   `fight_opponent.gd:28-33`. Measured on `opponent_levels.gd`'s own
   seeding: rushdown 93 (lancer) and 85 (dancer); jumper 100 and 100;
   **turtle 66 as the lancer** and 100 as the dancer. On seeds offset by
   1000: rushdown 88 and 75, turtle 68 and 100. One number per stand-in
   hides that hard as the lancer beats the turtle only 66 times in 100.
   That is below the 75 the gate requires against the ghost, on the
   opponent the task names as the check. The exact ghost (claimed 83) is
   89 and 82; the clone (claimed 94) is 95 and 90. No committed command
   produces any of these numbers. *Reproduced.*
   *Fix:* print hard against each stand-in, per character, from
   `opponent_levels.gd` (reported, not gated, if a bar is not wanted), and
   quote those lines. Say that the lancer is weak against a turtle.

3. **The gate's planted case is far from the bar, and the bar sits inside
   seed noise.** `godot/test/opponent_levels.gd:80-88`. Medium beats the
   ghost 36 and 32 against a bar of 75, so the planted case would also
   pass at a bar of 40. The case that tells the bar apart is T37's hard,
   and the gate does not plant it. Measured with T37's weights and tactics
   9 restored (the two new situations kept), the gate fails at **74** as
   the lancer, one fight short, and 51 as the dancer. On seeds offset by
   1000, the new hard scores 88 and **75**: exactly on the bar. The gate
   is deterministic, so it will not flicker, but any change to the seeds,
   the ghost or the fight loop can move a character across the bar with
   nothing about hard changing. And the ghost is rebuilt from
   `clone_weights.json`: the owner's next `make train-clone`, which T40
   asks for, changes what the gate measures. *Reproduced.*
   *Fix:* plant T37's hard (its weights kept as a constant in the test)
   and require it to fail. Report the margin, or play 200 fights. Name in
   the header that the gate moves when the clone is retrained, and pin the
   ghost the gate uses (its sha256, as `win_rates.json` does) so that a
   retrain is a deliberate re-measure.

4. **A load-bearing rule with no planted case: a backdash pressed while
   holding down.** `godot/game/fighting/fight_rules.gd:42`. Remove
   `FightBackdash.KIND` from `STANDING_STUNS` and all 785 cases pass. The
   rule matters because `_act` returns early on every carried frame
   (`:96-97`), so crouching is never set again during the backdash. With
   the mutation, EVADE|DOWN on frame 1 then DOWN held gives a backdash
   **crouched on all 24 frames**, so highs pass over its vulnerable
   frames. `test_a_backdash_is_committed_for_its_frames_and_no_more`
   holds down on even frames, which looks as if it covers this, but it
   presses the evade without down, so the line it would test never runs.
   *Reproduced* (scratch probe, both with and without the mutation).
   *Fix:* press `EVADE | DOWN` on the first frame of that test.

5. **Only hard ever evades.** `fight_opponent.gd:62-71`. "evade" is last in
   every list (index 5 and 9), and easy and medium know the first 2 and 4.
   So they backdash only when a fumble's `_slip` draws it. The learner at
   medium, the one T18's win rates seat, never has "evade" or the answer
   "throw -> evade" among its options. T40's Goal says the evade "gives
   every opponent here one more choice to differ in", and its "Decided"
   says the learner leans to an evade when it expects a throw. That is
   true at hard only. Moving `["evade", 1]` to `["step out", 1]` in
   neutral (`no_hard_evade`) survives `make test-godot`: no test holds
   that any level evades. *Reproduced (mutation).*
   *Fix:* say it in the header and in T40, or give medium the evade. Add a
   test that hard's options include it.

6. **Text the data now contradicts.**
   - `docs/concepts/behaviour-cloning.md:104-112, 115-116, 127-128`: the
     table and prose still say the ghosts beat medium 78 and 86, the clone
     64, the learner 40, the medium reference 35, and give the numbers
     column as ≤121 / 143 / 396. `win_rates.json` and `compare.py
     --report` now say 70, 71, 48, 37, 33 and ≤144 / 156 / 432. The page's
     `verified_on` is still 2026-10-15. "A ghost is the better opponent"
     still holds; the numbers under it do not.
   - `godot/test/opponent_levels.gd:7`: the ghost "beat medium 86 times in
     100". That is under T37's rules; today it is 71.
   - `godot/game/fighting/fight_model_opponent.gd:45`: "the surest it
     gets about one of eleven actions is 6 in 16". There are twelve now:
     6 in 17.
   - `godot/game/fighting/fighting.gd:94`: the legend says
     "paler: stunned, taking off or landing". A backdash is drawn pale too
     (`stun > 0`).
   *Fix:* rerun the report into the page and bump `verified_on`, then
   correct the three comments.

### Could fix

7. `fight_rules.gd` went from exactly 400 lines to 424. The 400-line limit
   only binds `addons/`, so this is not a gate failure, but this file is
   the teaching centrepiece. The new `_start_buffered` branch and the
   step-4 comment could move into `FightBackdash`, as the jump's did.
8. `godot/game/fighting/fight_action.gd:5-6`: the header was not reflowed,
   and one line runs past the others.
9. `python/tests/test_cloning.py:100`: the evade-count test sits in
   `TestTheNGramIsTheGames`, which is about the n-gram's settings. It
   belongs in a class of its own or next to the report tests.
10. `FightBackdash.start` does not clear `move`. It is only reached with
    `move == ""` today (cancels are refused first), but a later caller
    would leave a fighter both in a move and evading. A one-line guard or
    a doc line would close it.

## Verdict

**Not as is.** The backdash itself is right frame by frame, it is well
tested, and the old logs replay unchanged. That half could merge. The
other half is T40's step 3: "long" is meant to answer a player who
evades, and at a human reaction it lands on a backdash 5 times in about
1,400 decisions. The opponent therefore has no answer to the evade,
and the evade is the reason the task exists. Finding 1 needs either
the answer to work or the claim to go. Findings 2 and 3 are about the
evidence that hard is hard enough: today that evidence is one
deterministic run that sits 5 above the bar, with a planted case 40
below it, and the check meant to be independent has the lancer at 66.
4 to 6 are small and should go in the same pass.

## What was done about them

All ten were answered by the author, on the branch, before the merge.
Seven were fixed and three were left on purpose. The numbers are in T40's
"After the review".

1. **Fixed, by removing the claim.** "long" is gone, and so are
   `longest_strike` and the learner's lean towards it. The pre-emptive
   read in "it blocked", which the decisions relied on, was measured too:
   it caught nothing in 8 tries, because the dancer's backdash carries it
   past the straight's reach. "It evaded" now follows (step in, or a
   high). T40 says its answer to a player who evades too often is **not
   done**. An opponent with medium's knobs that backdashes out of every
   block loses to hard 95 and 98 times in 100, and is about even with
   medium. The habit is neither punished nor rewarded.
2. **Fixed.** The turtle is now a bar of its own: 130 of 200, as the lancer.
   As the dancer every level beats it 195 to 200 times, so a bar there
   would measure nothing. Its numbers come from `make
   test-opponent-levels`, at 150 and 147 of 200 over two sets of seeds.
   The task now gives every measured pair, not one number per stand-in.
3. **Fixed.** The gate plays 200 fights per character and reads a frozen
   copy of the ghost (`godot/test/owner_ghost.json`), so retraining the
   clone does not move it. Over two sets of seeds, T40's hard won 158 to
   178 of 200 against a bar of 150. T37's hard won 109 to 133 and fails by
   17 or more. Medium won 39 to 64.
4. **Fixed.** A test presses the backdash with down held and checks that
   it stands on every frame. With `FightBackdash.KIND` taken out of
   `STANDING_STUNS` it fails.
5. **Fixed.** "evade" is now second in "after blocking", inside even easy's
   tactics. A test holds that every level knows it, and it fails with the
   evade put back at the end. The medium learner can now answer a throw
   with it.
6. **Fixed.** The cloning page has the current win rates, with T37's beside
   them, and is dated 2026-10-16. `opponent_levels.gd` says "T37's medium";
   the model's comment says 6 in 17; the legend names evading among the
   paler states.
7. **Left.** `fight_rules.gd` is game code, not an addon. Splitting step 3
   or step 4 out to get it under 400 is a change of its own.
8. **Fixed.** The `fight_action.gd` header is reflowed.
9. **Left.** The evade-count test is about `compare.report`'s output, and
   sits beside the other report tests.
10. **Left.** `FightBackdash.start` is only reached with no move, from
    `_start_buffered`. A test would only be guarding a path that does not
    exist.
