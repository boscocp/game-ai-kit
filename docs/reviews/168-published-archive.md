# Review: wave/168-published-archive

T159. The PR records the store's upload in `tools/store/published.json`
and adds `scripts/check_published.py` (`make check-published`, by hand,
not in `make check`): it downloads download 8161 into the toolchain, checks
its sha256, size and paths, unzips it into a blank project outside the
repository, imports it and loads every script through
`godot_checked.py --project` (new), then rebuilds the kit zip from the tag
the record names with that tag's own `release.py`. Its verdict: the store's
file is byte for byte `v0.1.0`'s kit zip, 314,853 bytes, sha256
`8538106a…bbd1db`, and the page's "322.41 KB" is 314,853 x 1.024 / 1000.

A fresh context reviewed PR #126 on `origin/wave/168-published-archive`,
on the owner's short list of commands only (no `make check`, no
`check-affected` that selects everything).
**Verdict: approve. The claim holds. No blocker; two shoulds and three nits.**

## What was reviewed

- The task file, `git diff origin/main...origin/wave/168-published-archive`
  (10 files), CLAUDE.md invariants 4, 8 and 9 and the traps.
- **The claim, measured independently.** `make check-published` downloaded
  `$GAK_TOOLCHAIN/store/0.1.0-8161.zip` again: `sha256sum` gives
  `8538106aa2fa8adf21b7b2472349c26b9a83058bc5a7e2697f571424ecbbd1db`,
  `stat` 314,853 bytes. 314,853 x 1.024 / 1000 = 322.409472, shown as
  322.41. A separate clone of `v0.1.0` in the scratchpad, built with
  `python3 -I scripts/release.py --build --output …`, wrote
  `game-ai-kit-addons-0.1.0.zip` with the same sha256. The download has
  278 entries under 16 `addons/ai_*/` folders and no `ai_bayes`.
- **The commands asked for.** `check_published.py --self-test`: ok, 0
  (4.7 s; the clean zip and the wrong-sha plant each load 3 scripts, 3
  class_names). `make check-published`: 0, "107 script(s) loaded and 107
  class_name(s) registered", "rebuilt from v0.1.0, byte for byte".
  `godot_checked.py --self-test`: ok, 0. `python3 -m unittest` on
  `test_check_published.py`: 8 tests, OK. `make check-no-engine`: see the
  end. No `SCRIPT ERROR` in any of their output.
- **Where the download lands (invariant 8).** `.toolchain` in this worktree
  is the link `make worktree-setup` made to `/mnt/games/gamedev/toolchain`;
  the file lands in its `store/`. Nothing new under the checkout
  (`git status` clean, `.user-data/` only, ignored), and a `find ~ -newer`
  over the run found nothing in the home; `~/.local/share/godot` does not
  exist. The blank project and the clone live in `tempfile` folders, and
  the blank project's `user://` goes through `scripts/godot`'s
  `XDG_DATA_HOME` into the checkout's ignored `.user-data/`.
- **The plants, broken one at a time** in a mutated copy of the gate
  (`scripts/zz_mut_check_published.py`, removed after): no LICENSE/NOTICE
  check -> self-test exit 1, the NOTICE plant named; the sha256 compare
  removed -> 1, the sha plant named; `test` dropped from
  `FORBIDDEN_FOLDERS` -> 1; the install skipped -> 1, the parse plant
  named; the loader run straight through `scripts/godot -s` instead of
  `godot_checked.py` -> 1, the parse plant named (so it is the output
  reading, not the exit code, that catches it, as the loader's header
  says). Three mutations stayed green: the size compare removed, the
  stray-path rule removed, the script/class_name count compare removed
  (finding 1; the stray path is held by the unit test instead).
- **Exit codes 1 and 2, on edited copies of the record** (`--record`): a
  wrong sha256 -> 1; a wrong size -> 1; an unresolvable host -> 2; a
  missing record file -> 2; a tag that is not here (`v9.9.9`) -> 2;
  `provenance: unknown` -> 0 with "no rebuild" and the note. Kept apart.
- **The rebuild uses the tag's own `release.py`.** It clones the tag into a
  temporary folder and runs `scripts/release.py` with `cwd=clone`, so the
  path resolves inside the clone; `-I` is safe because `release.py`
  imports only the standard library. `scripts/release.py` has not changed
  since `v0.1.0` (`git diff --stat v0.1.0 HEAD` is empty), so today the
  tag's and HEAD's builds cannot be told apart and the property has no
  case that could show it (part of finding 1).
- **`--project` in `godot_checked.py`.** `command_for` swaps the one value
  after `--path` in `godot_command`'s list, which has exactly one
  `--path`; the log, the wrapper and Windows' `bash` stay shared. A folder
  with no `project.godot` is refused with 2 before Godot starts. Both have
  a planted case in its `--self-test`. Sound.
- **`check_modules.py`.** `tools/` and `python/` are in `SCOPE`, so
  `tools/store/` and the new test must be owned by something. Nothing a
  module builds reads them; the test imports `scripts/check_published.py`,
  which is already global, as `test_techniques.py` is beside the registry.
  See "Not findings".
- **The stale text from wave 163** (finding 2).

## Findings

1. **Should.** Three of the gate's checks have no planted case
   (invariant 4), and one of the three is the gate's headline:
   - the **rebuild** compare: nothing feeds `rebuild_findings` a tag that
     builds a different file, so `if rebuilt != upload.sha256` could be
     `if False` and stay green;
   - the **count** compare in `install_findings` (scripts and
     `class_name`s that came up against the zip's own): removing it left
     the self-test at 0;
   - the **size** compare: removing it left the self-test at 0. It is
     reached only when the sha256 already disagrees, so it adds a second
     line to a finding that exists, not a verdict; but a check that is
     there should be one a plant can see.
   Proposed fix: unit cases in `test_check_published.py`, no network and
   no engine needed: `rebuild_findings` with `rebuilt_sha256` replaced by a
   stub returning `"1" * 64` must name "rebuild:", and with the record's
   own hash must return `[]`; `integrity_findings` on a temporary file
   with a record whose sha256 is right and size wrong must name
   "integrity: the size is"; and a self-test plant for the count, e.g. a
   `.gd` file the loader cannot see (a dot folder, if the docs for
   4.7 confirm `DirAccess` hides those by default; not measured here) so the zip's count and the
   loaded count differ. If that last one costs more than it buys, say so
   in the docstring next to the count check rather than leave it unseen.

2. **Should.** The wave 163 text that the verdict now contradicts is still
   there as present fact:
   - `tasks/STATUS.md`, top `## Resuming after 2026-11-10` section, first
     bullet of "The store check": "no committed build is 322.41 KB. So the
     store's file comes from no commit, and T159 downloads it to find out."
     This is the next session's prompt, and it tells it the opposite of
     what wave 168 measured.
   - `tasks/T159-the-published-archive-is-tested.md`, `## Goal`: "**But
     the size says otherwise.** … None of them is 322.41 KB … So the
     store's file is no committed build." The new `## Result` at the
     bottom answers it, but a reader stops at the Goal.
   - `tasks/T160-a-version-is-not-reused.md`, `## Goal`: checked, and it
     does **not** carry the claim. It says a second zip was built under
     0.1.0 "in `dist/` (see T159)", which is still true, and that store
     downloads have no hash, which is still true. Nothing to change there.
   Proposed fix: in STATUS, replace the two sentences with "the tag builds
   314,853 bytes, and wave 168 (T159) measured the store's file: it is that
   build byte for byte; 322.41 KB is the page's unit, bytes x 1.024 /
   1000." In T159's Goal, keep the history but mark it: one line after "So
   the store's file is no committed build…", "*Wave 168 answered it: it is
   the tag's build, and the page's KB is 1,000 / 1.024 bytes; see
   Result.*" STATUS is the prompt; a stale prompt is how the next session
   re-opens a closed question.

3. **Nit.** The docstring and the test call the self-test "offline", and
   it is; but it needs the engine. Without a bootstrapped toolchain
   `install_findings` raises `Unreachable`, `self_test` does not catch it,
   and `run_selftests.py` (which finds the gate by its `check_` name) gets
   exit 2 for the whole self-test. CI bootstraps before the godot job, so
   nothing breaks today. Proposed fix: say "offline, on the pinned engine"
   in the docstring's "Why `--self-test` exists".

4. **Nit.** A download id belongs to the store, not to the asset:
   `…/game-ai-kit/download/1/` (tried here while looking for a 404) served
   another asset's zip, `addons/InstanceDock/…`, with status 200. The gate
   handles it right (sha256 and contents findings, exit 1), but a typo in
   the id reads as "the store's file changed", not "wrong URL". Proposed
   fix: one sentence in `docs/howto/publish.md` step 2, "the id is the
   store's, not the asset's: copy the link from the asset's own page".

5. **Nit.** `godot_checked.py --project` passes the folder to Godot as
   given. `check_published.py` passes an absolute one, and `scripts/godot`
   does not `cd`, so a relative path works today; `.resolve()` on it in
   `main` would keep that true if the wrapper ever changes directory.

## Not findings

- **The claim.** Measured here, not read: same sha256 from the store and
  from a clean build of `v0.1.0`; 322.41 is the page's rounding of
  322.409472. The wave 163 search for a 322.41 KB commit was looking in
  the wrong unit.
- **Exit codes.** 1 for every disagreement, 2 for a record that cannot be
  read, a host that cannot be reached, no engine and a missing tag; each
  measured above. `main` maps argparse's exit to 0/2 itself.
- **An interrupted download.** `partial.write_bytes(response.read())` runs
  only after the whole body is read, and the rename only after the write,
  so a failed fetch leaves neither `.part` nor a target (an unreachable
  host left `store/` unchanged).
- **The install runs even when the sha256 disagrees.** Deliberate in
  `archive_findings`: integrity and the install are separate findings,
  and only dirty contents skip the import.
- **`tools/store/` and the test in `GLOBAL`.** The cost is that a new
  upload's record selects all of `make check`; the only waves that will
  touch it are releases (T161), which need `make check` anyway, and the
  owner of `test_check_published.py`'s subject is a script, which is
  global. `test_godot_shards.py` is owned by `botmatch` instead, but that
  script is used by one module's gates; this one is used by none.
- **Planted parse error.** `func f( -> void:` is the plant, and
  "Parse Error" is what it must name: it is found in the engine line
  `godot_checked.py` repeats, not in a path, and the zip files are
  numbered so no path carries the expected words.
- **The User-Agent** is a generic client name, nothing personal.

## Commands run

`python3 scripts/check_published.py --self-test` 0;
`make check-published` 0; `python3 scripts/godot_checked.py --self-test` 0;
`python3 -m unittest discover -s python/tests -t python -p test_check_published.py`
OK (8); `make check-no-engine` 0 (697 Python tests OK; no `SCRIPT ERROR` in its output).
