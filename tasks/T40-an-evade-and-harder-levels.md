# T40 — An evade, and levels that are hard enough

Size: M · Prereqs: T18, T37, T38 · Files: `spec/frames/`, `godot/game/fighting/`, `godot/test/`

## Goal

The owner played T18's manual check and found the clone, the two ghosts and
T17's learner hard to tell apart, and every opponent very easy -- the fixed
hard one only a little harder than the rest. The owner's guess: the game,
not the AI. With no evade there are few choices, and opponents with few
choices look alike and are easy to read.

So two things, measured separately:

1. **An evade** -- a backdash, a quick hop backwards with a few frames in
   which strikes pass through, and recovery that a read punishes. It is the
   move fighting games give a player who wants out without guarding, and it
   gives every opponent here one more choice to differ in.
2. **Levels that are hard enough.** Hard should beat a person who is
   learning, often. T37's knobs stay honest -- reaction never under 15
   frames, no reading the controller -- so what can change is tactics and
   execution, and the options each situation offers once the evade exists.

Before writing it, read how shipped fighting games build a backdash
(invulnerable frames, distance, recovery) and write the source down, as T36
did; the frame data is a design choice and its numbers need a reason.

## Steps

1. The backdash in the frame data and in `FightRules`: its input, its
   frames, which of them strikes pass through, and the resolution order
   updated and tested rule by rule. The recorded log still replays to its
   digests, or is recorded again on purpose (`make record-replay`).
2. `FightAction` reads it as an action, "evade", so T17's n-gram and T18's
   rows see it; the rows are cut again, and the owner's recordings, which
   have no evade in them, say so.
3. The fixed opponent gains the evade among its options, and an answer to a
   player who evades too often.
4. Hard is retuned and measured: T37's ordering still holds (each level
   beats the one below 60 times in 100), and hard beats a scripted
   stand-in that plays like a learning person a stated number of times.
5. T18's comparison is run again on new recordings with the evade, and its
   page says whether the opponents became easier to tell apart.

## Acceptance

```bash
make test-godot
make test-replay
make test-opponent-levels
make test-clone-rows
python3 python/gameaikit/cloning/compare.py --report
```

## Manual check

Play hard: it should win more often than not against you, without ever
reacting faster than a person could. Then play the clone, the ghosts and
the learner again, and say whether they can now be told apart.

## Decided on the way (2026-10-16)

- **How shipped games build a backdash, read first.** Dustloop's frame
  data for Guilty Gear -Strive-: Sol Badguy's backdash lasts 20 frames,
  invulnerable on 1-5 and airborne on 1-15; Potemkin's lasts 24,
  invulnerable on 1-6 and airborne on 1-17
  (<https://www.dustloop.com/w/GGST/Sol_Badguy/Frame_Data>,
  <https://www.dustloop.com/w/GGST/Potemkin/Frame_Data>, read 2026-10-16).
  Its controls page: "a brief period of invincibility starting from the
  very first frame" (<https://dustloop.com/w/GGST/Controls>). Invulnerable
  for about the first quarter, then committed. The Street Fighter pages
  (SuperCombo's wiki, Capcom's own frame data) refused the request and
  were not read, so nothing here rests on them.
- **The numbers.** The lancer is the slow one, as Potemkin is: 24 frames,
  invulnerable on 1-6, 14 frames of travel at 6 a frame (84 units). The
  dancer is the quick one: 20 frames, invulnerable on 1-5, 12 frames at 8
  (96 units). It stays on the ground: Strive's is airborne most of its
  length, which also makes it throw-proof there; here only the
  invulnerable frames protect from a throw, so there is one rule and not
  two. After them it cannot guard and can be thrown, and a strike that
  finds it is a plain hit ("caught evading"), not a counter-hit.
- **A button of its own (O, bit 512), not back pressed twice.** A
  double tap would need a timing window and a field to remember the first
  tap; and a log recorded before the evade, in which a person walked back
  in taps, would replay differently. With its own bit, none of those logs
  can hold one -- a test goes through every older input -- and they replay
  as they did. Measured: the recorded fight's 980 frames gave the same
  digests without re-recording; 98 frames were appended for the backdash,
  and only those are new in `fight_log_digests.txt`.
- **Kept as a stun, `stun_kind` "evade"**, as a take-off is: no new field
  on a fighter, so the digests' text did not change. It costs exactly its
  `frames`, as a move does: the fighter acts on the frame after the last.
  Buffered like a button: pressed during a move's recovery it comes out
  when the move ends -- never as a cancel; pressed in the air, not there.
- **The rows were cut again; only their header changed**, which now lists
  "evade". Every row of the 33 recordings is the same, none holds an evade,
  and `compare.py --report` says so in a line of its own: "evades: 0 of 450
  decisions, in 9 recording(s) -- none: they were recorded before the
  backdash". The clone was published again with twelve classes and the win
  rates fought again under the new rules.
- **The fixed opponent's evade, and the answer to it.** "evade" is an
  option after being hit, after blocking and in neutral, at the smallest
  weight. Two situations: "it blocked" -- where a player under pressure
  reaches for the backdash -- and "it evaded". The answer is a new option,
  "long", the character's furthest-reaching strike (the lancer's thrust,
  the dancer's straight), which a backdash is still recovering from when it
  arrives. The learner (T17) leans to it when it expects an evade, and to
  an evade when it expects a throw.
- **Hard, measured against the owner and not a script.** A scripted
  stand-in was written first, its table the owner's own 450 decisions
  counted by situation. It could not tell the old hard from the new: both
  beat it 96 to 98 times in 100. The owner's ghost (T18's "ghost:
  nearest") could. The old hard beat it 56 times in 100, about even, which
  is what the owner felt; that ghost also beat the old medium 86 times. So
  `make test-opponent-levels` holds hard to beating the ghost 75 times in
  100 as each character, and medium must not reach 75 (the planted case);
  firmer since the review, below.
  The stand-in was deleted.
- **What was retuned: the weights, by what each option won.** Over 100
  fights of hard against the ghost, every decision was tallied by the health
  it gained before the next one. "Step in" in neutral was the largest loss
  (-8 a time, 1773 times). An overhead at a crouch lost 13.7: the axe kick
  is too slow. A backdash straight after a hit lost 11.6. Lows, mids and
  throws won. The lists keep their order, a beginner's reach first, so easy
  and medium still know the obvious answers; the weights now follow what
  works, and hard knows all ten neutral options. Measured afterwards: hard
  beats the ghost 80 of 100 as each character, the exact ghost 83, the clone
  94. Since the ghost is what it was tuned against, those flatter it, so
  the check is T18's stand-ins, which were not used for tuning. Against the
  rushdown it went from 61 to 92, the jumper stayed at 100, and the turtle
  went from 87 to 84. The ordering still holds: medium beats easy 100 of
  100, hard beats medium 90 and 99. With equal reaction times, hard beats
  medium 80 and 92.
- **Found on the way:** T18's stand-ins had habits for T37's five
  situations only, and stopped dead in "it evaded". They now fall back to
  neutral, and a test holds that every stand-in has options in every
  situation.
- **Step 5 waits for the owner.** The T18 comparison was run again, and
  passes, on the recordings there are: nine fights, none with an evade.
  Whether the opponents became easier to tell apart needs new recordings
  with the evade in them (`make record-fights`, then `make train-clone`),
  and a person to play them. That is the manual check above.

## After the review (2026-10-16)

The review ([docs/reviews/43-an-evade-and-harder-levels.md](../docs/reviews/43-an-evade-and-harder-levels.md))
found the backdash's rules sound and the rest not ready. What changed,
measured again after each change:

- **"long" is gone: there is no answer that punishes a backdash it sees.**
  In "it evaded" the long strike caught a backdash 5 times in about 800
  (lancer) and never in about 760 (dancer). Seen 15 frames late, the
  backdash is over before any strike arrives, and this is the reaction
  a person has too. In "it blocked", the pre-emptive read the decisions
  above relied on caught nothing in 8 tries: the dancer's backdash carries
  it past the straight's reach. So the option, `longest_strike` and the
  claim are removed. "It evaded" now follows (step in, or a high), and the
  learner's answer to an expected evade is to follow. What a backdash costs
  is the ground it gives up, and that is not much. Measured: an opponent
  with medium's knobs that backdashes out of every block and every hit
  loses to hard 95 and 98 times in 100, and is about even with medium, which
  beats it 43 and 44 times. The habit is neither punished nor rewarded.
  So step 3's "answer to a player who evades too often" is **not done**,
  and this says so. A real read would need knowing the player's habit (T17) and a
  strike that reaches, which neither character has against the dancer.
- **Every level evades.** "evade" is now second in "after blocking", which
  is a beginner's reflex, so easy and medium choose it. A test holds that
  every level knows it, and the medium learner can now answer a throw with
  it.
- **The hard gate is firmer.** It reads a frozen copy of the owner's ghost
  (`godot/test/owner_ghost.json`), so retraining the clone does not move
  the bar. It plays 200 fights per character and holds hard to 150 of them.
  It also holds hard to 130 of 200 against T18's turtle stand-in, which
  hard was not tuned against and does worst against, as the lancer only:
  as the dancer every level beats the turtle 195 to 200 times in 200. Over
  200 fights at two sets of seeds:

  | against | T40's hard | T37's hard | medium |
  |---|---|---|---|
  | the ghost, as the lancer | 172, 178 | 123, 133 | 60, 64 |
  | the ghost, as the dancer | 162, 158 | 109, 113 | 39, 44 |
  | the turtle, as the lancer | 150, 147 | 136, 135 | 37, 25 |

  T37's hard now fails the ghost bar by 17 fights or more, and the new hard
  clears it by 8 or more. Against the turtle the margin is thinner (17 over
  the bar, T37's hard 6 under), which is why the turtle bar is lower.
- With equal reaction times, hard now beats medium 95 and 92 times in 100.
  The ghosts beat the retuned medium 60 and 66 times in 100, and the clone
  49 (`compare.py --report`).
- Smaller fixes: a backdash pressed with down held now stands (it used to
  stay crouched for all its frames, and nothing tested it); stale numbers
  on the cloning page and in two comments; the legend names evading among
  the paler states.
