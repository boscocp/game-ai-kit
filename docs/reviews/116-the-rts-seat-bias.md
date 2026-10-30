# Review: wave/116-the-rts-seat-bias

T57: the mirror match as a gate (claim 6 of `test-rts-match`), each
suspect the task named measured on its own, and three tie-breaks made
mirror images (`RtsScenario.as_seen_by` for the building ring and the
squads' open cell, `FlowField._wins_tie`).

A fresh context reviewed PR #57 at head a1ef091, reading only. Before the
findings were applied the branch was rebased on main at b672d5b (T108,
PR #53); the rebase was clean.

**Verdict: changes requested, no blockers.** Three should-fix findings
and two nits, all applied on the branch, and a follow-up proposed.

## What was reviewed

The diff against main: `flow_field.gd` and its new mirror test;
`rts_scenario.gd`, `economy_queue.gd`, `squad.gd` and the scan test in
`rts_game_test.gd`; the core test whose fixture moved; claim 6 in
`rts_match.gd` and the mirror pairing in `rts_measure.gd`; the T57
section of `docs/concepts/rts-ai.md`; the STATUS row; the per-suspect
measurements reported in the PR.

## Findings

Should fix:

1. **Claim 6 passed on an empty record** (`rts_match.gd`, `seat_bias`):
   `decided == 0` returned "", so twelve draws were green -- a gate that
   passes on nothing (invariant 4). And it had one planted case, to the
   west; a `seat_bias` that looked at west only would have passed.
2. **A 70% share has a high, draw-dependent false-alarm rate** for fair
   seats: 14.6% on 12 decided matches, 22.7% on 11, 10.9% on 10. Every
   change to `ai_core`, `ai_rts_core` or `game/rts` re-deals the twelve
   matches, so the gate would go red by chance one re-deal in five to
   seven, and teach people to re-roll it. Use an exact two-sided binomial
   test, p < 0.05, on the decided matches: on 12 it trips at 10 - 2
   (3.9%); on 20 it still catches T20's 15 - 5 (p = 0.041). Consider the
   paired statistic too (seeds where one seat won both legs). Say that 12
   matches cannot see a 60/40 seat.
3. **`ai_rts_core` is a shipped library** (`flow_field.gd`'s header): every
   user's units now take the vertical leg first on equal routes, and the
   tie-break respects a half-turn only -- a map mirrored left to right, or
   four seats turned a quarter, still get a bias. Say which symmetry the
   ties respect, in the header and in `docs/techniques/ai_rts_core.md`
   and its pt-BR page.

Nits:

4. `rts_measure.gd` played the mirror through its own `_pairing`: call the
   shared `mirror_record`, and say claim 6's 12 matches are the first 12
   of rts-measure's 20 -- the concepts page presented them as two records.
5. The comment above `_ring_cells` and `as_seen_by`'s doc said "towards
   the enemy first"; the top row faces the enemy, but the scan starts at
   the corner away from it.

Lead for the opposite biases (not for this wave): `REGIONS["bridge"]` =
(24, 15) is the only neutral region that is not its own mirror -- its
turn is (23, 16), and on a 48 x 32 map no cell is its own half-turn, so
no single-cell neutral region can be fair. East's home is about 1.4 cells
nearer the bridge (20.6 against 22.0), and `SquadTactics.scores` divides
by distance. Claim 1 checks `MAP`, not `REGIONS`.

## What was done about them

1. `seat_bias` refuses fewer than `MIRROR_SEEDS` (6) decided matches, and
   claim 6 now plants three records that must be refused: 10 - 2 to the
   west, 2 - 10 to the east, twelve draws.
2. `SEAT_SHARE` is gone. `seat_p` is the exact two-sided binomial test
   (twice the tail at one half, capped at 1) and `SEAT_P` = 0.05; the
   comment gives both trip points and says twelve matches cannot see a
   60/40 seat. Six seeds kept. The paired statistic was not adopted: on
   six seeds it is six pairs, and the pairs measured in the wave split
   19 - 25 (west both - east both) over 100 seeds before the fixes and
   13 - 17 over 60 after them, no more telling than the wins; it stays an option for the owner (below).
3. One paragraph in `flow_field.gd`'s header, one sentence in
   `docs/techniques/ai_rts_core.md` and its translation in the pt-BR page,
   `translation_of` restamped.
4. `rts_measure.gd`'s `_seat_bias` plays `RtsMatchCheck.mirror_record(SEEDS)`
   and judges it with `seat_bias`/`seat_p`; `_pairing` lost its `by_seat`
   flag. The concepts page says the twelve are the first twelve of the
   twenty.
5. Both comments now say only what the order is: west's from the
   top-left, east's from the bottom-right.

The bridge lead is written into the concepts page beside the corner lead,
and proposed below as a task.

## For the owner

1. **The gate's statistic.** The reviewer: replace the 70% share with the
   exact binomial test, p < 0.05 -- done; it trips at 10 - 2 on 12 and
   15 - 5 on 20. Open: whether to add the paired statistic (seeds where
   one seat won both legs), and whether six seeds is enough when twelve
   matches cannot see a 60/40 seat.
2. **A follow-up task for the opposite biases** -- base kills west
   158 - 77, time-outs on worth east 201 - 122 over 560 matches, still
   30 - 9 and 25 - 55 with this wave's fixes. Proposed: "The RTS regions
   as mirror images". Steps: (a) claim 1 checks `REGIONS` as it checks
   `MAP`, every neutral region paired with its turn; (b) the bridge (and
   the fords, if they are scored as single cells) becomes a pair of cells
   or a point at the true centre, so neither home is nearer; (c) regions
   scored and walked to at the cell's centre, not its corner
   (`Vector2(cell)`); (d) each measured alone on the split, as T57 did.
   Acceptance: `make rts-measure` prints the split by how the match ended,
   and neither part is lopsided by the same binomial test.
