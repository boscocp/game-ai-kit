# Review: wave/122-one-seeded-generator-in-ai-core

T109: one seeded generator in `ai_core`. `Xorshift` moves from
`ai_adversarial` to `ai_core`, `gameaikit.core.Xorshift` is its Python
twin, and four copies are deleted with their twins: `Xorshift` (T86),
`MazeDice` (T97), `ParticleDraws` (T91) and `BanditDraws` (T99, which the
task did not list). The PR adds `spec/vectors/core/`, `make
test-core-vectors`, an amendment to ADR 0021, and a wheel that ships
`gameaikit.core`.

A fresh context reviewed PR #60 at head aabcf86, reading only, in a
throwaway worktree.

**Verdict: changes requested, no blockers.** No blockers, four should-fix
findings and seven nits. The code change is right. All four streams are
bit-identical to what they were, every vector runner and suite is green,
and invariant 2 holds. The findings are a vector runner that goes green
on a malformed file, an ADR amendment that ratifies two things the owner
has not decided (both contradict ADR 0024's text), a teaching
contradiction about "no algorithm", and stale references.

## What was reviewed

- The diff against `origin/main`: `ai_core/xorshift.gd` against each of
  the four deleted GDScript copies and the four deleted Python twins,
  compared line by line.
- Every caller: `mcts.gd`, `bandit.gd`, `particle_belief.gd`,
  `maze_game.gd`, `maze_ghost.gd`, and the Python `mcts`, `bandit`,
  `particles`, `maze.game` and `maze.rules`.
- `xorshift_vector.gd`, `xorshift_vectors_runner.gd`, `xorshift_test.gd`,
  `test_core_xorshift.py`, `spec/vectors/core/` (README, `derive.py`,
  JSON).
- The manifests, the Makefile, `scripts/release.py`, `pyproject.toml`,
  ADR 0021 (read against ADR 0024), the technique pages in both languages,
  the README, `docs/godot/maze.md`, the task file and the STATUS row.

Run on the head:

- `make test-core-vectors` (6 seeds), `test-adversarial-vectors`,
  `test-maze-vectors`, `test-perception-vectors`, `test-bandit-vectors`,
  `test-mdp-vectors`: all 0. No `SCRIPT ERROR` in any log.
- `make test-python`: 493 tests OK.
- `make test-godot-some SUITES="test/ai_core test/ai_adversarial
  test/ai_perception test/maze test/ai_bandit"`: 164/164. The two
  `SCRIPT ERROR`s come from the planted abstract-class parses in
  `interfaces_test.gd`.
- `git diff --exit-code origin/main -- spec/vectors/{adversarial,maze,perception,bandit}`:
  empty.
- `check_addon_deps.py`, `check_modules.py`, `check_readability.py`, and
  the lint targets (tasks, status, docs-freshness, translations-docs,
  catalogue, no-training, tiers, links, workflow, license, demos,
  employer-refs): all green. `lint-selftests` is green.
  `scripts/library_check.py` reports that the wheel and two addons ran
  outside the repository. `release.py --self-test` is ok.

Mutations, each restored afterwards (`__pycache__` cleared):

- `ai_core/xorshift.gd` with a pick of one spending a draw: core,
  adversarial and perception vectors go red. Bandit and maze stay green,
  which is expected: neither asks for a pick of one.
- `ai_core/xorshift.gd` without the mask on `<< 5`: all five families go
  red.
- `gameaikit/core/xorshift.py` without the mask on `<< 13`:
  `test_core_xorshift` fails 3 of 7.
- `modules/ai_bandit.json` and `modules/maze.json` with `ai_core` removed
  from `depends_on`: `check_modules.py` refuses each one (M3, exit 1).
  The manifests match the code.
- Parity for negative and wide seeds, measured in both languages: seeds
  -1, -5, -2^31 and 2^63-1 give 253983, 1269915, 2148024320 and 253983 in
  Godot and in Python.

Equivalence of the streams: `BanditDraws`, `ParticleDraws` and the old
`Xorshift` (both languages) are token-identical to the shared generator,
apart from comments. `MazeDice.index` differed: it had no `count <= 1`
guard, so `index(1)` spent a draw and `index(0)` divided by zero. Both
maze callers return early on one way (`maze_ghost.gd:126-131`,
`rules.py:145-160`), so `index` is only ever called with 2 or more, and
the 239 maze snapshots confirm the stream did not move.

## Findings

1. **Should-fix: the core vector runner goes green on a malformed vector.**
   `xorshift_vector.gd:26` and `:33` cast with `as Array`. On a value that
   is not an array, the cast is a `SCRIPT ERROR` that aborts
   `why_not_a_vector` and then `wrong_claims`. The runner prints "0
   failure(s)" and exits 0. This is the trap CLAUDE.md documents for `-s`
   scripts. To reproduce, write this to `<dir>/xorshift.json`:

   ```
   {"description":"x","cases":[{"seed":1,"draws":"abc","uniforms":[0.5],"picks":[],"picks_of":[]}]}
   ```

   Then run `./scripts/godot --headless --path godot -s
   res://test/ai_core/xorshift_vectors_runner.gd -- <dir>`. It exits 0
   with "core vectors: 1 seed(s), 0 failure(s)", although `uniforms`
   [0.5] is wrong for seed 1. `"cases": "x"` also exits 0.

   Fix: check types with `is Array` / `is Dictionary` and return an `X`
   reason, so the runner exits 2. Plant both files in
   `test_a_broken_vector_is_refused`. The same weakness is in the
   adversarial runner, which this PR did not write: change one case's
   `draws` in a copy of `spec/vectors/adversarial/xorshift.json` to a
   string, and `mcts_vectors_runner.gd` exits 0 with "0 failure(s)".
   That is a follow-up, under "For the owner".

2. **Should-fix: the ADR amendment ratifies two things the owner has not
   decided, and both contradict ADR 0024.** The PR body lists "keeping
   `Xorshift` without the `Gak` prefix" and "shipping `gameaikit.core` in
   the wheel" as not ratified. ADR 0021's amendment states both as settled
   Consequences, with no "put to the owner" qualifier
   (`docs/adr/0021-the-board-is-the-examples-kernel.md:99-102`). Only the
   fourth copy gets that qualifier, at line 68. ADR 0024 says:

   - "The wheel holds the Python packages owned by modules of kind
     `technique`" (`0024-the-library-prefixes-its-ports.md:58-60`; its
     title is "...and ships only techniques").
   - "The owner decided on 2026-10-20 to prefix only the ports and the
     kernel" (line 14).

   `Xorshift` is now a kernel class, and it is a name likely to collide in
   a user's project, which is the concern ADR 0024 was written for. The
   wheel change itself is necessary: the shipped `gameaikit.adversarial`
   imports `gameaikit.core`. Fix: mark both lines in ADR 0021 as T109's
   reading, pending the owner. Either add a one-line amendment pointer in
   ADR 0024, or state that ADR 0024's "technique" line is superseded once
   the owner decides.

3. **Should-fix: "no algorithm" is now false in two places, and the ADR
   says so itself.**

   - `docs/techniques/ai_core.md:15-18` and `ai_core.pt-BR.md:17` say "two
     types, one seeded generator and no algorithm".
   - `godot/addons/ai_core/grid_graph.gd:12` says "`ai_core` holds types,
     not algorithms."
   - ADR 0021's amendment, line 102, justifies the missing prefix because
     `Xorshift` "is an algorithm's name, like `AStarSearch`".

   A reader is told both things. Fix: reword the page and the header.
   What the ADR argues is "no game logic" or "decides nothing", not "no
   algorithm".

4. **Should-fix: stale references to what was deleted or changed.**

   - `spec/vectors/maze/README.md:21` names `maze_dice.gd` and
     `gameaikit/maze/dice.py`, which no longer exist. The author left it
     because the acceptance diffs the whole folder. But the acceptance
     exists to prove that no vector moved, and a README is not a vector.
     Invariant 1 wins here. Fix the line and narrow the acceptance to
     `'spec/vectors/maze/*.json'` (and the same for the others), saying so
     in the task file.
   - `scripts/check_translations_docs.py:111-112`: "ai_core is the grid
     and the pathfinder port every addon stands on".
   - `CLAUDE.md:34-35` (invariant 2): "the grid and the pathfinder
     interface, no logic". This is off the Files line, so it goes under
     "For the owner".
   - `docs/godot/maze.md:197`: the bullet "**The generator exists
     twice**" still reads as present tense. Use "existed".

5. **Nit: the Python side plants no unmasked twin.** Python's unbounded
   integers are the overflow case the module's own docstring calls the
   reason for `MASK` (`python/gameaikit/core/xorshift.py:3-5`). The
   planted twins are `SpendsOnOne` and `OneAhead` only
   (`test_core_xorshift.py:23-35`). A mutation is caught (3 of 7 fail),
   but no planted case says so. The GDScript `Unmasked` comment
   (`xorshift_test.gd:21-23`, "it keeps bits Python's twin would keep
   too") is misleading: an unmasked Python twin does not wrap at 64 bits,
   so it would differ from the unmasked GDScript too.

6. **Nit: the Python vector test does not hold X1, X2 or X5.**
   `test_core_xorshift.py:83-89` checks the case keys and the pick
   lengths. A case with `"draws": []` passes vacuously in Python. Godot's
   X5 catches it, so this is belt and braces.

7. **Nit: no negative seed in `spec/vectors/core/`.** Parity holds; see
   the measurement above. A case such as seed -1 (first draw 253983)
   would pin the two-complement masking in both languages, and it costs
   one line in `derive.py`'s `SEEDS`.

8. **Nit: "drawing exactly what each copy drew from the same seeds"**
   (ADR 0021:61-62). This is not exact for `MazeDice.index(1)`, which
   spent a draw, or `index(0)`, which divided by zero. Qualify it as
   "for every call its users make", as the PR body does.

9. **Nit: formatting.**
   - `python/gameaikit/adversarial/__init__.py:5` is a docstring line of
     about 130 characters.
   - `scripts/release.py:301-304`: after `techniques` was renamed to
     `shipped`, the comprehension's continuation lines are no longer
     aligned.

10. **Nit: the selection cost, which ADR 0021 measured, grows slightly.**
    A change to `xorshift.gd` selects 28 modules. A change to
    `grid_graph.gd` selected 26 on main and selects 28 now
    (`ai_adversarial` and `ai_bandit` added). Small, because
    `game_shared` already pulls in nearly everything. The amendment could
    say it in one line, since the original ADR was argued on exactly this
    number.

11. **Nit:** `Xorshift` has been removed from `gameaikit.adversarial` and
    `BanditDraws` from `gameaikit.bandit`. There is no release tag yet, so
    nothing breaks for users. Worth a line in the release notes if one is
    cut before the wheel is published.

## What was done about them

Every finding was applied on the branch, apart from the parts that belong
to the owner or to a follow-up, which are named.

1. `XorshiftVector.why_not_a_vector` now checks types before anything
   reads them: `cases` must be a list, each case an object, `seed` a
   number, and `draws`, `uniforms`, `picks` and `picks_of` lists of
   numbers. Anything else is refused as X6. Both of the reviewer's files
   now make the runner exit 2, naming the problem ("X6 seed 1: draws is
   not a list of numbers", "X6 its cases are not a list"), with no
   `SCRIPT ERROR`. `xorshift_test.gd` gained
   `test_a_vector_of_the_wrong_types_is_refused_before_it_is_read`, which
   plants `"cases": "x"`, a case that is a string, `"draws": "abc"`,
   `"uniforms": ["a"]` and `"seed": "1"`. `mcts_vectors_runner.gd` is
   unchanged, as asked; it goes under "For the owner" as a follow-up
   across every `*_vectors_runner.gd`.
2. ADR 0021's amendment no longer states the two points as decided. Its
   Consequences end with **"Pending the owner -- T109's reading, not
   decided"**, which quotes the ADR 0024 lines each point contradicts:
   "The wheel holds the Python packages owned by modules of kind
   `technique`" and its title, for the wheel; "The owner decided on
   2026-10-20 to prefix only the ports and the kernel", for the name. It
   says that the wheel shipping `gameaikit.core` is required while the
   shipped techniques import it. ADR 0024 gained a short "Pending (T109)"
   section that points to it. The code is unchanged. The task file's
   reading section says "pending the owner" too.
3. "No algorithm" now reads "no game logic -- nothing here decides
   anything about a game" on `docs/techniques/ai_core.md` and its pt-BR
   twin, in the intro and in "Deeper". `translation_of` is updated. The
   header of `grid_graph.gd` says `ai_core` "holds what techniques share
   and no game logic, and a search is a technique's". The amendment's
   "an algorithm's name" line went with point 2.
4. `spec/vectors/maze/README.md` names the shared generator. The
   acceptance's diff is narrowed to
   `'spec/vectors/{adversarial,maze,perception,bandit}/*.json'`, written
   out one folder at a time; the task file says why. On this head the diff
   is still empty. `check_translations_docs.py`'s comment names the
   generator. `docs/godot/maze.md` reads "existed twice". CLAUDE.md is
   unchanged, as asked; it goes under "For the owner".
5. `test_core_xorshift.py` plants `Unmasked`, a twin that cuts the seed and
   never again, so its draws grow without end; it fails the draws. The
   GDScript `Unmasked` comment now says that its high bits wrap at 64,
   that Python's would never wrap, and that Marsaglia's keeps neither.
6. The Python vector test holds X1 (the file's keys), X2 (at least four
   cases) and X5 (draws and uniforms non-empty), beside the case keys and
   the pick lengths.
7. `derive.py` gained seed -1, and `xorshift.json` now holds seven seeds;
   -1 draws 253983 first in both runners. The README's rule 2 says a
   negative seed is cut in two's complement. A Python test pins
   `Xorshift(-1)` against `Xorshift(2^32 - 1)`. Only the new core file was
   regenerated; no user's vector was.
8. The amendment now says "for every call its users make", and names the
   maze copy's two differences, a pick of one and a pick of none.
9. The docstring of `adversarial/__init__.py` is reflowed, and the
   continuation lines of `release.py`'s comprehension are aligned.
10. The amendment's Consequences give the selection cost: 28 modules for
    `xorshift.gd` and for `grid_graph.gd` now, measured with
    `affected.py --paths`, against 26 on main, as the review measured it.
11. One sentence in the PR body: `gameaikit.adversarial` no longer exports
    `Xorshift`, nor `gameaikit.bandit` `BanditDraws`, both now
    `gameaikit.core.Xorshift`. Worth a release-notes line once a wheel is
    published.

## For the owner

1. **The fourth copy, `BanditDraws`, folded in.** The reviewer agrees.
   Leaving it would make "one generator" false, and `spec/vectors/bandit/`
   is unchanged.
2. **`Xorshift` without the `Gak` prefix.** ADR 0024 line 14 says the
   kernel is prefixed. The reviewer leans to `GakXorshift`: it is a common
   name in Godot projects, and the ADR names collisions as the risk. A
   prefix is cheap now and a breaking rename after a release.
3. **The wheel ships the kernel's package.** This is necessary, because
   `gameaikit.adversarial` imports `gameaikit.core`. ADR 0024's "kind
   `technique`" line needs amending to match.
4. **`CLAUDE.md` invariant 2's wording** ("the grid and the pathfinder
   interface, no logic"). It needs the generator, or "no game logic".
5. **The adversarial vector runner** (and possibly other families) exits
   0 on a type-mangled vector (finding 1). This predates the PR. The
   reviewer suggests a follow-up task across every `*_vectors_runner.gd`.
6. **Manual check, still a person's:** read ADR 0021's amendment cold.
   Open the maze (R, a few seeds) and the MCTS example, and confirm they
   play as before. The maze vectors make a change very unlikely.
