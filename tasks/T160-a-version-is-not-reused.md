# T160 — A version is not reused

Size: S · Prereqs: T159 · Files: `scripts/release.py`, `scripts/library_check.py`, `python/tests/`, `README.md`, `README.pt-BR.md`, `docs/howto/publish.md`, `docs/techniques/using-the-library.md`, `docs/techniques/using-the-library.pt-BR.md`

## Goal

`make release` builds from HEAD and names the zip after `VERSION`, which
still says 0.1.0. Since `v0.1.0`, `godot/addons/` has changed in 23 files.
Nothing stops a second, different zip from being built under a version that
is already published, and that has already happened once in `dist/` (see
T159). Store downloads have no hash, so a user cannot tell the two apart.

## Decisions written down first

_The owner asked for the store validation on 2026-11-10; this session
split these follow-ups out of it. The wave confirms them._

- **`make release` refuses a published version:** when `VERSION` is
  already a tag and HEAD differs from that tag under `godot/addons/` or
  `python/gameaikit/` (not the tests: a test-only change ships nothing), it fails by name and says to bump `VERSION`. Planted case: a
  repo fixture with a tag and one changed addon file.
- **(owner) The next upload, 0.2.0, waits.** It goes out only after the
  boss-fight batch (T154-T158) and the follow-ups, as T161. This task
  builds the guard and uploads nothing.
- **`make library-check` installs the kit zip too**, all addons at once,
  and `using-the-library.md` and its pt-BR twin say so. The same pages fix a
  live bug: the `infer` step unzips `ai_learning` with `-d my_game/addons/`,
  so it lands in `addons/addons/`; it passes only because Godot finds a
  `class_name` anywhere. The check asserts the path, not just the class,
  not only three addon zips. Installing all of them together is how the
  store delivers them.
- **Small fixes found by the check:**
  - Both READMEs still say the kit is "in review at the Godot Asset Store";
    they will say it is published, with the link.
  - `docs/howto/publish.md` says to set the store's Godot version to 4.7
    and above. The page's selector offers 3.0 to 4.8.
  - The same page says to write the upload's sha256 into the release notes
    and into `tools/store/published.json`.

## Acceptance

```bash
make test-python
make library-check
make lint-links
```

## Manual check

- The owner corrects the Godot versions on the store page.
