# Review: wave/19-close-the-slice

Five fresh contexts across three rounds. None of them wrote the code. Two
reviewed the first draft, one half each: `make release` with the licence gate,
and the documentation checked claim by claim against the code. Then each half
went to a new reviewer to review the *fixes*, and the release half went round
a third time. Every round found something, and the second round on the
release found that the first round's main fix had been tested in one place out
of five.

**The third round's fixes were not reviewed by a fourth context.** Each one
was checked by planting the mutation the reviewer described and watching it go
red, and that is all. It is stated here so that nobody reads this record as
saying more.

## What was reviewed

- `scripts/release.py` (new), the wheel rule and the archive rules in
  `scripts/check_license.py`, and the `release` target in the `Makefile`.
- `docs/concepts/{search,planning,learning}.md`, `docs/godot/{search,planning,learning}.md`,
  `docs/concepts/cost_models.py`, ADRs 0006-0009, and `README.md`.
- Header corrections in `dijkstra.gd`, `search.gd` and `decision_policy.gd`,
  and the docstring of `python/gameaikit/dataset/combat.py`.

## Findings

### The release shipped the working tree

`release.py` listed tracked paths with `git ls-files` and then read the bytes
off disk. A reviewer appended a marker to a tracked file and staged a new one
without committing either, and both shipped in the zip, under a docstring
saying "what ships is what was reviewed".

The fix read paths and bytes from `HEAD`. The **second** reviewer then found
that the self-test written for it planted strays in one addon and opened one
zip. Reading the wheel's package bytes, the root LICENSE and NOTICE, or the
root copies off disk all left it green. **A test of "nothing uncommitted
ships" only covers the sources it plants in and the artifacts it opens.** It
now plants in every source the build reads and opens all five artifacts and
both root copies.

### "The wheel is a wheel" checked that it was a zip that imported

No `WHEEL` file, no `Name:`, a misnamed `.dist-info`, a wrong filename tag:
each one passed the self-test and pip refused each one. `RECORD` was checked by
recomputing every row with the function that wrote it, which agrees with
itself whatever the encoding. The replacement was a cold check against the
spec. The second round found that it read headers past the blank line that
ends them, accepted `Requires-Python` on presence (including `>=3.99`), and
ignored `RECORD` rows for files that do not exist. That made five more wheels
pip refuses. **Nothing checked what an artifact held**, either: dropping every
`.gd` from the zips, or a module from the wheel, left everything green. Each
artifact is now compared with a list built from `HEAD` independently of the
build.

### The licence gate never opened a wheel, and then trusted any NOTICE

The release's own first self-test found this: five artifacts, four findings.
Across three rounds the rule then let through, in turn: a NOTICE inside the
package rather than in `.dist-info/licenses/`, a directory named `NOTICE/`,
an empty NOTICE, a dependency's `.dist-info`, a second top folder in a zip
("one top folder" was only in the prose), a link named NOTICE, a `.tar.xz`
(never opened), and a NOTICE reading `TODO`. The last needed a new rule, L10:
the attribution in an archive must be the repository's own bytes. Two ordinary
archives crashed the gate with a traceback and exit 1: a `.` member in a
tarball, and a wheel with no version in its name.

**Two of the planted cases were passing through a different rule.** Once L10
existed, every planted archive that carried `copy` as its NOTICE went red on
L10 rather than on the rule it planted. Each archive case now asserts the
finding code it expects. And one mutant this branch had called *equivalent*
was not: `zipfile` lets a directory entry carry bytes, so the "directory" case
needed data in it to tell `is_dir()` from a size check.

### The fixes, reviewed a third time

- **L10 compared against the file on disk.** A checkout whose line endings git
  converts (Git for Windows does this by default, and the repository has no
  `.gitattributes`) failed every artifact of a correct release. An edited,
  uncommitted NOTICE was blamed on archives holding exactly HEAD's copy. L10
  compares with HEAD now, and only with HEAD of the checkout `--repo` names,
  never with a checkout that happens to enclose it.
- **The "independent" content check shared the build's helpers.** If
  `committed_files` skipped `.gd` files, or `shipped_addons` returned one addon
  instead of four, the check agreed with the build, which is the defect the
  previous commit message said was now caught, moved one function down. The
  expectation now comes from `git archive HEAD`.
- **Reading content brought new crashes.** An encrypted entry, an unknown
  compression method, corrupt deflate data and a truncated `.tar.xz` each
  escaped as a traceback with exit 1. Three of them were regressions against
  the gate before that commit. They exit 2 now. A NOTICE larger than 1 MiB is
  not read.
- Members at `../` or `/` counted as an archive's one top folder (now L11).
  The list of repeatable header fields was not the specification's, and a
  folded header line was called malformed.

### Documentation that said what the code does not

- Terrain was described as reducing the damage an attacker gets through. It
  adds to the damage the defender returns. The sentence came from `combat.py`'s
  own docstring, which contradicted its code, and was copied into a concept
  page and an ADR.
- ADR 0009 described the release by the mechanism it had just replaced. ADR
  0006 said the search and the planner take a `BoardState` (they take a
  `GridGraph` and a `WorldState`) and called the RTS last, with driving after
  it. ADR 0007 told the sentinel bug as a different bug.
- The README quoted a red unit's decision as blue's, and called a demo that
  runs one search at a time "side by side".
- `docs/concepts/search.md` stated A\*'s optimality on admissibility alone.
  This A\* refuses to expand a cell twice, and that is only safe with a
  *consistent* heuristic. Manhattan distance here is one, and the page now says
  so and why.
- Two numbers had no command behind them. "1533 improvements" came from a
  scratch script. It now lives at `docs/concepts/cost_models.py`, and it prints
  1674, because the draw order changed. "About a tenth fewer" was a sixth on the
  test's own boards, and nothing prints it.

### Found while writing, before any review

- `dijkstra.gd` taught the wrong cause. It never improves a cell because a cost
  belongs to the cell *entered*, not because its frontier is a linear scan, and
  its claim that a binary heap would bring improvements back was false: 0 over
  300 boards on these costs. The wave 08 review passed this header twice.
- `decision_policy.gd` said the planner and a scripted opponent implement it.
  Neither does.
- The README listed `ai_llm` as shipping three transports. It has no code and
  no task.

## What was done about them

Every finding above was fixed on this branch, in commits 952d464, 40651b4,
84df4f4, 6606496 and fbeb2ec. Every fix except the last went back to a
reviewer that had not written it. Every release mutation a reviewer reported
surviving was re-run against its fix and is now killed, in sweeps of 26, 22
and 10 mutations that also cover each rule the fixes added. Two survivors are
left, and neither is a hole:

- dropping `create_system = 3` changes nothing on Linux, where `zipfile`
  writes 3 already, and `entries_are_fixed` would catch it on Windows;
- dropping the 1 MiB read limit leaves every verdict the same, because an
  oversized NOTICE still fails L10. The limit protects memory, and no test
  here measures memory.

Recorded rather than fixed:

- `check_license.py` reads `godot/addons/` from the working tree, so an
  untracked addon folder fails `make release` with L4 although it would not
  ship. That is conservative, and the message names the folder.
- A zip with a `__MACOSX/` folder fails the one-top-folder rule. Nothing here
  builds one.
- The Godot pages cite `docs.godotengine.org/en/stable/`, as the existing
  pages do, where `CLAUDE.md` asks for the pinned version's documentation.
  That is a convention to change for every page at once.
- `invalidated_if` is checked for presence only. No gate can test it against
  anything.
- A real third-party wheel placed in `dist/` is refused on L10, because it
  carries its own licence and not this repository's. `dist/` holds this
  repository's artifacts, so that is the intended reading, but it is a choice.
- `check_license.py` is 710 lines and `release.py` 728, most of it planted
  cases. `check_readability.py` only measures `godot/addons/`, so nothing
  holds `scripts/` to the 40-line function rule, and `check_license.py`'s
  `self_test`, at over 300 lines, breaks it.
