# Review: wave/163-boss-fight-tasks

The PR writes seven tasks and changes no code. T154-T158 are a boss fight
with minions: attack tokens and engagement rings in `ai_teamwork`, a boss
with phases and telegraphs, a 3D third-person example, and a director with
three difficulty levels. T159-T160 test the archive published on the Godot
Asset Store and stop a version from being reused. `tasks/STATUS.md` gets a
resuming section and seven rows.

A fresh context reviewed PR #121 at head f47ba9a. **Verdict: approve, no
blocker. There are eight shoulds and six nits.** All of them are in the
task text, and a wave would hit them on its first day.

## What was reviewed

- Every acceptance command, checked against the Makefile.
  `test-teamwork-vectors`, `lint-tiers`, `lint-renderer`, `lint-modules`,
  `test-demo-overlays`, `lint-demos`, `test-godot-some`, `test-python`,
  `library-check` and `lint-links` all exist. `check-published` and
  `demo-bossfight` do not exist yet. T159 says it creates the first ("It
  gets its own target") and T157 creates the second (its registration
  list).
- The order. The prerequisites chain T149 → T159 → T160 → T154 → T155 ∥
  T156 → T157 → T158, as the STATUS section says.
- Each claim about the code, read in the code:
  - `tactical_positions.gd`, `role_arbiter.gd`, `behaviour_tree.gd`,
    `state_machine.gd`, `action_choice.gd`, `difficulty.gd` and
    `infiltration/director*.gd` exist;
  - `ai_teamwork` has a Python twin (`python/gameaikit/teamwork/`) and
    vectors (`spec/vectors/teamwork/`);
  - `shooter-ai.md` describes tokens, and T52's plan for them is at its
    line 443.
- The store facts, measured at the tag:
  - the tag has 16 addons and no `ai_bayes`;
  - 23 addon files changed since `v0.1.0`;
  - `dist/game-ai-kit-addons-0.1.0.zip` is 338,507 bytes;
  - both READMEs still say "in review".
- T159's claim that `make library-check` installs three addon zips. **True:**
  `ai_core` and `ai_search` in the page's `unzip` step, and `ai_learning`
  in its `infer` step.
- The invariants in the design: 2, 4, 6, 8, 9 and 13. Invariant 6 holds:
  nothing about the player is counted, and the reissue multipliers read
  current state. Invariant 8 holds: downloads go to the toolchain and
  scratch work to a temporary folder. Every task has planted cases and
  says what is shown.
- The writing. `check_no_employer_refs.py` exits 0, `check_commit_msg.py`
  on the commit exits 0, and the commit and the PR body carry one author
  and no tooling byline.

## Findings

1. **Should. T154 names a class that does not exist, and a prefix that
   is not the house's.** The arbiter is `RoleArbiter`
   (`role_arbiter.gd:20`), not `GakRoleArbiter`. Since T64, `Gak` marks
   the ports: `GakPathfinder`, `GakGridGraph`, `GakSteeringBehaviour`,
   `GakRtsCrowd`. The addons' own classes have no prefix, so its
   neighbours are `TacticalPositions` and `RoleArbiter`.
   **Fix:** write `RoleArbiter`, and name the new class `AttackTokens`
   unless the wave makes it a port and says why.

2. **Should. T155 says `TacticalPositions` "already generates" points. It
   does not.** Its header says "It reads facts, not geometry: whoever builds
   a `Candidate` has already cast the rays", and that is why the Python twin
   needs no physics engine. A ring generator that tests line of sight
   inside `ai_teamwork` would break that design, and it would reach for
   `ai_perception` or physics (invariant 2).
   **Fix:** the generator places points only (a radius, a count, an angle
   from the camera) and returns `Candidate`s. The example fills in the facts
   (`fires_on_main` for line of sight, plus a new fact such as
   `in_front_of_camera`). The property "every ranged claim has a line of
   sight" is then stated over those facts, or moves to T157's test.

3. **Should. A cost can be larger than its pool.** T154's example pool is
   `melee: 1`, and "a heavy attack takes two". That request can never be
   granted, which breaks the task's own bound ("served within K reissues").
   T156 then says a heavy attack takes "the melee kind's whole pool", which
   is a third rule. T154 also does not say how the boss's request ranks
   against waiting minions: under longest-waiting-first the boss queues
   behind them.
   **Fix:** in T154, refuse a cost above its pool by name, as a planted
   case, or define a cost of "all". Say whether a large request blocks the
   head of the queue. Say whether a requester can have priority, which
   Dawe's chapter is said to cover.

4. **Should. T154 and T157 give two different rules for ranged attacks
   under melee pressure.** T154: "under melee pressure, the ranged kind
   waits longer", a multiplier. T157: ranged minions "lose their token when
   a melee minion is on the player", and its test says "a ranged minion
   never fires while melee pressure is on". Losing a token is a fourth way
   back that T154's three (end, interrupt or death, timeout) do not
   include, so T154's tests would not cover it.
   **Fix:** pick one rule. If it is Spider-Man's revocation, add "revoked
   by the pool's owner" to T154, with a property and a planted case, and
   drop the multiplier for that case.

5. **Should. T158's table goes against what `Difficulty` teaches.**
   `ai_planning/difficulty.gd` opens with "The usual hard AI is given more
   than the player ... That is a lie told to the player". Its levels change
   only how much the AI thinks, and `test-difficulty-knobs` holds every
   preset to `KNOBS`. T158's levels set pool sizes, minions per wave and a
   wave cap, which is giving more. So "reused if it fits" will not fit, and
   the honest outcome needs saying, not finding.
   **Fix:** T158 says that `Difficulty` is not reused, and why: in an
   action fight, difficulty is pressure within a readable limit. DOOM's
   pool size by difficulty is the precedent. T154's concept page sets the
   two ideas side by side. No knob is added to `Difficulty`.

6. **Should. T156 creates files no module owns.** T156 writes
   `godot/test/bossfight/`, but `modules/bossfight.json` first appears in
   T157's file list. `make lint-modules` refuses a file nobody owns, and
   `affected.py` would send T156's wave to a full `make check`.
   **Fix:** T156 creates `modules/bossfight.json`, depending on
   `ai_behaviour`, `ai_utility`, `ai_teamwork`, `ai_core` and `game3d`,
   and adds `make lint-modules` to its acceptance. T157 extends it.

7. **Should. T159's `make check-published` cannot go green in the case
   the task expects.** The task expects the store's file not to be the
   tag's build, and the rebuild-and-compare step reports that as a finding
   (exit 1). Measured for this review, building each commit in a clone in
   a temporary folder:
   - the tag's kit zip is 314,853 bytes, sha256 `8538106a…bbd1db`;
   - the 13 commits after the tag build between 314,853 and 338,507
     bytes;
   - none is 322.41 KB, read as 1,000 or as 1,024 bytes. The nearest are
     329,454 bytes (`f251705`, `0692b9c`) and 328,350 bytes (`d5d0a58`).

   So the store's displayed size identifies no build, and the Goal's
   "inferred from timestamps and size" is weaker than it reads: the size
   matches neither the tag's build nor `dist/`.
   **Fix:** say what `published.json` records when the file is no tag's
   build, for example `built_from` as a commit, or `null` with a note. Make
   the check's green mean "the record is true", which a mismatch the record
   admits still satisfies. Drop the size inference from the Goal.

8. **Should. T160 changes what `library-check` installs, but not the page
   it follows.** `library_check.py` runs the steps of
   `docs/techniques/using-the-library.md` as printed. It refuses a page
   whose steps differ from `STEPS`. Installing the kit zip therefore means
   editing that page in both languages, and neither is in T160's Files.
   The same page also has a live bug: its `infer` step unzips
   `ai_learning` with `-d my_game/addons/` (line 221; pt-BR line 225). That
   is the pre-T149 nesting the self-test plants for the `unzip` step. The
   addon lands in `my_game/addons/addons/ai_learning/` and passes only
   because Godot finds a `class_name` anywhere.
   **Fix:** add both pages to T160's Files. Correct the `infer` unzip.
   Check where the files land after every unzip, not only after the first.

9. **Nit. `godot_checked.py` cannot do what T159 asks of it.** It takes a
   `res://` script and runs it in the repository's own project, with no
   `--path`. T159 needs it to load every `class_name` in a fresh project
   outside the repository.
   **Fix:** name the route: either a project option on `godot_checked.py`,
   or `engine_errors` reused the way `library_check.py` runs
   `stranger.gd`. Also, `lint-links-remote` runs in CI (`ci.yml:49`), so
   it is a poor example of a target run by hand.

10. **Nit. The rebuild must use the tag's own `release.py`.** If it uses
    HEAD's, a later change to the build script reads as a mismatch.
    **Fix:** say "a clone at the tag, in a temporary folder, running its
    own `release.py`". That is what this review did.

11. **Nit. T160's refusal reaches too wide.** It refuses when HEAD differs
    from the tag "under `godot/addons/` or `python/`", and `python/` holds
    `python/tests/`, so a change to a test alone would block a release.
    **Fix:** compare only the paths `release.py` packs.

12. **Nit. T156's "no attack runs three times in a row" is a hard
    property, and a repetition penalty in a utility score is soft.** A
    strong enough attack outscores the penalty and runs a third time.
    **Fix:** say that the third repeat is filtered out (a consideration
    that scores zero), with the penalty used only for spacing.

13. **Nit. The source marking is honest, but one source carries more than
    its mark.** Dawe's chapter is marked "[F, index only; the body is
    unread]" and called "the main reference". T154 still says what the
    chapter does ("calls the naive version the 'kung-fu circle' and
    generalises it"), and its manual check compares the page to "the tokens
    chapter". The plugin also goes by two names: "Soulslike Enemy Combat
    3.2" in STATUS and the decisions, and "Soulslike Enemy AI Combat
    System" in the sources.
    **Fix:** in T154, the wave reads Dawe's chapter before confirming the
    design, and the sentence is marked as coming from its title and index.
    Use one name for the plugin.

14. **Nit. Two file lists are missing a path.** T158 adds level names to
    the example's menu, in English and pt-BR, but does not list
    `godot/locale/`. T155 adds Python properties but does not list
    `python/tests/`.
    **Fix:** add them.

Not findings:
- invariant 6, because no task counts anything about the player;
- invariant 8, because T159 downloads into `GAK_TOOLCHAIN`;
- invariant 13, because every task says what is shown;
- the [S]/[F] marks on the GDC talks, which are honest: the Vault page is
  [F] and the summary of the talk is [S].

## What was done about them

All fourteen were applied in a second commit on the branch:

- **1. Names.** `AttackTokens`, with no `Gak` prefix (ADR 0024).
  `RoleArbiter` is named correctly.
- **2. T155.** The ring generator only places points. The example fills
  in their facts, line of sight included, so the Python twin stays free of
  physics.
- **3 and 4. One rule for costs, priority and revoking.**
  - A cost above its kind's pool is refused by name, and there is a test
    for it.
  - Requests carry a priority, so the boss goes before minions already
    waiting.
  - A heavy attack costs exactly the melee pool.
  - Revoking is the fourth way a token comes back. T157 uses it for the
    Spider-Man ranged rule.
- **5. T158.** It says up front that `difficulty.gd` is not reused, and
  why.
- **6. T156.** It creates `modules/bossfight.json` and runs `lint-modules`.
- **7. T159.** `published.json` has a `provenance` field: a tag, or
  `unknown` with a sentence. The rebuild runs only for a tag, with that
  tag's own `release.py`. The goal now gives this review's measurements:
  no committed build is 322.41 KB. That replaces the earlier claim that
  git confirmed the store's file was the tag's build.
- **8. T160.** It lists the two `using-the-library` pages, fixes the
  `addons/addons/` bug, and asserts the install path.
- **Nits.**
  - T159 adds a `--project` option to `godot_checked.py`, with its own
    planted case. It no longer uses `lint-links-remote` as its example.
  - T160 compares only `python/gameaikit/`.
  - T156's rule "never three in a row" is a hard filter.
  - Dawe's chapter is marked as read only by its title and index, and the
    wave reads it first.
  - The plugin has one name.
  - The two missing paths are added.

After the review, the owner decided that 0.2.0 goes to the store only
after T154-T158 and the remaining follow-ups. That release is the new
T161, and T160 now builds the guard and uploads nothing.
