# Review: wave/173-engagement-rings

T155. The PR adds `EngagementRings` to `ai_teamwork`
(`godot/addons/ai_teamwork/engagement_rings.gd`) and its Python twin
(`python/gameaikit/teamwork/rings.py`). The class places points on three
rings round a target: `INNER` for a melee token holder, `WAITING` for the
rest of the melee, `RANGED` for the ranged. `TacticalPositions` then picks
among the points. A point on another ring is `OUTSIDE_AREA`. A point within
`spacing` of another enemy's claim, on any ring, is `CLAIMED`. A point with
no line of sight is `EXPOSED`. A point behind the camera is taken only on a
second pass. The PR also adds eight `rings` vectors from `derive.py`, suites
in both languages and the docs.

A fresh context reviewed PR #131 on `origin/wave/173-engagement-rings`,
using only the owner's short list of commands (no `make check`).
**Verdict: changes requested. No blocker. Two shoulds to apply on the
branch before the merge, and four nits.** The code is small and readable,
and the twins agree. The vectors and suites catch every mutant that matters
in both languages. The two shoulds are behaviours that T157 will hit and
that the suites cannot see.

## What was run

- `make worktree-setup`, then `./scripts/godot --headless --path godot --import`: 0.
- `make check-no-engine`: 0.
- `make test-godot-some SUITES="test/ai_teamwork"`: 0, 35 cases,
  0 failures, no `SCRIPT ERROR` in the output.
- `make test-teamwork-vectors`: 0, "53 file(s), 0 failure(s)".
- `make test-python`: 0, 708 tests, OK. This was rerun on its own after the
  mutation rounds, with `__pycache__` cleared first.
- `make lint-modules`: "ok -- 40 modules".
- Modules whose `depends_on` names `ai_teamwork`, and their gates:
  - `botmatch`: `make test-botmatch-effects` gave "4 pairings of 20
    matches, 0 failure(s)". `make test-player-model-vectors` gave "11
    file(s), 0 failure(s)".
  - `infiltration`: `make test-infiltration-properties`,
    `make test-infiltration` and `make test-director-vectors` were all 0
    with 0 failures.
  - No `SCRIPT ERROR` in any of them.
- `python3 scripts/check_readability.py`: 0. No line over 120 characters in
  the four new code files.
- Authorship: `git log origin/main..HEAD` has three commits by Adalberto
  Pereira <adalbertobosco@gmail.com>. Neither they nor the PR's title and
  body contain "Claude", "Anthropic", "Co-Authored-By" or "Generated".
- The twins agree on every vector. Both runners check each of the 53 files
  against the file itself, not against each other, and both pass.
  `test_a_planted_wrong_answer_is_caught` covers the new kind as well.
- The addon header says what the class solves, its complexity
  (O(points^2) per choice) and when not to use it.

## Mutations

Each mutant was applied to the source, run, and then the source was
restored. Python runs used `test_teamwork_vectors.py` and
`test_teamwork_rings.py`, and `__pycache__` was removed after each one.
GDScript runs used `make test-teamwork-vectors` and
`make test-godot-some SUITES="test/ai_teamwork"`.
`git status` was clean afterwards.

| mutant | Python vectors / suite | GDScript vectors / suite |
|---|---|---|
| spacing `<` to `<=` | survived / survived | survived / survived |
| spacing ignored (only the claimed point itself crowded) | caught / caught | caught (4) / caught |
| `other is point or` dropped | survived / survived | -- |
| crowding returns a wrong holder (999) | survived / survived | -- |
| crowding only on the same ring | **survived** / caught | -- |
| camera `>` to `>=` | caught / survived | caught (3) / survived |
| camera inverted | caught / caught | caught / caught |
| camera never in front | caught / caught | -- |
| no front pass | caught / caught | caught / caught |
| no fallback pass | caught / survived | -- |
| line of sight ignored | caught / caught | caught (22) / caught |
| `covered_from_main` true | caught / survived | caught (18) / survived |
| old claim kept while choosing | caught / survived | caught (6) / survived |
| `release` does not clear | caught / caught | caught / caught |
| radius ignored or doubled | caught / caught | caught / caught |
| phase ignored | caught / survived | caught / survived |
| `ring_for`: holder waits | survived / caught | survived / caught |
| `ring_for`: ranged holder goes inner | survived / caught | -- |
| ring ignored in `in_area` | caught / caught | caught / caught |
| `threat_distance` measured from the enemy | caught / survived | caught (38) / survived |
| `place` clears the claims | caught / caught | caught / caught |
| claims off in `TacticalPositions.choose` | caught / caught | -- |

The two languages behave the same on every mutant run in both. The suites'
three planted generators (they ignore the claims, the view or the sight)
each fail their test. Checked by hand: an "empty" generator, one whose
`choose` always returns -1, passes the three property tests without
breaking anything (see finding 1). `test_no_point_left_is_minus_one` and
`test_the_points_lie_on_their_rings_and_follow_the_target` reject it.

## Findings

### 1. should -- waiting claims can lock the token holder out of the inner ring

`engagement_rings.gd:175-181` (`_crowding`) and `rings.py:125-132` (PR
decision 2: the spacing applies across rings).

A waiting enemy's claim crowds the inner points near it. So an enemy that
was just granted a melee token can find every inner point `CLAIMED` and get
-1. Then it has nowhere to strike from. The task says "Holding a token
moves an enemy to the inner ring", and T157's minions depend on that.

Measured on the suite's own scenes (40 seeds x 30 steps, its config, with a
script that only counts outcomes):

- 224 of 2400 token-holder choices (9.3%) returned -1, and in every one of
  them all inner points were `claimed`.
- 733 of 4800 waiting choices returned -1. 491 of them were all `claimed`.

The suites check their properties only `if chosen != -1`, so all of this
passes as green. Nothing says that a holder gets an inner point.

Possible fixes:

- Crowding from a `WAITING` claim does not apply to an `INNER` point, so
  the waiter gives way.
- Or a static `config_problem` (like `AttackTokens.config_problem`) that
  refuses rings whose radial gap, or whose neighbour chord, is below
  `spacing`. In the suite's config, inner at 2 m and waiting at 4 m with a
  spacing of 2.5 m both fail. Ten points at 4 m are 2.47 m apart, so each
  waiting claim also crowds both of its neighbours.

In both cases, add a property: a melee token holder gets an inner point
whenever one is not crowded by another holder.

### 2. should -- default `max_travel` breaks the camera rule and strands far enemies

`engagement_rings.gd:53` (`Config.weights` defaults to
`TacticalPositions.Weights`, whose `max_travel` is 20 m:
`tactical_positions.gd:68`), and `engagement_rings.gd:161`.

`TOO_FAR` is checked before `OUTSIDE_AREA`. So a front point that is too
far fails the front pass, and the fallback pass takes a nearer point behind
the camera. Planted with the default weights (rings at 2/4.5/9 m, camera at
(0,-3) looking along +y):

- A waiting enemy at (0,-22) takes `waiting-6` at (1.71,-4.16), behind the
  camera. The front points are unclaimed and in sight, only "too far".
  This is the case the acceptance property ("no waiting claim behind the
  camera when a free one is in front") exists to rule out.
- A ranged enemy at (0,30) gets -1: every ranged point is `too_far`.

The vectors (30 m) and the suites (40 m, spawns within ±12 m) never reach
this case.

Possible fixes: ring choices should not drop by travel. For example,
`Config` sets a large `max_travel`, or travel only ranks and never filters.
At the least, state the limit on `Config` and in the technique page.

### 3. nit -- the overlay cannot show the camera rule from `last_choice`

`engagement_rings.gd:163`. A point behind the view and a point on another
ring both come out as `OUTSIDE_AREA` in `last_choice.statuses`. T157's
overlay (invariant 13: show why) would have to redo the half-plane test to
show the camera rule, which is this class's own lesson. A `behind` flag per
point, or the pass that answered, would let it draw that rule directly.

### 4. nit -- two ids per minion

`docs/techniques/ai_teamwork.md:215`. `AttackTokens` names enemies by
`String`, and `EngagementRings` by `int` (inherited from
`TacticalPositions`). The page's example tests `name in
tokens.holders("melee")` and then calls `choose(enemy_id, ...)`, so T157
has to keep both ids. Say so on the page, or show the mapping.

### 5. nit -- what no vector pins

- No vector puts a point exactly at `spacing` from a claim, so `<` to `<=`
  survives in both languages.
- No vector uses a spacing of 0, so dropping `other is point or` is an
  equivalent mutant today.
- No vector crowds a point across rings. Decision 2 is held only by each
  language's suite, so the twins could disagree on it with every vector
  green.
- `ring_for` is held only by the suites (the vectors name the ring
  directly).

One vector each for the boundary and the cross-ring case would close the
first and third.

### 6. nit -- the suites never assert that a choice was made

This is the test side of finding 1. In both `engagement_rings_test.gd`
(`_one_step`) and `test_teamwork_rings.py` (`fight`), a -1 skips every
check. Counting the -1s, or asserting that a holder is placed, would stop
an over-strict generator from reading as a correct one.

## The PR's decisions, judged

1. The front rule as a filter with a second pass, not as a weight:
   agreed. A weight could not hold the property. Finding 2 is the one gap.
2. Spacing shown as `CLAIMED`, across rings: the mechanism is fine. Across
   rings it needs either a priority for the holder or a config check
   (finding 1).
3. Line of sight on every ring: agreed, documented.
4. Ranged keep to their band with or without a token: agreed. This matches
   T157 (ranged token revoked under melee pressure).
5. A strict half-plane, pinned by a vector: agreed.
6. `choose` releases first, with no stealing: agreed. It also means an
   enemy with no point loses its old one. That is fine, but T157 must
   handle -1 (see findings 1 and 2).
7. Drawing left to T157 through `last_choice`: agreed, see finding 3.
