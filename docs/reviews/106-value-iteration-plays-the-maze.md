# Review: wave/106-value-iteration-plays-the-maze

T98: the maze solved as a Markov decision process in Python, in the
owner's stationary regime (Blinky alone, chasing for ever); value
iteration and policy iteration, the policy and values published to
`data/maze/` at review (since moved into `godot/game/maze/`), `MdpPacMan`
looking them up in Godot, C in `make demo-maze` handing Pac-Man to the
policy with the value map and each move's Q drawn, and N15 in
`check_no_training.py`.

A fresh context reviewed PR #48 at head 0278f70.

**Verdict: approve once S1 and S2 land; no blockers.** S1, S2, S3 and the
nits were applied on the branch.

## What was reviewed

The diff against main:

- `python/gameaikit/mdp/` (`model`, `solve`, `maze`, `publish`,
  `measure`), its tests and `spec/maze/mdp.json` with its two copies;
- the schedule added to `rules.mode_at`, `MazeRules.mode_at` and both
  games;
- the published tables, `make solve-maze`, and N15 with its self-test;
- `spec/vectors/mdp/`, its `derive.py` and README, and both runners;
- `MdpPacMan`, `MazeGhost.chances`, the demo's C mode, `MazeView`'s heat
  map and lookahead, `MazePanel`'s lines, the pt-BR table;
- `modules/maze.json`, the catalogue entry and the regenerated pages,
  `docs/concepts/mdp.md`, the maze page's section, the literature table's
  row, the STATUS row.

## What the reviewer found sound

- **The model is the game.** Measured against the real `Game` over
  20,000 random games: every visited state is in the table; 0 outcomes
  the model does not list over 12,973 (state, action) pairs; on the
  pairs played at least 30 times, the largest |z| between the model's
  probability and the observed frequency was 4.29 over about 4,000
  cells. The state is Markov in this regime.
- **The step order** is the rules': Pac-Man moves, a catch on entering
  Blinky's cell, eat and win, Blinky's committed move, a catch on his
  cell. A swap is covered by the first catch; eating and then being caught
  pays both; Blinky's chances come from the cell Pac-Man stood on when
  Blinky chose. The start state is in the table.
- **Value iteration**: the threshold is epsilon (1 - gamma) / gamma, a
  terminal is worth 0, 60 sweeps. **Policy iteration** changes an action
  only for a strictly better one, warm-starts each evaluation, and the
  page is honest about its slow start.
- **Frozen Lake** re-derived by hand: V(S) = 0.625, V(F) = 5/6.
- `derive.py` imports nothing from the repository and refuses a case
  within 0.01 of a tie.
- The Godot reader never writes; its slot arithmetic matches Python's.
- The overlay screenshots fit, and the boxed Q matches the move made.
- The concepts page is tier 1, and cites AIMA 17.2 as opened.

## Findings

1. **S1 -- the comparison flattered the MDP (should-fix).** "Won 1,000
   of 1,000, never caught" was right, but set only against a ghost-blind
   greedy controller. Never being caught is certain, not the MDP's doing:
   from the start, under the published policy, the model's catch
   probability is exactly 0 (684 states reached, none with a catch
   outcome), and every state has a move with no catch next step -- one
   ghost at the same speed, no dead ends. A safe-greedy baseline (A\* to
   the nearest pellet, refusing a move onto a cell Blinky can reach next
   step) won 1,000, caught 0, in 32.06 steps against the MDP's 30.55. The
   blind A\*'s 30.0 steps averaged its wins only.
2. **S2 -- N15 did not hold "no update at game time" (should-fix).**
   Three spellings planted in `MdpPacMan.q_value` --
   `_values[slot_of(game)] += 0.1 * (worth - ...)`,
   `_values[slot_of(game)] = worth`, and
   `_values.set(slot_of(game), ... + 0.1 * ...)` -- all passed
   `check_no_training.py --retrain N15`. The read-back net
   (`_accumulates`) catches two of them but ran only inside the inference
   addon.
3. **S3 -- C with no published tables (should-fix, small).** The person's
   game was thrown away by a restart, the mode stayed the person's, and
   nothing said why; a failed read was retried, and logged, on every call.
4. **Nits.**
   - N1: "82,160 states a game can reach": a search from the start over
     any moves and dice reaches 80,288. The list is what the rules allow.
   - N2: the greedy move over values rounded to thousandths differs from
     the unrounded one in 20 states, at most 0.0008 lost; worth stating.
   - N3: `policy_iteration` computed 6 Q-values a state per improvement
     (the greedy pass, then two more) and counted 4.
   - `CLAUDE.md`'s invariant-6 row does not name N15.

## What was done about them

1. `measure.py` gained the safe-greedy controller (its own: the greedy
   move unless the model lists a catch among its outcomes, then the first
   safe move in tie order), the mean steps over all games beside the mean
   over wins, and `catch_from_start`: the states the published policy
   reaches from the start, how many of their chosen moves could end in a
   catch (0 of 684), and how many states have no safe move at all (0 of
   82,160) -- held by a test in `test_mdp_vectors.py`. Measured: the MDP
   1,000 won, 30.5 steps; safe greedy 1,000 won, 31.9 steps (the
   reviewer's baseline, 32.06, differs only in which moves it calls risky); blind
   greedy 826 won, 30.0 over its wins, 27.0 over all games. Both pages say
   plainly that Blinky alone cannot catch a careful player here, that what
   value iteration adds is about 1.4 steps and the weighing of waiting
   against running, and answer the manual check's "does it ever walk into
   the ghost?" with the proof.
2. N15 gained `check_mdp_updates`: in the maze game and in any script
   naming `MdpPacMan`, no line outside `_load_tables` assigns to
   `_values` or `_letters` (by `=`, a compound assignment, or an in-place
   call such as `set` or `append`), and no line reads an indexed value back
   into itself -- the read-back net, there too, a declaration excepted
   (`var ways: Array[Dictionary] = [...] as Array[Dictionary]` has the
   shape and was the one false finding). Planted: the reviewer's three
   spellings, a rewrite from a script holding the reader, the loader's own
   reads (allowed) and a typed declaration (allowed). All three of the
   reviewer's plants, put into the real `q_value`, now fail the gate. The
   docstring says what is still not held: an update through a renamed
   copy of the table.
3. `MazeDemo.hand_over`: with no published tables, C leaves your game as
   it is and the status line says "C: no MDP policy published -- run make solve-maze
   first" (en and pt-BR) until the next key; a suite test
   holds it. `MdpPacMan` remembers a failed read and does not try again.
4. The nits:
   - "82,160 that the rules allow, 80,288 reachable from the start", in
     `mdp/maze.py`, both pages and the PR; a test counts both.
   - The 20 rounded states and their 0.0008 are on the concepts page.
   - Each improvement now computes the four Q-values once and compares
     with them, so the count is right; the measured table did not change
     (22 improvements, 1,233 sweeps, 106.7 million Q-values).
   - `CLAUDE.md` was not edited by the wave: a change to the standing
     instructions is left to the owner's own hand. The proposed row:
     "...; T18's cloned player is N10-N12; T98's maze policy is N15",
     keeping "half held".

The wave's runs after the fixes are in the PR body: `make solve-maze`
byte-identical, the MDP and maze Python tests, `make test-mdp-vectors`,
`test/maze` (25 cases), `check_no_training.py` and its self-test, the
overlays and locale screen, the lints, and `make check-affected`.

The reviewer's runs, at 0278f70: `make solve-maze` in 5.1 s,
byte-identical; 48 Python tests; 10 vectors; `test/maze` 7 + 17 cases;
`check_no_training.py` exit 0, N15 about 22 s under load, self-test ok;
the overlays and the locale screen, 0 failures; the lints green.
Mutations: the catch by Blinky's move removed, killed; uniform chances,
killed; the three game-time update plants survived -- S2.

## Decisions for the owner, with the reviewer's opinion

Decided by the owner, 2026-10-29: as recommended. N15 is
in `CLAUDE.md`'s invariant-6 row since wave 110.

- **Where the policy lives**: `data/maze/` was outside the Godot project,
  so an export did not carry it. The reviewer's opinion: move the two
  files into `godot/game/maze/`, as the checkers weights are. **Decided by
  the owner (2026-10-29): moved.** `make solve-maze` writes there,
  `MdpPacMan` reads `res://game/maze`, N15's folder is the maze game's,
  and `measure.py` reads the same files; the task file notes the decision
  over its "data/maze/".
- **The policy-iteration comparison** -- fewer improvements, more work,
  measured and said: fair.
- **No technique page** -- the MDP is Python and a lookup inside the maze
  game, as MENACE is: agree.
- **N15 in `CLAUDE.md`'s invariant-6 row**: yes.

## Manual check

Done by the owner, 2026-10-29: `make demo-maze` plays well, nothing to
adjust.
