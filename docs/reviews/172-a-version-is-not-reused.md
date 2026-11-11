# Review: wave/172-a-version-is-not-reused

T160. The PR adds a refusal to `scripts/release.py`: a build into the
repository's own `dist/` (and `make release-version`, run before `export`)
refuses a `VERSION` that is already a tag `v<VERSION>` when HEAD differs
from that tag under `godot/addons/` or `python/gameaikit/`. It gives
`library_check.py` a step `kit` (the kit zip unzipped over the same
project, every addon present, the route example run again) and a path
check on `infer`, which caught the page's `-d my_game/addons/`. The READMEs
link the store page; `publish.md` covers the refusal, the store's Godot
range and the sha256 in the release notes.

A fresh context reviewed PR #132 on `origin/wave/172-a-version-is-not-reused`
(head `9a22e4b`), on the owner's short list of commands only (no `make check`).
**Verdict: approve. The guard holds on every planted case the task names.
No blocker; three shoulds and three nits. Nothing was bumped, tagged,
released or uploaded.**

## What was reviewed

- The task file, `git diff origin/main...HEAD` (9 files), CLAUDE.md
  (invariants 3, 4, 9, 11; "Readable by a person"; the traps),
  `docs/howto/parallel-batch.md`, `docs/howto/publish.md`, T159's
  `check_published.py` and `published.json`, the review record of wave 168.
- **The refusal on today's tree.** `python3 scripts/release.py
  --check-version`: exit **1**, `release: refused: VERSION 0.1.0 is already
  published as v0.1.0, and HEAD changed 39 shipped file(s) since,
  godot/addons/ai_bayes/LICENSE first: bump VERSION, in a wave, before
  releasing`. As intended: the bump is T161's.
- **`make release` order.** `release: release-version export`, and the
  Makefile has `.NOTPARALLEL:` (line 72), so the refusal really comes before
  the export even under `-j`. The build repeats it (`build`, the default
  `--output` is `REPO`), so `release.py --build` run by hand is held too.
- **The guard, planted on scratch fixture repos** (`published_fixture` plus a
  `.uid` and `python/README.md`, tagged `v0.1.0`; never the real tags):

  | plant | result |
  |---|---|
  | an addon file renamed (`git mv`) | refused, names the new path |
  | an addon file deleted | refused, names it |
  | only a `.uid` changed | refused (the `.uid` ships in the zip: correct) |
  | a `.import` added under an addon | refused (it would ship: correct) |
  | VERSION bumped to 0.2.0, `v0.2.0` already on an older commit, addon changed | refused |
  | `v0.2.0` tagged, only a docs file since | accepted (correct) |
  | annotated tag instead of lightweight | refused |
  | a branch also named `v0.1.0` | refused (`refs/tags/` is explicit) |
  | addon changed in the working tree only | accepted (the build reads HEAD: correct) |
  | `git clone --no-tags --depth 1`, and `--depth 1` with default tags | accepted (decision 2; see finding 4) |
  | only `NOTICE` / only `LICENSE` / only `python/README.md` / only `python/pyproject.toml` changed | **accepted** (finding 1) |
  | `--output .` from inside the repo, `--output` a symlink to the repo, `--output repo/dist/..` | refused for the version (`resolve()` holds) |
  | `--output repo/dist` | refused by the older rule (inside `dist/`) |
  | `--output repo/sub`, `--output ../out` | not held (decision 1, by design) |

- **Mutations of the self-test** (monkeypatched in-process, no file edited):
  `SHIPPED_SOURCES` cut to `godot/addons/` -> the self-test names the
  missing module; widened to `godot/` -> the test-only plant is refused and
  named; `refuse_a_published_version` switched off -> two failures. The
  implementer's measurements reproduce.
- **`library_check.py`'s `kit` step, planted** by rewriting the kit zip
  after the `release` step (one process per plant, `follow()` on the
  untouched English page):

  | plant | result |
  |---|---|
  | the kit wrapped in one top folder (`game-ai-kit/addons/...`) | refused, every addon named |
  | every `LICENSE` removed from the kit | refused by `licence` |
  | an extra top-level `docs/` and a `project.godot` in the kit | **accepted** (finding 3) |
  | the kit without `addons/ai_core/` | **accepted** (finding 2) |
  | the kit without `addons/ai_core/grid_graph.gd` | **accepted** (finding 2) |
  | the kit holding an `ai_zzz` no per-addon zip has | **accepted** (finding 3) |
  | `ai_bandit/LICENSE` alone removed from the kit | accepted by `licence` (pre-existing; `check_license.py` counts per folder) |
  | an `ai_dup` addon with `class_name GakXorshift` | **accepted**, no error printed (finding 2) |

- **Docs against the scripts, both languages.** The English and pt-BR
  pages say the same thing in the `release`, `infer` and `kit` steps; the
  `translation_of` hash is updated. `publish.md`'s "fails before the export"
  is true (above). The READMEs' store link matches `published.json`'s asset.
- **Authorship (invariant 11).** `git log origin/main..HEAD`: one commit,
  Adalberto Pereira, no trailer. `gh pr view 132`: author boscocp, body
  without a tooling byline.

## Findings

1. **should -- the guard watches two folders, the release ships more.**
   `scripts/release.py:123` (`SHIPPED_SOURCES`) against what the build
   reads: `LICENSE` and `NOTICE` go into every zip and the wheel,
   `python/README.md` is the wheel's METADATA body (`release.py:440`),
   `python/pyproject.toml` and `modules/*.json` shape its metadata.
   `head_archive` (`release.py:862`) already lists most of this set. Plant:
   a fixture tagged `v0.1.0` with only `NOTICE` changed -- accepted; the
   same for `LICENSE`, `python/README.md`, `python/pyproject.toml`. So a
   second, different `game-ai-kit-addons-0.1.0.zip` can still be built
   from a NOTICE edit, which is the exact harm the task names. The task
   wrote the two folders down, so this is not a defect against its letter;
   but the docstring (`release.py:37`, "a version's number names bytes")
   and the exit code line (`release.py:85`, "already published with other
   bytes") claim more than the code checks. Either widen the set to what
   the build reads (one list shared with `head_archive`) or say "the
   addons' and the package's sources" in both places.
2. **should -- the kit installed over the three addons does not test the
   kit's own copy of them, and the class_name claim does not hold.**
   `scripts/library_check.py:265-279` and decision 4. Because the kit is
   unzipped with `-o` over `ai_core`, `ai_search` and `ai_learning` already
   there, the route example that runs "again" runs on the per-addon zips'
   files. Plants: a kit without `addons/ai_core/` at all, and one without
   `grid_graph.gd`, both pass. The docstring (`:271`, "where two addons'
   `class_name` clashing would stop every script") and the PR ("which would
   catch two addons' `class_name` clashing") are not what the engine does:
   with an `ai_dup/clash.gd` declaring `class_name GakXorshift`, the import
   printed no error, `global_script_class_cache.cfg` kept
   `res://addons/ai_core/xorshift.gd`, and the route printed its marker,
   exit 0. The kit's layout is held elsewhere (`release.py`'s
   `check_the_store_installs_into_addons`, `check_license.py` per kit
   folder, `check_published.py` on the store file), so this is not a
   blocker; but the step says more than it measures. Either unzip the kit
   into a second blank project (or compare the kit's three addons against
   the per-addon zips byte for byte), and either check the class cache for
   duplicates or drop the clash sentence.
3. **should -- "nothing else is there" is only half held.**
   `scripts/library_check.py:258-262,275` and the page's kit paragraph
   (`using-the-library.md`, "every addon in `my_game/addons/<addon>/` and
   nothing else there"; pt-BR the same). The kit step does not re-run the
   `unzip` step's root check, so a kit carrying `docs/` and a
   `project.godot` (which `-o` silently wrote over the reader's project
   file) passed; and an extra `ai_zzz/` with a VERSION passes because the
   comparison is one-way (every expected addon present, not every present
   addon expected). Both are one line each: reuse `unzipped_findings`'s
   root listing, and compare the folder set to `expected` both ways.
4. **nit -- with no tags the guard is silent.** `release.py:208-214`:
   a clone without `v*` tags (`--no-tags`, or `--depth 1`, which fetches
   only tags on fetched commits) passes with no word. Decision 2 is
   reasonable, and the docstring says so; in this repository's habit (the
   forbidden-term list prints a note on every run), a one-line note when no
   `v*` tag exists at all would turn a silent pass into a visible one.
5. **nit -- long lines.** `release.py:85` (the exit-code paragraph, now
   111 characters, the rest of it wrapped at ~75) and `release.py:931`
   (the fixture dict, 124). Not gated, but the paragraph reads broken.
6. **nit -- `checked_unpublished`** (`release.py`, `--check-version`'s
   function) reads as an adjective about a thing, not what it does;
   `check_version_unpublished` or `version_refusal` would say it.

## Decisions the PR left open

1. Guard only on the repository's own `dist/`: agreed; the plants show
   `resolve()` closes the relative, symlinked and `..` spellings.
2. No tags, no guard: agreed, with finding 4.
3. `release-version` before `export`: agreed; `.NOTPARALLEL` keeps the order.
4. Kit over the same project: the reader's convenience is real, but see
   finding 2: it is why the rerun proves little about the kit.
5. Godot 4.7 to the newest offered: agreed; the owner's manual check stays.
6. sha256 in the store changelog and the GitHub release: agreed.

## What was run

On this head, after `make worktree-setup`:

- `make check-no-engine`: exit 0.
- `make lint-selftests`: exit 0 (`release.py ok`, `library_check.py ok`).
- `make test-python`: 701 tests, OK.
- `make library-check`: exit 0, "the 9 steps of using-the-library.md ran
  outside the repository"; no `SCRIPT ERROR` in its output.
- `make lint-links`: exit 0.
- `python3 scripts/release.py --check-version`: exit 1, the refusal quoted
  above.
- `python3 scripts/release.py --self-test`: `self-test: ok`, exit 0.
- `python3 scripts/library_check.py --self-test`: `self-test: ok`, exit 0.
- The plants above: scratch scripts and fixture repos in the session's
  scratchpad, outside the checkout; the real tags, `VERSION` and `dist/`
  were not touched (`git status` clean before this record). No Python
  file in the repository was edited, so no `__pycache__` could keep a
  mutant; the caches were cleared anyway.
