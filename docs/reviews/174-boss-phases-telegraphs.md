# Review: wave/174-boss-phases-telegraphs

T156. The PR adds the boss's brain, headless, with no scene (T157 builds
it): `BossTable` reads `boss_attacks.json` (six attacks, three windows
each, three phases with a telegraph scale, a minimum telegraph of 0.4 s)
and refuses it whole; `BossBrain` puts the phases at the top of a
`BehaviourTree`, picks the attack with `ActionChoice` plus a code-added
"not a third time" step, and strikes with the target's `AttackTokens`;
`BossPanel` shows phase, attack, scores and a telegraph bar; a new example
module, `modules/bossfight.json`; a section of
`docs/concepts/action-combat-ai.md`.

A fresh context reviewed PR #130 on `origin/wave/174-boss-phases-telegraphs`,
on the owner's short list of commands (no `make check`).
**Verdict: changes requested. No blocker; six shoulds and three nits.**
The four acceptance properties hold and each of the task's planted cases
is rejected. What is missing is the rest of what the brain and its PR
promise: eight of eighteen mutants survived the suite (finding 2), and one
claim in the PR and in the test's shape is not what the brain does under a
game that steps the pool (finding 1). The shoulds are test cases and two
small guards, to land on the branch before the merge.

## What was reviewed

- The task (T156), T157 and T158's opening sections, CLAUDE.md
  invariants 1-4 and 13, "Readable by a person" and the traps, and
  `git diff origin/main...origin/wave/174-boss-phases-telegraphs`
  (12 files, 992 lines added).
- **The PR's seven decisions, judged.**
  1. The tree instead of an HFSM: agreed; the selector reads like the
     task's sentence, and the "mid-attack" branch is honest about the tree
     keeping no memory.
  2. No phase skipped: the property holds, but the sentence "enters them on
     consecutive decisions" is false once the pool is stepped (finding 1).
  3. The filter added in code, streak across phases: agreed; stricter than
     the task, and `_why_third_in_a_row` still checks the task's
     within-phase form.
  4. The token kept through recovery, lost token calls the attack off:
     agreed as design; the call-off has no case (finding 2).
  5. No randomness in the boss: agreed; the other-seed assertion keeps the
     determinism test from passing vacuously.
  6. Priority yields to T154's patience: agreed, and the concept page says
     so; but priority itself is untested (finding 2).
  7. Keren 2018 not cited because unread: correct under the task's [S]
     rule.
- **Readability (invariant 1).** `check_readability.py`: 0. By eye: the
  longest function is `_choose_in` (19 lines), nesting at most 2, all
  three files under 400 lines (brain 308), static types throughout, every
  public function documented with what and why. Each script opens with
  what it solves, and the brain and table with "when not to use it"; the
  brain gives its complexity. `BossPanel._init` has no doc comment, which
  the gate accepts for a constructor.
- **Addon independence (invariant 2).** The brain uses `ai_behaviour`,
  `ai_teamwork` and `ai_utility`, all declared in `depends_on`;
  `make lint-modules` ok. Nothing under `godot/addons/` changed.
- **Acceptance as commands (invariant 3).** Both are commands with exit
  codes: `make test-godot-some SUITES="test/bossfight"` and
  `make lint-modules`. The four properties are each an assertion inside
  `test_every_seeded_fight_keeps_the_promises` over 8 seeds. The dodge is
  under `## Manual check`, as it must be. The module's `gates: []` is
  correct: `affected.py` runs a module's owned suite folders without a
  named gate.
- **Planted cases (invariant 4).** The task's two (zero telegraph, phase
  never met) are each rejected twice, at the table and in a fight forced
  past it, plus a filterless brain. Good shape.
- **Authorship.** The one commit is Adalberto Pereira's; neither its
  message nor the PR's title and body carry a `Co-Authored-By`, a
  "Generated with" line, or a mention of the tooling (grep over
  `git log -1 --format=%B` and `gh pr view 130 --json title,body`: empty).

## Probes

A temporary suite `godot/test/bossfight/zz_review_probe_test.gd` (removed,
with its `.uid`, before this record):

- **A hit past two thresholds, with the pool stepped between decisions**
  (as `decide`'s doc comment says the game does): health 1.0 to 0.1
  right after the first decision. Events, in order: `stone` at 0.0,
  `swipe` in stone at 0.1, **`cracked` at 1.7, `swipe` in cracked at
  1.8 (telegraph 0.51), `molten` at 3.3**, then `quake`. See finding 1.
- **`shown()` on a brain whose table was refused** (a zero telegraph):
  `SCRIPT ERROR: Invalid access to property or key 'trail' on a base
  object of type 'Nil'` at `boss_brain.gd:138`, and an empty dictionary
  back. See finding 3.

## Mutants

Planted one at a time in place by a scratchpad script, the bossfight
suite run, the file restored after each (`git status` clean at the end,
`git diff` empty):

| # | mutant | result |
|---|---|---|
| M1 | `and phase >= index - 1` dropped (phase order) | caught |
| M2 | the tree asks the phases first to last | caught |
| M3 | `MOST_IN_A_ROW` 2 -> 3 | caught |
| M4 | the step's `at` one higher (filter on a fourth use) | caught |
| M5 | the streak never counts (`_streak = 1`) | caught |
| M6 | the table's minimum-telegraph check removed | caught |
| M7 | the phase's telegraph scale ignored at play (`_start` uses the raw telegraph) | **survived** |
| M8 | a heavy attack costs 1 | caught |
| M9 | a heavy attack costs the pool minus one | caught |
| M10 | the token not released when recovery ends | caught |
| M11 | a lost token does not call the attack off | **survived** |
| M12 | the fall does not release (or unqueue) the boss | **survived** |
| M13 | `_enter` neither withdraws nor releases | **survived** |
| M14 | the boss requests with priority 0, not the table's | **survived** |
| M15 | the first phase may start below 1.0 | **survived** |
| M16 | a threshold of 0 accepted | caught |
| M17 | a window of zero accepted (`seconds < 0.0`) | **survived** |
| M18 | the active window skipped (telegraph straight to recovery) | **survived** |

The PR's own four mutants are M1, M4, M6 and M8 here, and they are caught
as it says.

## Findings

1. **Should.** `boss_brain.gd:243-244`, PR decision 2, and
   `boss_test.gd:217-227`. The PR says a burst of damage across two
   thresholds "enters them on consecutive decisions". It does only when
   no token is granted in between. The probe above, with `tokens.step`
   between decisions, shows the boss at 10% health finishing its stone
   swing, entering `cracked`, **running a whole attack in cracked** (1.5 s),
   and only then entering `molten`: two phase events 1.6 s apart, each
   with `summon: true`, for one hit. The test that holds the property
   never calls `tokens.step`, so the request never becomes a token and the
   case that differs is never run. "Each phase once, in order" still
   holds; the claim, and possibly the design, do not. Either (a) keep the
   behaviour, correct decision 2 and the concept page's wording, and make
   the test step the pool and assert what it now does; or (b) let a phase
   whose next threshold is already met enter the next one without
   choosing an attack (a loop in `_choose_in`, or `_phase_opens` asking
   whether the later phase is also open), and test that with the pool
   stepped. T158's director reads these events, so which one it gets is
   worth deciding now; (b) is what "a big hit" reads like to a player.

2. **Should.** Eight mutants survive (table above). Each is a behaviour
   the code, its comments or the PR states, with no case:
   - **M18, M17: the three windows.** Nothing checks that an attack goes
     telegraph, active, recovery, or that `hurts()` is ever true; and a
     zero `active` or `recovery` window is refused by
     `boss_table.gd:128-131` but no plant shows it (the zero-telegraph
     plant is caught by the minimum check instead, so M17 lives).
     Proposed: in the seeded fight record each state the boss is in at
     each step and assert every attack passes TELEGRAPH, ACTIVE, RECOVERY
     in that order; plant `active: 0` and `recovery: 0` and assert the
     refusal names the window.
   - **M7: faster tells.** The phase's `telegraph_scale` is the task's
     "faster tells" and nothing checks it is applied. Proposed: assert an
     attack used in two phases (`swipe`, stone and cracked) has
     `telegraph` events equal to `telegraph_of` in each.
   - **M14: the boss's priority.** The task names it ("puts it before
     minions already waiting", "this is why T154 has costs and
     priorities"). Proposed: a pool with one melee token held by a minion
     and another minion waiting; the boss asks; on release the boss is
     granted first.
   - **M11: the call-off** (PR decision 4). Proposed: `revoke_kind("melee")`
     during the boss's telegraph; the next decision logs `called_off` and
     `hurts()` is never true for that attack.
   - **M12: the fall.** A boss that dies holding or waiting for a token
     must give it back (T154: "held + free must equal the pool").
     Proposed: kill it mid-attack and assert `tokens.held("melee") == 0`
     and the boss is not in the queue.
   - **M13, M15**: see nits 7 and 8.

3. **Should.** `boss_brain.gd:131-139`. `shown()` on a brain whose table
   was refused dereferences a null `tree` (probe above: `SCRIPT ERROR`,
   and the typed function returns `{}` -- the trap the CLAUDE.md
   describes). T157 feeds the panel once a frame, so a bad table becomes
   one engine error a frame instead of a refusal on screen. Proposed:
   return `{"phase": "", "state": "", "attack": "", "telegraph": 0.0,
   "reasons": [], "trail": [], "refusal": refusal}` when `refusal != ""`,
   and let the panel show the refusal; one test.

4. **Should.** `boss_test.gd:217-227`. Besides finding 1, the test
   asserts only the phase list and the fall, after a fixed four ticks.
   Once finding 1 is decided, it should assert the times (or the absence
   of an attack) between the phase events, which is what a reader of
   "a big hit still enters every phase" will expect it to prove.

5. **Should.** `boss_brain.gd:85-88, 260`. The heavy cost is
   `_pools[kind]`, from a dictionary passed beside the pool rather than
   read from it. Hand the brain a `pools` that differs from the pool's
   config (T158 will build both from a difficulty table) and a heavy
   attack silently costs less than the pool, or is refused as
   `REFUSED_COST` and the boss waits for ever. Proposed: read the size
   from the pool itself (`free_tokens(kind) + held(kind)`, which T154
   guarantees equals the pool), or refuse in `_why_not_fight` when
   `_pools` disagrees with it; plant the disagreement.

6. **Should.** `boss_test.gd:10-201`. The fights take 8 seeds x at most
   600 s at 0.1 s, but the suite runs them in 59 ms: the player's
   0.01-0.02 damage ends each fight in seconds of simulated time. That is
   fine, but `assert_int(sim.attacks().size()).is_greater(len(table.phases) * 2)`
   is the only floor, so a seed where molten gets one attack still passes
   the "never three in a row" property in molten trivially. Proposed:
   assert at least three attacks in every phase for every seed (or say
   in the comment why fewer are enough).

7. **Nit.** `boss_brain.gd:270-273` (M13). `_enter`'s withdraw and
   release are unreachable as written: `_choose_in` runs only when the
   mid-attack branch failed, so the boss holds nothing, and a request of
   another kind already withdraws the old one in `AttackTokens.request`.
   Keep them as a guard if you like, but say so in the comment, or
   remove them.

8. **Nit.** `boss_table.gd:148-149` (M15). "The first phase must start at
   1.0" has no planted case. One line in `test_a_phase_never_met_is_refused`.

9. **Nit.** `boss_panel.gd:35-36`. The heading and state go through
   `tr()`, but `bossfight` has no `godot/locale/bossfight.csv` yet, so
   they are keys with no table. `check_translations_game.py` passes
   because an untranslated module is out of its scope. T157 should add
   the table when it adds the scene; worth a line in T157.

## Not findings

- **The 143 leaked ObjectDB instances** at the end of the bossfight run.
  `make test-godot-some SUITES="test/ai_behaviour"` prints the same 143
  on this branch, where `ai_behaviour` is unchanged from main; it is the
  behaviour tree's, as the PR says, and T157's exit-leak gate will meet
  it.
- **The mid-attack branch before the phase branches.** A phase change
  waits for the swing to end. That is the commitment the tree's comment
  states, and the swing is at most `longest_attack()` (3.2 s).
- **`longest_attack()` uses the unscaled telegraph.** Every scale is in
  (0, 1], refused otherwise, so the unscaled one is the longest.
- **Re-choosing while waiting.** A different attack of another kind or
  cost withdraws the old request (`AttackTokens.request`), so the token
  the boss is granted always matches `attack`.

## Commands run

All on `review/174` (= the wave's head, `3f43782`), after
`make worktree-setup` and `./scripts/godot --headless --path godot --import`
(0):

- `make test-godot-some SUITES="test/bossfight"`: 0; 11 cases, 0 failures,
  no `SCRIPT ERROR`; 143 ObjectDB instances leaked at exit (see above).
- `make test-godot-some SUITES="test/ai_teamwork"`: 0 (16 + 2 + 10 cases);
  `test/ai_behaviour`: 0 (2), 143 leaked as above; `test/ai_utility`: 0
  (2 + 3). No `SCRIPT ERROR`.
- `make lint-modules`: ok, 41 modules. `make lint-demos`: ok, 17
  examples. `make test-game3d-floor`: 0 failure(s).
- `make check-no-engine`: 0 (701 Python tests OK, twice).
- `python3 scripts/check_readability.py`: 0.
  `python3 scripts/check_translations_game.py`: 0.
- The probe suite and the 18 mutants above.
