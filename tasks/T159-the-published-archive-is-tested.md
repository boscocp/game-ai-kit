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
Both are called 0.1.0. What the store serves is inferred from timestamps
and size, and was not verified.

## Decisions written down first

_The owner asked for this check on 2026-11-10 ("valide se tá tudo ok ou
precisamos criar tarefas de teste"); the owner decided it runs before the
boss-fight batch. The rest is this session's proposal._

- **What was published is recorded in data:** `tools/store/published.json`
  holds the URL, sha256, size, version and the tag it was built from. One
  entry per upload. The sha256 is measured once by this wave, from the
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
    `scripts/godot_checked.py`, so a `SCRIPT ERROR` fails it;
  - rebuilds the kit zip from the recorded tag and compares sha256s. A
    mismatch is reported as one, not silently accepted.
- **Network means it is not in `make check`.** It gets its own target,
  `make check-published`, which is run by hand after each upload and
  before a release, like `lint-links-remote`. Exit codes: 1 for findings,
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
