# Review: wave/115-a-bandit-chooses-the-opponents-answers

T99: `ai_bandit` (UCB1, and epsilon-greedy for the comparison) over pulls
and payoff sums, its Python twin and vectors; `FightBanditOpponent`, one
bandit per T37 situation, in the fighting game's modes and panel; N13 in
`check_no_training.py`; `CLAUDE.md`'s invariant 6 naming the bandit;
`make measure-bandit` and the fighting page's tables.

An independent reviewer, a context that did not write the code, read PR #56
at head 722d936.

**Verdict: changes requested, no blockers.** Three should-fix findings and
six nits. Every one was applied on the branch.

## What was reviewed

The diff against main: `godot/addons/ai_bandit/` and its tests and vectors;
`gameaikit.bandit` and its tests; `fight_bandit_opponent.gd`, the modes in
`fighting.gd`, the panel in `fighting_panel.gd` and their tests;
`bandit_measure.gd`; N13 and its planted cases; the `CLAUDE.md` row and
text; the technique pages, the fighting page and the literature row.

## Findings

Should-fix:

1. **Delayed payoffs repeated the "untried" arm.** `pulls` rose only when a
   payoff window closed, about 30 frames after the next decision, so UCB1
   chose the same arm again: hard's neutral picked "step in" three or four
   times before anything was paid, the panel saying "never tried" each
   time, and after the first round an arm with a pending payoff kept being
   chosen. The test paid at once and never saw it. The fighting page's
   tables were measured with the defect.
2. **The panel could contradict the choice** (invariant 13). Bounds were
   recomputed every frame from the current total, which moves as other
   windows close, so the arm marked `>` might not show the highest bound.
3. **N13 missed spellings**: `mean = mean + (payoff - mean) / n`,
   `q[a] = lerp(q[a], payoff, 0.1)`, and a difference named on the line
   before (`var delta = payoff - mean`, then `mean += delta / n`). A
   `static var` keeping bandits across fights is caught only by the
   restart test, and the docstring did not say so.

Nits: the header said "more often than T37's medium" where the jumper row
is 100 to 100; the header's `s + reaction + 1` did not match `lands =
seen.frame + reaction`; no test held the opponent's bandits to its own
constant; the replay test's claim for condition 3 was wider than what it
proves; the payoff window (from landing, overlapping windows crediting one
hit to two options) departs from the task's wording without saying so; the
page did not say the tables are one seed of 100 fights, nor that 0.5 was
chosen against the opponents it is measured on.

## What was done about them

1. `Bandit` counts a pull in two halves: `pull(arm)` when chosen, `pay(arm,
   payoff)` when known, and `reward` is both. The exploration term reads
   all pulls; the mean reads the paid ones (`sums / paid`). With every
   payoff known at once the two are equal, so the vectors and their
   meaning are unchanged, and the vector README says so. The opponent
   pulls when it chooses and pays when the window closes. New tests in
   both languages, and `test_a_pending_option_is_not_chosen_again_as_untried`,
   which fights without paying at once; reverting the fix fails it. The
   tables were remeasured at both constants, and the payoff spread again
   (2,481 payoffs).
2. The opponent keeps each arm's option, pulls, mean and bound as they
   stood when it chose (`chosen_from`); the panel and the overlay draw
   those. A test holds the marked arm's bound to be the highest shown.
3. N13 also refuses a written-out step that reads its left side back, and
   `lerp`, `lerpf`, `lerp_angle` and `move_toward` anywhere in its targets.
   Inside `ai_bandit` it refuses any scaled `+=` or `-=`, which catches the
   two-line form. Only there, because holders take `RANGE / 2` off a health
   and add `fight * 2` to a seed. One planted case each, and disabling each
   new branch fails the self-test. The docstring names the `static var`
   hole.

Nits: the header now says "at least as often", and the frame arithmetic
matches the code. A test asserts `current_bandit().exploration ==
FightBanditOpponent.EXPLORATION`. The replay test says it proves that
replaying `fight_log.json` behind `FightDelay` (not `FightReplay`) is
deterministic. Rebuilding a live fight's counts would also need the
opponent's seed (`fights_begun`), which the log does not keep. The class
header records the payoff window as a departure. The page says 100 fights,
one seed, under about ten wins is noise, and 0.5 was chosen against the
same opponents.

**The remeasured tables moved.** At 0.5 the bandit no longer beats T37's
medium against the turtle (15 against 20, within the noise). It gains
clearly on the medium rushdown (86 against 68), the medium ghost (45
against 30) and the hard turtle (95 against 73). It settles after 35 to 60
of 50 to 89 pulls. At the square root of two it now loses to T37 in most
rows. The page, the class header and STATUS say this.

## Runs

- `make test-godot-some SUITES="test/ai_bandit test/fighting"`: passes,
  with no `SCRIPT ERROR`.
- Python: `test_bandit*.py` and `make test-python` pass.
- `make test-bandit-vectors`: passes.
- `check_no_training.py`: passes, as does its `--self-test`.
- `make check-affected BASE=origin/main`: green, with the timing gates
  rerun alone.

## Owner decisions, with the reviewer's opinion

1. **The opponent's UCB1 constant is 0.5, not the textbook square root of
   two.** The reviewer agrees, with two caveats. The tables are one seed of
   100 fights, so differences under about ten wins are noise. And 0.5 was
   chosen against the same stand-ins and ghost it is evaluated on, with no
   held-out opponent. The remeasurement keeps the case: 0.5 is at least as
   good in every row, and the square root of two loses to T37 in most.
2. **The payoff constants live in the class, not the fighting data.** The
   30-frame window and the 100-health range are constants in
   `FightBanditOpponent`, beside T37's `LEVELS`. The task's written
   decision put "every constant in the fighting data". `characters.json`
   is the frame data a fight is resolved by, mirrored byte for byte to
   `spec/frames/`. The reviewer finds this acceptable, but it is a
   departure from the task's written decision and needs ratifying. So does
   the window starting where the option lands, not "after the option
   ends".
3. **The manual check is the owner's.** In `make demo-fighting`, press M to
   reach a bandit mode and answer one situation the same way: does it
   switch to what beats you, and after how many exchanges? Then restart:
   has it forgotten? Check also that the panel's `>` sits on the highest
   bound.
