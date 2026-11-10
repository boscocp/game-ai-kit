# T159 — The published archive is tested

Size: S · Prereqs: T149 · Files: `tools/store/`, `scripts/check_published.py`, `python/tests/`, `Makefile`, `docs/howto/publish.md`

## Goal

The kit is on the Godot Asset Store
(https://store.godotengine.org/asset/boscocp/game-ai-kit/, version 0.1.0,
download 8161, 322.41 KB). No command in this repository has ever opened
that file. `make library-check` builds `dist/` from HEAD and installs
three addon zips. It tests what we would publish today, not what a
stranger downloads.

A read-only check on 2026-11-10 found that the two differ. The local
`dist/game-ai-kit-addons-0.1.0.zip` is 338,507 bytes, 13 commits after
`v0.1.0`, and has `ai_bayes`. The tag has 16 addons and no `ai_bayes`.
Both are called 0.1.0. The owner explained why on 2026-11-10, and git
agrees: the store's file was uploaded on 2026-11-07 at 00:31, from the tag.
Waves 154 to 159 then changed 23 files under `godot/addons/`:

- `ai_bayes`, a new addon;
- the tree and the forest in `ai_learning`;
- the flock rules in `ai_steering`;
- `rts_crowd.gd`;
- a fix to `llm_validator.gd`.

`dist/` was rebuilt afterwards, at 07:47. So the store file should be the
tag's build. **But the size says otherwise.** The review of wave 163
built every commit from the tag to main in a scratch clone. The tag's kit
zip is 314,853 bytes, sha256 `8538106a…bbd1db`. The later commits build
between 314,853 and 338,507 bytes. None of them is 322.41 KB, read either
as 1,000 or as 1,024 bytes. The nearest are 329,454 bytes (`f251705`) and
328,350 bytes (`d5d0a58`).

So the store's file is no committed build. It may have been built from a
working tree with uncommitted changes, or the store may repackage. Only
downloading it will say which.

*Superseded by the Result below (wave 168): the store's file is the tag's
build, byte for byte, and the page shows bytes x 1.024 / 1000 as KB.*

## Decisions written down first

_The owner asked for this check on 2026-11-10 ("valide se tá tudo ok ou
precisamos criar tarefas de teste"); the owner decided it runs before the
boss-fight batch. The rest is this session's proposal._

- **What was published is recorded in data:** `tools/store/published.json`
  holds the URL, sha256, size, version and a `provenance` field. That is
  either a tag, when the rebuild matched, or `unknown`, with a sentence
  saying what was found. One entry per upload. The sha256 is measured once by this wave, from the
  downloaded file, and written down.
- **`scripts/check_published.py` downloads into the toolchain**
  (`GAK_TOOLCHAIN`), never into the checkout or the home folder
  (invariant 8). Then it:
  - verifies the sha256 and the size;
  - lists the contents: every path under `addons/ai_*/`, LICENSE and NOTICE
    in each addon (invariant 9), and no `test`, `demo`, `gdUnit4` or
    `.toolchain` path;
  - unzips into a fresh project outside the repo, imports it headless on
    the pinned engine, and loads every `class_name` through
    `scripts/godot_checked.py`, so a `SCRIPT ERROR` fails it.
    `godot_checked.py` has no way to name a project outside the repo, so
    this task adds a `--project` option, with its own planted case;
  - when `provenance` names a tag, rebuilds the kit zip from that tag with
    **the tag's own** `release.py`, in a worktree of the tag, and compares
    sha256s. A mismatch is a finding. An `unknown` entry skips the rebuild
    and prints why, so the check can be green on the 0.1.0 file as it is.
- **Network means it is not in `make check`.** It gets its own target,
  `make check-published`, which is run by hand after each upload and
  before a release, the way `make library-check` is. Exit codes: 1 for findings,
  2 for usage or an unreachable download, kept apart.
- **Planted cases in `--self-test`**, offline (invariant 4): a zip with no
  NOTICE in one addon, a wrong sha256, a `test/` folder inside, and an
  addon whose script does not parse.
- **If the store file is not the tag's build**, the wave writes down what it
  is and asks the owner whether to upload a new version. It does not
  re-upload on its own.

## Acceptance

```bash
python3 scripts/check_published.py --self-test
make check-published
make test-python
```

## Manual check

- The owner installs Game AI Kit from the editor's AssetLib tab into an
  empty project and opens one addon's example. This closes T149's pending
  store-tab check.

## Result (wave 168)

The store's download 8161, fetched on 2026-11-10, is 314,853 bytes, sha256
`8538106aa2fa8adf21b7b2472349c26b9a83058bc5a7e2697f571424ecbbd1db`: byte
for byte the kit zip that `v0.1.0`'s own `release.py` builds, 278 entries
under 16 `addons/ai_*/` folders, each with LICENSE and NOTICE, no
`ai_bayes`. So `provenance` is `v0.1.0`, and there is nothing to re-upload.
The Goal's puzzle was the page's unit: 322.41 KB is 314,853 x 1.024 /
1,000, so no other build was ever needed to explain it.
