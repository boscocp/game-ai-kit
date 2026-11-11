# Review: wave/171-save-is-a-record-of-deeds

T163. The PR writes ADR 0025 ("a save is a record of deeds, not a model of
the player"), amends ADR 0016 and 0022, adds rule N20 to
`scripts/check_no_training.py` with 14 planted cases, records where
`user://` lives in the checkout and for an export in
`docs/godot/user-data.md`, and adds `make valley-erase`
(`scripts/valley_erase.py`). The owner accepted the ADR with the
recommended decisions on 2026-11-11, so this review also asks whether
N20's fixed names and the ADR can be used as written by T164-T166.

A fresh context reviewed PR #129 on `origin/wave/171-save-is-a-record-of-deeds`
(one commit, `1ccbeaf`), on the batch's short list of commands (no full
`make check`).
**Verdict: changes requested. One blocker: N20 refuses the tests T164 is
required to write, and the ADR itself describes. Four shoulds, three nits.**

## What was reviewed

- The task file, `git diff origin/main...HEAD` (9 files), CLAUDE.md
  (invariants 3, 4, 6, 8, 12, "Readable by a person", the traps),
  `docs/howto/parallel-batch.md`, and T164, T165 and T166's task files,
  read for what they will need from N20.
- **Acceptance (invariant 3).** Every criterion in the task is a command:
  `lint-no-training`, `lint-disk-layout`, `lint-selftests`,
  `lint-docs-freshness`. The one manual check, the owner's approval, is
  recorded in the ADR's status line and in STATUS.
- **N20 on the real tree.** `check_valley(godot/)` on this checkout: 0
  findings, so no false positive on the existing game code (the tactical
  board's `deed`/`search_depth`, botmatch's `standing`).
- **N20's own plants, broken one at a time** in a copy of the script in the
  scratchpad (never in the checkout): `DEED_KEYS` widened with `target`
  and `villager` -> self-test 2 failures, both person-target plants named;
  `check_valley` removed from `run()` -> "run() never reached the valley
  check"; the beside-the-record challenge test disabled -> the search-depth
  plant named; the in-folder challenge test disabled -> the difficulty
  plant named. The PR's claim that each pattern has teeth holds for the
  four tried.
- **N20 against plants of my own**, written into a scratch repository
  beside the PR's `SOUND_VALLEY` and run through `check_valley` (script:
  the scratchpad's `plant.py`, not committed). 23 cases; the ones that
  matter are the findings below. Refused as they should be: a save written
  through a `store_string` handle from another valley file; the standing
  setting `bot_aim` on one line in botmatch. Passed as they should: an
  empty `.gd` in the valley's folder (the empty-scene question: N20 says
  nothing about an empty folder, which is right, since T164 does not exist
  yet), a future `ai_sifting` addon filtering plain `Dictionary` events,
  and a doc comment that names `user://valley/deeds.json` or shows a deed
  with a `target` key (the code view blanks it).
- **`make valley-erase` cannot leave the checkout, planted** (the
  scratchpad's `erase_plant.py`, on temporary checkouts): a redirect into
  a fake home -> refused, 1, nothing deleted (the PR's own plant); a
  `config/name` of `../../../../../outside` -> refused, 1, the outside
  folder survives (`resolve()` folds the `..`); `valley/` a symlink to a
  folder outside -> refused, 1, the target survives; `XDG_DATA_HOME` equal
  to `.user-data` itself -> erased, 0, inside. One way out: finding 4.
  On this checkout, `make valley-erase` asked `scripts/godot
  --gak-print-redirect` (`XDG_DATA_HOME=<checkout>/.user-data/xdg`),
  found no save and exited 0; a bad flag exits 2.
- **The ADR's reasoning.** The three counts for "not ADR 0016's player
  model" (authored weights, no skill estimate, no difficulty) are the
  right ones and are each held by something: N20's rules 3 and 5, and the
  record's shape. Invariant 8 not reaching a player's exported build is
  argued from what the invariant is for, and the one claim it rests on --
  `export.py` starts the exported binary under the redirect -- is true
  (`export.py`, `user_data_redirect()`, line 147). `use_custom_user_dir`
  staying off is argued from the readers of the default layout, which is
  right. The alternatives section rejects the obvious karma design (deeds
  on people) for the reason the owner gave.
- **`docs/godot/user-data.md`** cites the 4.7 data-paths page and the
  `use_custom_user_dir` property, records the six measured layouts, and
  says what was not measured (the export template itself, Windows).
  `verified_on` moved to 2026-11-11 with a new source and a wider
  `invalidated_if`.
- **Readability.** `check_valley`, `_valley_lines`, `_valley_refusal`,
  `_self_test_the_valley` and `_valley_plants` are each under 40 lines
  (`_valley_plants` 39), nesting within 3, typed, every function with a
  docstring saying what and why. `valley_erase.py` opens with what, exit
  codes and usage. `lint-readability` is in `check-no-engine` (below).
- **Authorship (invariant 11).** The commit is Adalberto Pereira's, with
  no trailer. `gh pr view 129`: title, body and commit carry no tooling
  byline, no `Co-Authored-By`, no "Generated with".

## Findings

1. **Blocker.** N20 refuses the tests T164 must write, and the test the
   ADR itself describes. `gdscript_files(root)` walks all of `godot/`,
   `godot/test/` included, and `holds_valley`
   (`scripts/check_no_training.py:758`) takes any file that names
   `ValleySave` or `DeedLog`. Planted under `godot/test/valley/`:
   - `ValleySave.new("user://tmp/deeds.json")` -> `N20 ...:3 writes,
     erases or names the save; only ValleySave does`
     (`check_no_training.py:803`). ADR 0025, line 136, says exactly this
     is how tests work: "they hand `ValleySave` a path of their own under
     `user://tmp/`".
   - `assert_bool(log.accepts({"verb": "burn", "target": "villager_3"})).is_false()`
     -> `gives a deed a key beyond day, verb and place`
     (`_gives_a_deed_a_target`, line 821). T164's task requires this very
     plant: "the test refuses a planted `{"verb": "...", "target":
     "villager_3"}`".
   - `DirAccess.remove_absolute(path)` in an `after_test`, the cleanup
     `docs/godot/user-data.md` asks every `user://` test to do -> refused
     as an erase.

   T164's acceptance includes `make lint-no-training`, so as merged T164
   cannot pass without editing N20, and the wave that writes the valley
   would then be loosening the gate that watches it -- the symmetry
   invariant 12 exists to break. Proposed fix: decide here what a test may
   do and hold it with plants. For example, in `godot/test/` (by
   `is_under`, the folder, not the name) refuses only rule 5 (a challenge
   beside the record) and rule 3's steps, and lets a test name `user://tmp/`,
   erase under it and build a deed literal with a planted key; and two
   plants: the three lines above under `godot/test/valley/` pass, and the
   same `user://` line under `godot/game/valley/` is still refused. If the
   gate should instead stay strict on tests, the ADR's line 136 and T164's
   decision must say how a test reaches a temporary save without naming
   it, and that is a decision for this wave, not the next.

2. **Should.** The schema version the ADR requires is refused in the most
   natural place to put it. The ADR's rule says the record "has a schema
   version"; `SOUND_VALLEY`'s save (`check_no_training.py:2228`) carries
   none. Planted in `valley_save.gd`, a JSON-lines record with the version
   on each line, `store_line(JSON.stringify({"version": 1, "day": ...,
   "verb": ..., "place": ...}))` -> `gives a deed a key beyond day, verb
   and place`. A header line (`{"version": 1}` alone) would pass, but
   nothing says so, and T164 learns it by crashing into the gate. Proposed
   fix: put the version in `SOUND_VALLEY` the way the ADR intends (a
   header object, or a top-level `{"version": 1, "deeds": [...]}`), and
   one sentence in the ADR's "A deed is `{day, verb, place}`" saying where
   the version lives; or add `version` to what `_gives_a_deed_a_target`
   allows in the save's own file.

3. **Should.** Rule 4 (no deed has a person as its target) sees only a
   deed written on one line. `_gives_a_deed_a_target` reads one raw line
   and needs `"verb"` and the extra key on it (`check_no_training.py:821`,
   `QUOTED_KEY_RE` line 342). Passed, beside the sound valley:
   - the same literal split one key per line (`_deeds.append({` /
     `"day": day,` / `"verb": "burn",` / `"target": "villager_3",` /
     `})`) -- the form this project's readability rules push a reader
     towards;
   - GDScript's Lua-style keys, `{day = day, verb = "burn", target = "ana"}`;
   - `deed.target = "ana"`, `deed.merge({"target": "ana"})`,
     `deeds[0]["target"] = "ana"`.
   N20 says it is a net for the common spellings, and that is fair, but
   the multi-line literal is the common spelling, and the planted case
   pins only the one-line form. Proposed fix: run the deed-literal test
   over each `{...}` span (the file already has `open_braces`), accept
   `\b(\w+)\s*=` keys inside a brace, and add `deed\w*\.\w+\s*=` and
   `deed\w*\.merge\(` to the write test; each with a plant.

4. **Should.** `make valley-erase` deletes outside the checkout when
   `.user-data` is itself a symlink. `allowed = (repo / ".user-data").resolve()`
   (`valley_erase.py:76`) follows the link, so the containment test
   compares two resolved paths that both lie wherever the link points.
   Planted: `.user-data` -> a fake home, the redirect
   `XDG_DATA_HOME=<repo>/.user-data` -> exit 0, and the home's
   `godot/app_userdata/game-ai-kit/valley/` is gone. With a link to
   `~/.local/share`, that is the exported game's real save, the one folder
   the docstring says the command must not follow the wrapper to.
   Nothing in the repository makes `.user-data` a link today, but someone
   keeping big data on another disk (as `.toolchain` already is, by
   `make worktree-setup`) would. Proposed fix: refuse when
   `(repo / ".user-data").is_symlink()` (or compare without resolving the
   `.user-data` part), with a plant in `--self-test`.

5. **Should.** N20's challenge and weight words fire on the planning T165
   is told to do in the valley's folder. In `godot/game/valley/` any
   `CHALLENGE_RE` word is refused outright (`check_no_training.py:816`,
   pattern line 358), and any assignment to a name holding `weight`
   outside `_load_weights` (line 347). Refused, as good code T165 is
   likely to write:
   - `const MAX_DEPTH: int = 6` for a villager's GOAP/HTN plan search ->
     `names a challenge parameter` (a planner's bound is not the player's
     difficulty);
   - `var reaction: String = "nod" if standing.virtue("care") > 2 else
     "scowl"` in a `VillagerManner` -> `reads the record or the standing
     to set a challenge` -- the ADR's own line 176 calls this "a person's
     reaction ... read off the standing";
   - `edge_weight = edge.length` for an A\* path between places ->
     `writes an authored weight outside _load_weights`.
   Proposed fix: narrow rule 3's weight write to `standing.gd` and to a
   `Standing`'s member (`standing\.\w*weight`), drop `reaction` (a
   villager's reaction is the consequence the ADR allows) and scope
   `max_depth`/`search_depth` in the folder to the same "beside the
   standing" line test used elsewhere; each with a plant that passes and
   the existing ones still refused. Or keep them strict and say in the ADR
   which words T165 may not use, so it renames rather than edits the gate.

6. **Nit.** The ADR's "What N20 cannot see" (line 120) lists the
   rebuild-twice and cut-at-day-n tests and the villagers' reading, but
   not two other parts of its own rule N20 does not hold: that the record
   is appended to and never edited (`valley_save.gd` may open the file
   with `FileAccess.WRITE` and truncate it; N20 allows any write there),
   and that it has a schema version. Proposed fix: name them, and who
   holds them (a T164 test that appends to a record and reads the first
   deed back unchanged; one that loads a record with an unknown version
   and is refused).

7. **Nit.** `valley_erase.py` exits 1 with a traceback where it should say
   why: no `scripts/godot` (`FileNotFoundError` from `subprocess.run`,
   line 46), a wrapper that hangs (`TimeoutExpired`), and `valley` being a
   file rather than a folder (`NotADirectoryError` from `shutil.rmtree`,
   line 83). Each planted on a temporary checkout. 1 is "refused" in the
   docstring, so a crash reads as a refusal. Proposed fix: catch the first
   two as "no redirect" (1, with the message) and `unlink` a file, or
   refuse it with a line.

8. **Nit.** Rule 1's write test inherits `WRITING_RE`'s gap:
   `func keep(cfg: ConfigFile) -> void: cfg.save(p)` in a valley file is
   not refused, because the line names neither `ConfigFile` nor `config`.
   Shared with N4 and the rest, so not this wave's to close; worth one
   word in the N20 docstring's "not a proof".

## Not findings

- **Naming the five classes and the two files before they exist.** The
  gate's constants are the ADR's names, and T164 may rename them; the
  comment above `VALLEY_GAME` says the renaming wave renames them here.
  That is the right order for a rule written before its code.
- **Reading the save from another file is refused.** A stricter reading
  than the task's "a save written by any other file", decided in the PR
  (decision 5) and argued in the ADR: the record reaches the world through
  the class that keeps it. Fine, and it is finding 1 only in `godot/test/`.
- **Outside the valley, a challenge must share a line with the standing.**
  `var fear := valley.standing.virtue("fear")` then `bot_aim = fear *
  0.1` passes. That is the net the ADR says it is, and the in-folder rule
  is the strict half.
- **No file under `python/tests/`.** The task's Files line names it; the
  PR's decision 7 explains that the plants live in `--self-test`, which
  `lint-selftests` runs (`run_selftests.py` lists `valley_erase.py ok`).
- **`git clean -fdx` deletes the save.** Accepted in ADR 0022's amendment,
  with reason: a checkout is a working copy.
- **N14 is untouched.** The diff changes no N14 constant or function.

## Commands run

`python3 scripts/check_no_training.py --self-test` 0 (ok);
`python3 scripts/check_no_training.py` 0;
`python3 scripts/valley_erase.py --self-test` 0 (ok);
`python3 scripts/valley_erase.py` 0 (no save, nothing to erase);
`python3 scripts/valley_erase.py --bogus` 2;
`python3 scripts/check_disk_layout.py` 0 (the D7 note about older
worktrees only); `python3 scripts/run_selftests.py` 0;
`make check-no-engine` 0 (lint-readability, lint-docs-freshness and
lint-disk-layout included; 701 Python tests OK; no `SCRIPT ERROR` in its
output).
Mutations were made only in a scratchpad copy of the scripts; the
checkout's `scripts/` and `python/` have no `__pycache__` left and
`git status` was clean before this record was added.
