# Review: wave/170-karma-tasks

The PR writes four tasks and changes no code. T163 is an ADR that lets a
record of deeds persist between sessions. T164 is the deed log, the
valley's rules and the player's standing. T165 is the example: a 2D,
turn-based valley with no combat and no opponent. T166 is story sifting,
a new addon. `tasks/STATUS.md` gets an owner line, a "Next" line and four
rows.

A fresh context reviewed PR #128 at head 2b415a2 (8955657, then the
owner's standing commit). **Verdict: approve after the shoulds. No
blocker; six shoulds and five nits.** All are in the task text.

## What was reviewed

- `git diff origin/main...origin/wave/170-karma-tasks` (5 files), against
  CLAUDE.md invariants 2, 3, 4, 5, 6, 8 and 13, ADR 0016, ADR 0022,
  `scripts/check_no_training.py`'s header, `docs/godot/user-data.md` and
  "Adding an example" in `docs/godot/examples.md`.
- **The owner's rule on the game that must not be cited.** The diff and
  the four task files were searched for the name of that system, the
  game's two titles and "patent". **No hit.** The concept page's list in
  T165 (Ultima IV, Fable, KOTOR, Fallout, Elite, GTA, Hades, RimWorld,
  Dwarf Fortress, Talk of the Town) does not name it either.
- **Every acceptance command against the Makefile.** `lint-no-training`,
  `lint-selftests`, `lint-docs-freshness`, `test-godot-some`,
  `test-python`, `lint-modules`, `lint-demos`, `test-demo-overlays`,
  `test-demos-exit`, `lint-renderer`, `lint-addon-deps` and `lint-tiers`
  exist. `test-valley-vectors`, `test-sifting-vectors` and `demo-valley`
  do not exist yet. T164 and T166 list `Makefile` in their files, and
  T165 creates `demo-valley` under "Registered in full" (finding 9).
- **The order.** T163 has no prereq, and T164 → T165 → T166 each name
  the one before. T163's manual check, the STATUS owner line and the
  STATUS "Next" line all say the owner's approval of the ADR gates
  T164-T166.
- **The free numbers.** The last ADR is 0024, so 0025 is free.
  `check_no_training.py` uses N1 to N19, so N20 is free.
- **The classes the tasks name.** `GoapPlanner` (`ai_behaviour/goap_planner.gd`),
  `HtnPlanner` (`ai_behaviour/htn_planner.gd`), `AStarSearch`
  (`ai_search/astar.gd`), `ActionChoice` (`ai_utility/action_choice.gd`)
  and `GakGridGraph` (`ai_core/grid_graph.gd`) all exist. The
  infiltration director's Python twin is `python/gameaikit/director/`.
- **The quotes from ADR 0016.** "any count that survives" is at its line
  181, and "a profile outlives the match" is at line 157 (N14). ADR
  0022's "Nothing there is meant to survive" is at its line 56. T163
  cites them correctly.
- **The commands.** `make check-affected BASE=origin/main` (lints only)
  exits 0. `python3 scripts/check_status.py` exits 0.
  `python3 scripts/check_acceptance.py` exits 0 ("166 task files").

## Findings

1. **Should. Since 2b415a2, the ADR's rule contradicts itself.** T163's
   rule says "No person reads another person's state". T165 then has the
   ferryman, the merchant and the priestess read the player's standing.
   The player is a person, and the standing is about the player. As
   written, the gate N20 would have to refuse the example's own design.
   **Fix:** write the rule as what it means: "No villager reads another
   villager's state. The one thing about the player a villager may read
   is the standing, rebuilt from the record." Use the same sentence in
   T165's "No villager reads another's state".

2. **Should. The standing is a sum that outlives the session, and ADR
   0016 refuses exactly that. The ADR has to say so, not imply it.** ADR
   0016 allows counts "starting empty, never saved, rebuildable from that
   fight's or match's log", and line 181 refuses "any count that survives
   the fight". The standing is never saved, but it is rebuilt from a
   record that crosses sessions, so its value does survive. That is the
   amendment, and it is a fair one. But "N14 still holds within a match"
   does not help: the valley has no match. **Fix:** in ADR 0025, say in
   one paragraph that the standing is the one sum allowed to survive a
   session, and why it is not 0016's player model: its weights are fixed
   and authored, it estimates no skill, and it sets no difficulty. Say
   that N14 is unchanged and still reads the bot match's player-model
   files, and that N20 neither widens nor weakens it.

3. **Should. "Never sets difficulty" is not defined, and the example
   sets prices and doors.** "fear 6 → the ferryman's price ×2" could be
   read as difficulty. N20's plant "the record or the standing read to
   set difficulty" cannot be written until the line is drawn. **Fix:**
   define it in the ADR. Difficulty is any parameter keyed to an estimate
   of the player's skill: aim, reaction, an opponent's strength, a
   director's level. A consequence is an authored answer to a deed: a
   price, a door, a greeting. Make the plant read a difficulty file or
   class by name, as N14 does.

4. **Should. T163's file list misses files the ADR must change.**
   - `CLAUDE.md`: invariant 6's row and its text name ADR 0016's
     exceptions by rule (ADR 0016, lines 168-176, set that precedent).
     N20 joins them.
   - `docs/adr/0016-*.md` and `docs/adr/0022-*.md`: each gets an
     "Amended by 0025" note.
   - `Makefile`: T163 decides on a `make` target that erases the save,
     but does not name it or list the file.

   **Fix:** add all three to `Files:`, name the target (for example
   `make valley-erase`), and say which task creates it.

5. **Should. Invariant 8 for an exported build is rightly left to be
   read and measured. But the ADR must then say whether invariant 8
   covers it.** Invariant 8 says nothing this repository writes lands
   in `~/.local`. An exported valley writes its save to the player's
   `user://`, which is in the home by default. That may be the right
   place for a player's save, but it changes what the invariant means.
   `check_disk_layout.py` D1 already counts this project's `user://` in
   the home as a finding. **Fix:** in T163, say that the ADR states
   whether invariant 8 covers an exported build. If it does not, CLAUDE.md
   invariant 8 says so in one line, D1 is left as it is for the checkout,
   and `make lint-disk-layout` joins T163's acceptance.

6. **Should. T165's three-session run is prose, not a command.**
   Invariant 3: "A headless, seeded run of three sessions with a
   scripted player checks three things" has no exit code of its own.
   **Fix:** name where it lives, for example
   `godot/test/valley/test_three_sessions.gd`, so that
   `make test-godot-some SUITES="test/valley"` runs it. Or give it a
   target and add the target to the acceptance block.

7. **Nit. T164: "It is never saved and never changes at game time."**
   The standing's value changes after every deed. Its weights are what
   never change. **Fix:** "Its weights never change at game time. Its
   value is recomputed from the record after each deed, and never
   saved."

8. **Nit. `VillagerManner` is a new name, and the names note does not
   list it.** T164 says the names are a proposal the wave may change.
   **Fix:** add the same note to T165 for `VillagerManner`, and say it
   lives in `godot/game/valley/` with its data file named.

9. **Nit. Say "creates" for the three new targets.** T164 and T166 name
   `test-valley-vectors` and `test-sifting-vectors` in acceptance and
   list `Makefile`, but do not say they create them. CLAUDE.md asks that
   a new vector family name itself beside its rule. **Fix:** one line
   each, "creates `test-valley-vectors`, as `test-vectors:
   test-valley-vectors` beside its rule", and in T165, "creates `make
   demo-valley`".

10. **Nit. The italic owner paragraph is the same in all four files,
    and in T164-T166 it does not mention the standing.** The STATUS
    owner line was updated in 2b415a2, and the paragraph was not.
    **Fix:** add "and the player's standing, read from those deeds,
    sets prices and doors" to the paragraph, or keep it in full only in
    T163 and point to it from the other three.

11. **Nit. T166: say what the addon takes.** `ai_sifting` depends only on
    `ai_core` (invariant 2), but its goal says it matches over "the deed
    record". If it took a `DeedLog` it would depend on the game.
    **Fix:** "the sifter takes events as plain data (an `Array` of
    `Dictionary`); the valley passes its record in".

## Not findings

- **Deeds target places, never people.** T164's schema is
  `{day, verb, place}`. Its planted `{"target": "villager_3"}` is
  refused, and so is N20's plant. Every verb in the list acts on a place.
- **Nothing about a villager is saved.** T163's rule, T164's
  `ValleyWorld` ("never saved") and T165's three-session check all say
  so. After 2b415a2, the standing is not saved either.
- **The world is rebuilt from the record.** T164 tests it twice, and
  tests a record cut at day n. T165 checks session 3 against the
  rebuild. Time moves only while the player plays, so a run is
  deterministic.
- **A villager reads only the world's facts and its own day.** The
  signature holds it, and a test checks it (T165).
- **ADR 0022.** T163 names `.user-data/`, `git clean -fdx` and the
  sentence it amends ("Nothing there is meant to survive") for the save
  alone.
- **Invariant 13.** T165 shows two chains: deed → fact → plan → A\*
  frontier, and deeds → virtue → manner. The seeing stays under
  `## Manual check`.
- **Invariant 5.** `ai_sifting` is tier 1, and `ai_llm` at tier 3 is
  left to a later task.
- **Invariant 4.** N20 lists five planted cases, and T166 plants a
  sifter that writes.
- **Invariant 2 for the example.** T165 uses `ai_behaviour`, `ai_search`,
  `ai_utility` and `ai_core` from game code, not from an addon, and
  `modules/valley.json` declares them.
- **The sources.** Felt (Kreminski, Dickinson, Wardrip-Fruin, ICIDS
  2019), Winnow (Kreminski, Dickinson, Mateas, AIIDE 2021) and Ryan's
  2018 thesis are cited by author, venue and year.
- **The writing.** Short sentences, one term per concept. No employer
  reference. The commits carry one author and no tooling byline.
