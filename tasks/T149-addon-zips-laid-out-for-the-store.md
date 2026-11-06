# T149 — Addon zips laid out for the Asset Store

Size: M · Prereqs: T147 · Files: `LICENSE`, `python/LICENSE`, `godot/addons/ai_*/LICENSE`, `scripts/release.py`, `scripts/check_license.py`, `scripts/library_check.py`, `docs/techniques/using-the-library.md`, `docs/howto/publish.md`, `docs/adr/0009-the-release-is-built-by-hand.md`

## Goal

T147 read Godot 4.7.2's installer (`editor_asset_installer.cpp` at
`4.7.2-stable`; [docs/howto/publish.md](../docs/howto/publish.md)): a
download from the Asset Store is opened with its single top folder
**skipped**, unless that folder is `addons/`, and installed into `res://`.
Every zip `make release` builds has the top folder `ai_<name>/`, so from
the store `ai_search` lands at the project's root, and two addons collide
on `res://LICENSE`, `NOTICE`, `README.md` and `VERSION`. The store also
recommends `addons/<asset_name>/`. Until the zips change, nothing should
be submitted to the store.

## Decisions (confirmed by the owner, 2026-11-06)

The owner confirmed these on 2026-11-06 ("pode seguir o recomendado nas 5
decisões"), on the list in PR #102.

- **Every addon zip is laid out `addons/ai_<name>/...`**, with LICENSE,
  NOTICE, VERSION and the README inside `addons/ai_<name>/`. Unzipped by
  hand, it goes into the project's root, not `res://addons/`.
- **One store asset for the whole kit**, so one more zip: `addons/ai_core/`
  and every technique; the person unticks what they do not want. One
  entry, one page and one version to maintain instead of sixteen, and six
  of the fifteen techniques need `ai_core` while nothing documented lets
  one store asset declare another. The per-addon zips stay, for a person
  unzipping by hand.
- **The licence gate's archive rule moves with the layout.**
  `check_license.py` looks for LICENSE and NOTICE at an archive's root or
  in its one top folder (L5, L11). It learns `addons/<name>/` as the
  attribution's place in an addon zip, and in each of the kit zip's
  folders, and keeps refusing a member outside it.
- **A copyright line in LICENSE**, which the store asks for: the
  Apache-2.0 appendix line `Copyright [yyyy] [name of copyright owner]`
  becomes `Copyright 2026 Adalberto Pereira` in all 18 copies -- the root's,
  `python/LICENSE`, and the 16 `godot/addons/ai_*/LICENSE` -- together, so
  L26 (python/ holds the root's bytes) and L10 (each zip ships the root's)
  still hold.
- **The words that say where to unzip change with it**: the README
  `release.py` writes into each zip (`addon_readme`, the line "Unzip into
  your project's `res://addons/`"), `release.py`'s module docstring and
  `addon_readme`'s, `check_license.py`'s docstring on the archive shape,
  and `docs/techniques/using-the-library.md`'s "Unzip one addon" step.

## Steps

1. `release.py`: the new prefix, the kit zip, the README text, and
   `expected_release` and the self-test's expectations.
2. `check_license.py`: the attribution's place in the new layout, with
   planted cases -- an addon zip whose LICENSE sits at `addons/` instead of
   `addons/ai_<name>/`, a kit zip missing NOTICE in one folder, a member
   outside `addons/` -- each refused (invariant 4).
3. `library_check.py`: unzip into the blank project's root, and expect
   `res://addons/ai_<name>/`.
4. The 18 LICENSE copies, with the copyright line, in one commit.
5. `using-the-library.md`, `publish.md` (drop the warning in "The Godot
   Asset Store"), ADR 0009 (one line under the 2026-11-06 revisit).

## Acceptance

```bash
python3 scripts/release.py --self-test
python3 scripts/check_license.py --self-test
make release
make lint-license
make library-check
make lint-links lint-docs-freshness
```

## Manual check

Upload one zip as a test version in the Asset Store, install it from the
4.7.2 editor's store tab into a blank project, and see the files under
`res://addons/ai_<name>/`, nothing at `res://`.

## Notes

- Opened on 2026-11-06 from the review of wave 152 (T147, PR #102).
