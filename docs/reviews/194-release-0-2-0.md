# Review: wave/194-release-0-2-0

PR #153 (head `ac9b4765`), task `tasks/T161-release-0-2-0.md`. Fresh context, read-only: no make target, no Godot.

## What was reviewed

- `git diff origin/main...origin/wave/194-release-0-2-0`: `VERSION`, `python/pyproject.toml`, `tools/store/changelog-0.2.0.md`, `tasks/STATUS.md`.
- The changelog against `git diff v0.1.0 origin/wave/194-release-0-2-0 -- godot/addons python/gameaikit`. Every added file, every `class_name`, public `func`/`const`/`var` and Python `def`/`class` added or removed. The headers of the new addon files, and the bodies of every modified addon file.
- Where the version is carried: `VERSION`, the pyproject, `scripts/release.py` (`read_version`, `addon_files` stamps `addons/<addon>/VERSION` from the root file, `project_table`, the dist names), `scripts/library_check.py`, `docs/techniques/using-the-library{,.pt-BR}.md`, `tools/store/published.json`, and the READMEs.
- The STATUS upload steps against `docs/howto/publish.md` and the Makefile's `release`, `release-version`, `library-check` and `check-published` targets. The wave table's shas against `git log origin/main`.
- The STATUS rows for T124, T125, T127, T161, T165 and T166, and ADR 0024's promised `Gak` names.

## Findings

1. **blocker -- `make library-check` will fail on 0.2.0.** `scripts/library_check.py` runs every bash block of `docs/techniques/using-the-library.md` "as printed". The page hard-codes the old version in `unzip -q library/dist/ai_core-0.1.0.zip`, `ai_search-0.1.0.zip`, `ai_learning-0.1.0.zip`, `game-ai-kit-addons-0.1.0.zip` and `pip install ... gameaikit-0.1.0-py3-none-any.whl` (lines 102, 103, 171, 227, 274), and its prose says "0.1.0 today" (line 291). The pt-BR twin repeats all of it (lines 104, 105, 174, 231, 278, 296). With `VERSION` 0.2.0, `release.py --output library` writes `*-0.2.0.*`, so the unzip step fails. `library-check` is not part of `make check`, so the full check this wave runs stays green and does not see it. T161's Acceptance names `make library-check`, and publish.md lists it before the upload. Fix both pages before tagging, since docs-only changes after the tag are allowed but the tag should be what the page describes. The self-test plants in `library_check.py` (lines 519-525, 547) do `english.replace("...0.1.0...")`, so they have to move with the page. If they do not, a plant's replace becomes a no-op: the self-test either goes red, or quietly tests nothing. Read what it prints. Better still, stop the page from carrying a number at all, for example with a `$(cat game-ai-kit/VERSION)` spelling or a glob, so 0.3.0 does not repeat this.
2. **should-fix (could be called a blocker: it gets pasted into PyPI and the store) -- the changelog claims Python modules the wheel does not ship.** It lists "New: ... gameaikit.valley" and "opponent tree and forest in gameaikit.cloning". `python/pyproject.toml`'s `packages` holds neither `gameaikit.valley` nor `gameaikit.cloning`, and `release.py` builds the wheel from exactly that list (only technique and kernel manifests). Both are game packages in the repo, not part of the library. Drop both claims. `gameaikit.training` (tree and forest), `bayes`, `sifting`, `steering` and `teamwork` are shipped, so those lines are true.
3. **should-fix -- a behaviour change in `ai_llm` is missing.** Since 0.1.0, `LlmValidator` R9 (and its Python twin `gameaikit.llm.validator`) also refuses Unicode format controls (Cf: zero-width characters, bidirectional overrides, soft hyphen, tags). `SPEECH_PATTERN`, the schema handed to a constraining runtime, now excludes them, `is_refused_by_r9` is newly public, and `HttpRuntime` cleans a server's refusal with it (T139/T140). The file's own header names the price: an emoji joined by U+200D, or a Persian line that needs U+200C, is now refused. Someone upgrading whose game passed those before will see refusals. That belongs in the changelog, under "Changed".
4. **should-fix -- the `GakRtsCrowd` line overstates what ships.** "(a group moves as a flock)" describes the RTS game's `RtsFlock` (`godot/game/rts/rts_flock.gd`), which is not in the zip. The addon ships the port, a public `RtsWorld.crowd` and the base class, and the base class steps straight, exactly as 0.1.0 did. Suggested wording: "a port ... whose base walks as before; a game can put a flock there".
5. **should-fix -- what 0.2.0 promises is unsaid.** `GakRtsCrowd` is a new `Gak` port, but ADR 0024's table (ten rows, ending `GakXorshift`) does not list it. The ADR still says 0.1.0 promises nine names, and it leaves open whether `GakXorshift` is promised. The install page says the promise is "the `Gak` names above". So for 0.2.0, whether `GakRtsCrowd` (and `GakXorshift`) are promised is the owner's question. Either name it in the changelog ("prefixed, not yet promised") or add the ADR row. Nothing was renamed or removed since 0.1.0: no file deleted, no `class_name` changed, no public signature changed except Python `training.model_file.as_json`, whose type was widened. So there is no breaking change to list, and the changelog is right to list none.
6. **should-fix -- the STATUS upload steps leave out three things publish.md requires.** (a) Pushing the tag. Step 1 only checks `git describe --tags`. publish.md "Before either store" step 3 is `git tag v0.2.0 && git push origin v0.2.0`, and the after-upload step 2 writes the sha256 into "the GitHub release of its tag". The PR body says the tag is made after the merge, but STATUS does not say who makes it, or that it is pushed. (b) The sha256 in the changelog. publish.md says to write it into the store version's changelog. Step 3 says to paste the changelog from `tools/store/changelog-0.2.0.md`, which has no sha256 line. (c) `make library-check` after `make release` (publish.md step 2, and T161's Acceptance). STATUS step 2 goes straight from `make release` to `sha256sum`. The dist names in steps 2 and 4 are right: `game-ai-kit-addons-0.2.0.zip`, and `gameaikit-0.2.0-py3-none-any.whl`, which the glob matches. The twine route ("the uploader in the toolchain", `twine check` then `twine upload` with a project token) matches publish.md for a project that already exists.
7. **should-fix -- the STATUS rows contradict the new section.** The section says #149/#151 (T124) and #150 (T166) are merged. But the T124 row still ends "in review", and the T166 row still says "wave 189 (PR open) ... waits for review". The T125 row does not say it merged (#152) or that its manual check is owed. Only T127's row reads as current ("manual check owed"). All four should read: merged, PR number, `wip` until the owner's manual check. The table's shas are right: `672ce4c`, `e12e4cc`, `b0c660d`, `5e75860`, `ee38b4a` and `f855138` all match `git log origin/main`.
8. **nit -- the step 5 field list is short.** It names "download, sha256, size, `provenance`". The 0.1.0 entry and publish.md also have `store_page`, `version`, `uploaded_on` and `shown_size`, and `note` where it helps. A 0.2.0 entry should have no `known_at_exit`: any leak fails the gate, which is the point of T162.
9. **nit -- the paste instructions would be pasted.** The changelog's first three lines ("0.2.0 -- what changed ... Paste this into ...") sit in the file the owner pastes. Mark where the pasted text starts, or move the instruction into STATUS.
10. **nit -- the T161 row.** It reads "Before:  after T154-T158" (two spaces, and an awkward splice of the old text). It also lists "tag `v0.2.0`" among the wave's work, though the tag only comes after the merge.
11. **nit -- the pyproject `description` and `python/README.md` are stale.** Both still list only search, planning, fuzzy, steering, utility and perception: no Bayesian network, story sifting or teamwork. PyPI shows the README.
12. **not a finding, checked:** `VERSION` and `pyproject` both say 0.2.0. `release.py` refuses a disagreement (`project_table`) and stamps each addon zip's `VERSION` from the root file. No addon carries a `VERSION` or `plugin.cfg` of its own. (`rts_match.gd`'s `VERSION` is a recording format, not the release.) The new addons `ai_bayes` and `ai_sifting` each have LICENSE and NOTICE, and the README lists them. The descriptions of `BayesNetwork`, `SiftPattern`/`StorySifter`, `LearnedTree`/`LearnedForest`, `Flock` and its three behaviours, and `AttackTokens`/`EngagementRings` match their file headers. The "Fixed" line's 7 and 14 match `published.json`.

**What T161's Acceptance cannot hold before the upload, said plainly.** `make check` holds on the branch, but it does not include `library-check` (finding 1). `make release` and `make library-check` need the tag on main, and `library-check` fails until the page is fixed. `make check-published`, run before the upload, passes on the 0.1.0 entry alone and says nothing about 0.2.0: it holds 0.2.0 only once a later wave records the store's file. The manual check is the owner's, after uploading: installing from the editor's store tab into a blank project. So until the store serves 0.2.0 and its entry is recorded, nothing proves the uploaded file is the tag's build. T161 rightly stays `wip`.

## What was done about them

1. (blocker) The library page and its pt-BR twin name 0.2.0's files, and
   the self-test's plants with them. The first full `make check` on the
   reviewed head stopped exactly there, in `lint-selftests`
   (`library_check.py`, 17 failures: "cannot find ai_core-0.1.0.zip");
   after the fix `library_check.py --self-test` is ok and the full check
   was run again. Taking the number out of the page is left as a
   follow-up: every bump must touch it, and that is a step to remember.
2. The changelog no longer claims gameaikit.valley or gameaikit.cloning.
3. A "Changed" section names R9's refusal of format characters, its
   cost (U+200D, U+200C) and the new public is_refused_by_r9. Separators
   were already refused in 0.1.0, so they are not claimed.
4. GakRtsCrowd's line says its default steps straight, as in 0.1.0.
5. Put to the owner in STATUS ("The owner's question for 0.2.0"); the
   changelog says "not yet a promised name".
6. The upload steps push the tag (the coordinator pushes it after the
   merge), add the sha256 to the store changelog, and run library-check.
7. The T124, T125 and T166 rows say merged, with their PRs.
Nits: every published.json field is listed; the changelog's instruction
is an HTML comment above the text to paste; the double space is gone.
The pyproject description and python/README.md are left as they are.

## The full check

The second full `make check` stopped in `lint-translations-docs`: the
pt-BR library page carried the same version change as the English one,
and its `translation_of` named the old English page. The hash was set. The
third full `make check`, run alone with nothing else testing, exited 0;
its only SCRIPT ERROR lines are the planted cases of `test-demo-overlays`
and of the abstract-class checks.
