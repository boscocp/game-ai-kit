# Review: wave/153-addon-zips-laid-out-for-the-store

T149 lays every addon zip out as `addons/ai_<name>/`, the one top folder
Godot 4.7.2's store installer keeps. It adds `game-ai-kit-addons-<version>.zip`
as the kit's single store asset and fills the copyright line in all 18
LICENSE copies. It also teaches the licence gate and `make library-check`
the new layout, and changes the unzip wording wherever it appears.

A fresh context reviewed PR #105 at head f9149c3. **Verdict: approve, no
blocker: one should and four nits.**

## What was reviewed

- The PR title and body, the task file and the owner's decisions in it.
- `scripts/release.py`: the new layout, the kit zip, the README text,
  `expected_release`, and the transcription of the installer's rule with
  its self-test.
- `scripts/check_license.py`: `addon_places` and its planted cases.
- `scripts/library_check.py`: the unzip check and its planted old command.
- The 18 LICENSE copies, the library page in both languages, the technique
  pages' copy sections, `publish.md`, `addon-anatomy.md` and ADR 0009.

## Findings

1. **Should.** `check_the_store_installs_into_addons` takes
   `quiet_build(...)[:-1]`, which assumes the wheel is the last artifact.
   It should select the zips by name.
2. **Nit.** `check_stale_artifacts` plants no stale kit zip.
3. **Nit.** The docstring of `addon_places` should say that the gate does
   not hold the `addons/` layout itself, because an old `ai_search/` zip
   still passes there. `release.py`'s self-test is what holds it.
4. **Nit.** Decision 1 in `publish.md` still says "so it is T149's".
5. **Nit.** The sentences superseded in `addon-anatomy.md` and in ADR
   0009's decision do not point at the later change.

## What was done about them

1. The check now keeps the `.zip` artifacts whose names start with `ai_`
   or with the kit's name.
2. A stale `game-ai-kit-addons-0.0.1.zip` is planted beside the other two,
   and the check expects it to be cleared.
3. The sentence is in the docstring.
4. It now reads "so it was T149's, and is done there".
5. Both sentences now end with "(changed in T149, below)".
