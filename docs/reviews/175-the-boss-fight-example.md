# Review: wave/175-the-boss-fight-example

T157. The PR adds the boss fight you play: `BossFight`, a world a test can
step with no scene, where the boss (T156) and three melee and two ranged
`BossMinion`s share the player's `AttackTokens` (T154), stand on
`EngagementRings` (T155), walk by arrive and separation and aim along
`LineOfSight`; the scene, its drawing, panel and legend; the overlay as
data (`BossFightShown`); a seeded scripted audit over 8 seeds; en/pt-BR
strings; the card, `games.json`, `demo_overlays.gd`, `locale_screen.gd`,
`modules/bossfight.json`; `docs/godot/bossfight.md`.

A fresh context reviewed PR #134 on `origin/wave/175-the-boss-fight-example`
(one commit, 1bddc8b), on the owner's short list of commands (no
`make check`).
**Verdict: changes requested. No blocker; six shoulds and three nits.**
The four acceptance properties hold on every seed, and each of the PR's
four planted cases is rejected; the non-vacuity floor works (a fight where
no minion ever asks is caught). What is missing is the mechanism the task
names after the revoke -- the reissue multiplier -- which works only
through a grant nobody can use (finding 1) and has no assertion of its
own (finding 2); four more mutants survive the suite (findings 3-6).

## What was reviewed

- T157, T158's opening sections, CLAUDE.md invariants 1-4 and 13,
  "Readable by a person" and the traps, `docs/howto/parallel-batch.md`,
  the records of waves 173 and 174, and
  `git diff origin/main...HEAD` (48 files, 2153 lines added).
- **Readability (invariant 1).** `check_readability.py`: ok. Longest file
  `boss_fight.gd` at 381 lines (game code; the 400 limit is for addons,
  and it is under it anyway). Static types throughout; every script opens
  with what it does, and the fight and minion with "when not to use it".
  The step's order is written as a numbered list in `boss_fight.gd:8-21`
  and the code at `:109-126` reads in that order -- good teaching shape.
- **Addon independence (invariant 2).** Nothing under `godot/addons/`
  changed; `grep -rln "Boss\|bossfight" godot/addons/`: nothing. The
  manifest's new dependencies match what the code uses (`GakGridGraph`
  ai_core, `LineOfSight` ai_perception, `ArriveBehaviour`/
  `SeparationBehaviour`/`SteeringVehicle` ai_steering, `AssetShelf` game3d,
  `Legend`/`PadAsKeys`/`Language` game_shared); `make lint-modules` ok.
  `menu` now depends on `bossfight`, as for every card.
- **Acceptance as commands (invariant 3).** All five of the task's
  commands exist and pass. The four properties are assertions inside
  `test_the_four_promises_hold_on_every_seed`. Playing it and the clip
  are under `## Manual check`, not claimed.
- **Planted cases (invariant 4).** The PR's four (forgets to hold fire,
  tokenless minions, a 16 s wait, a fight nobody can finish) are each
  rejected. The wait plant is a hand-built trace, not a fight; acceptable,
  since `left_waiting` is a pure reader.
- **Invariant 13.** The overlay carries holders, queue in serving order,
  the timer with base delay, factor and the state that set it, the three
  rings with each claim, each minion's state/ring/point/token, the boss's
  phase, state, attack, telegraph and scores, and a `director` slot. The
  data is all there; what `demo_overlays.gd` requires of it is weaker
  (finding 6).
- **pt-BR.** `bossfight.csv` covers every `tr()` key the scene and panel
  use (`make test-locale-screen` ok in pt_BR); terms the glossary keeps in
  English (`token`, `melee`, `ranged`) stay English; "{place}º na fila",
  "marcada com o jogador {state}" read naturally. Decision 6's "fallen"
  avoids the `down`/"baixo" clash -- right.
- **Authorship.** The commit is Adalberto Pereira's; its message and the
  PR's title and body carry no `Co-Authored-By`, "Generated with" or
  tooling mention (`grep -ciE` over `git log -1 --format=%B` and
  `gh pr view 134 --json title,body`: 0 and 0).

## What was run

| command | result |
|---|---|
| `make test-godot-some SUITES="test/bossfight"` | 27 cases, 0 failures; no `SCRIPT ERROR`, 0 orphans |
| `make test-demo-overlays` | 18 examples + 1 mode, 0 failures, en and pt_BR (6 `SCRIPT ERROR` lines: the planted crash's backtrace, as its header says) |
| `make test-demos-exit` | 19 scenes and modes, all closed clean |
| `make test-menu-walk` | 18 examples, 0 failures |
| `make test-locale-screen` | 18 examples and the XCOM mode in pt_BR, 0 failures |
| `make lint-modules` / `make lint-demos` | ok / ok |
| `make check-no-engine` | exit 0 |
| `make test-godot-some SUITES="test/ai_teamwork test/ai_perception test/ai_steering test/ai_core test/ai_behaviour test/ai_utility test/game3d test/game_shared"` | 199 cases, 0 failures (2 `SCRIPT ERROR`s: `ai_core/interfaces_test.gd`'s intentional abstract-class parse errors) |
| `make test-teamwork-vectors` | 59 files, 0 failures |

## Probes

A temporary `-s` script `godot/test/bossfight/zz_probe.gd` (removed with
its `.uid`), running the PR's own audit on the PR's 8 seeds:

| seed | ended | ranged grants | of which revoked at the same instant | minion bolts | longest wait (s) |
|---|---|---|---|---|---|
| 1 | won 40.6 s | 18 | 2 | 11 | 7.8 |
| 2 | won 48.0 s | 20 | 3 | 14 | 7.6 |
| 3 | won 41.1 s | 15 | 3 | 9 | 9.5 |
| 5 | won 27.8 s | 12 | 1 | 8 | 7.8 |
| 8 | won 36.2 s | 16 | 1 | 12 | 8.6 |
| 13 | won 29.6 s | 13 | 2 | 8 | 5.8 |
| 21 | won 39.2 s | 15 | 2 | 12 | 7.9 |
| 34 | won 33.8 s | 14 | 2 | 9 | 5.8 |

And the boss's own ranged token: revoked by minion pressure in 5 of the 8
fights, a `hurl` called off in seed 8; the boss started a `hurl` twice in
all eight fights.

## Mutants

Planted one at a time in place by a scratchpad script, the bossfight
suite run, the file restored after each (`git status` clean at the end):

| # | mutant | result |
|---|---|---|
| P1 | `_hold_fire` revokes nothing | caught (7 seeds fire under pressure) |
| P2 | melee minions close and strike without a token (and are never called off) | caught (over the pool) |
| P2b | ranged minions aim without a token (and are never called off) | caught |
| P3 | a ring choice of -1 is never asked again (`decide` re-chooses only while it has a point) | **survived** |
| P4a | the multipliers dropped from `token_config` | caught, **by accident**: "seed 1 did not end in 60 s" |
| P4b | `player_state()` always `free` | caught, **by accident**: the same assertion |
| P5 | a falling minion keeps its token (`hurt` does not `release(DIED)`) | **survived** |
| P5b | a falling minion keeps its ring claim | caught |
| P6 | a summon adds a full wave, not up to the wave (`- alive` dropped) | **survived** |
| P7 | ranged minions act before the melee ones and before `_hold_fire` | caught |
| P8 | pressure is only `striking`, not `winding` | caught |
| P9 | the minions decide only once, at the start | caught |
| P10 | the overlay's holders, queue and claims always "none" | **survived** the bossfight suite **and** `make test-demo-overlays` (en and pt_BR) |
| P11 | no minion ever asks for a token | caught (the non-vacuity floor: no strikes) |

## Findings

1. **Should.** `boss_fight.gd:119-122, 234-237, 257-262`, with
   `attack_tokens.gd:258-269`. The reissue multiplier is applied at a
   grant, by the player's state *then*; `revoke_kind` does not touch the
   kind's timer. And `_grant` runs before `_hold_fire`, reading the
   previous step's `pressed`. So:
   - while the player stays pressed, the pool still grants a ranged token
     whenever the timer allows, and `_hold_fire` takes it back in the same
     step, before any ranged minion acts: 16 dead grants in the 8 fights
     (probe above, 1-3 per fight). The x3 delay is set *by these dead
     grants* -- that is the only way it ever applies;
   - right after a revoke, the next ranged grant waits what the revoked
     grant set, x1 if it was granted while free, not x3. The docs' step 5
     (`docs/godot/bossfight.md:72-74`), the header (`boss_fight.gd:15-17`)
     and the card's "while you are pressed, the next ranged token waits
     three times as long" describe something else;
   - a dead grant ends a wait, so it counts as "a turn" for the fairness
     property, though the minion never got to aim; it sends that minion
     to the back of the queue (it asks again with a new `asked_at`) and
     bumps every other waiter's `passed`;
   - the "4 to 9 ranged tokens were taken back per fight" on the docs page
     counts these dead grants too.

   Proposed: decide the rule and make the code say it. Either (a) no
   ranged grant while pressed -- e.g. compute `pressed` before `_grant`
   and have the ranged minions not ask (or withdraw) while it holds, with
   the "waits three times as long" restarted from the revoke -- which may
   need a small `AttackTokens` call that restarts a kind's timer (an addon
   change with its vector and Python twin); or (b) keep the mechanism and
   correct the docs, header and card to what it does. Either way, a case:
   no ranged `GRANTED` event at a step where pressure held at the end of
   the step before.

2. **Should.** `fight_test.gd:57-72`. Nothing asserts the multiplier. P4a
   and P4b fail only because seed 1 happens to run past 60 s without it --
   a different seed list or a retuned boss would let both pass. Proposed,
   once finding 1 is settled: from `tokens.events`, every ranged grant
   that follows one made while pressed comes at least
   `delay_for("ranged", "pressed")` (6 s) after it, and at least one such
   pair exists in the runs; plant the multipliers dropped.

3. **Should.** `fight_test.gd:142-150` (P5). "A dead minion gives back its
   token" is vacuous on the token: it stops at the first death in seed 1,
   and that minion held none. The 5 s timeout then hides the leak from the
   four promises. Proposed: step until a minion falls *while holding* a
   token (or set one up: grant it, then `hurt` it to death) and assert
   `held("melee") == 0` and it is in no holder or queue list.

4. **Should.** `boss_fight.gd:169-177, 320-328` (P6). "A phase that
   summons brings the group back to the wave's size" has no case: a summon
   that adds a whole wave on top of the living passes everything. T158's
   wave cap builds on this. Proposed: in the seeded runs, alive minions
   per kind never exceed `rules.wave[kind]` at any step, and at least one
   summon happened; plant P6.

5. **Should.** `boss_minion.gd:91-101` (P3). The docs (`bossfight.md:56-59`)
   and the doc comment promise that a minion the rings give no point
   "asks again at its next decision". A minion that stops asking survives
   the suite. Proposed: a small case on `BossMinion.decide` with rings
   whose points are all claimed (choice -1), then one freed: the next
   `decide` gives it that point.

6. **Should.** `godot/test/menu/demo_overlays.gd:76-77` and
   `fight_test.gd:122-131` (P10). An overlay whose holders, queue and
   claims are always "none" passes both, in both languages: "none" pads
   every empty list (rightly, for the reader), `time` makes the overlay
   change, and `REQUIRED` names `holders`, `queue` and `claims` as
   non-numeric fields that "none" satisfies. The task's list also names
   the multiplier and the boss's phase, which `REQUIRED` leaves out.
   Proposed: add `["factor", true]` and `["phase", false]` to `REQUIRED`;
   in `fight_test.gd`, over a seeded run, assert that holders, queue and
   claims each show a real id at some step; plant P10.

7. **Nit.** `boss_fight.gd:234-237`. `last_grant[kind].state` is the
   previous step's `pressed` (one step, 33 ms, stale), while the header's
   step 3 says the delay is stretched "while the player is pressed".
   Moot if finding 1 takes (a); otherwise say "as of the last step".

8. **Nit.** `boss_fight.gd:257-262`. `revoke_kind(RANGED)` also takes the
   boss's own `hurl` token, and `BossBrain` calls the attack off (probe:
   5 fights of 8, one hurl called off; two hurls started in eight fights).
   Decision 3 explains why the boss's melee is not pressure, but not that
   the boss's ranged attack obeys the minions' pressure. Either intended
   -- say so on the docs page -- or revoke only minions' ranged tokens.

9. **Nit.** `boss_fight.gd:326-327`. A summoned wave's placement is
   seeded by `_boss_events_read`, not by the fight's seed: every seed's
   later waves stand in the same places, which narrows what the 8 seeds
   explore. Keep the fight's `RandomNumberGenerator` as a member and draw
   from it.

## The PR's decisions, judged

1. Controller and camera copied, not shared: agreed; examples depend on
   no example, and the copy is small.
2. No new model pack, `assets.json` unchanged: agreed; the boss's look is
   the owner's call, as the PR says.
3. Pressure is a melee *minion*, not the boss: agreed as design, with
   nit 8 for the converse.
4. Ranged x3, melee x1 in `boss_fight.json`: the numbers are fine; the
   mechanism they feed does not do what the docs say (findings 1, 2).
5. `Boss*` class names: agreed.
6. "fallen" for the minion's state: agreed.
7. No new make gate, `gates: []`: agreed; `affected.py` selects
   `test/bossfight/` for the module, and wave 174's review reached the
   same conclusion.
8. The scripted player wins every seed: agreed that "ends" is the
   property; the non-vacuity floor (P11 caught) keeps the other three
   from passing on a fight with no attacks.
9. The Spider-Man rule written as the request's account, unchecked:
   agreed, and the docs link `action-combat-ai.md#unchecked`.
