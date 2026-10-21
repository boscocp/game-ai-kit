# Review: wave/69-the-3d-tier

A fresh context reviewed the wave before its first push: T50 and the
acceptance of ADR 0018. It was not allowed to edit the checkout. It ran the
three gates' self-tests and plain runs, the fetcher's self-test, the floor
test headless, and `check_readability`, `check_modules`,
`check_no_employer_refs` and `check_doc_freshness`. All of them exited 0.

**Verdict: fix before merge.** Nothing was high. Four findings were medium,
and each one meant a check could not fail, or a gate had a door it did not
watch. The rest were small promises the code did not keep.

## What was reviewed

- `CLAUDE.md`, ADR 0018, the T50 task, and the whole diff against
  `origin/main`.
- The planted cases (invariant 4): does each check reject its own, and
  could a real violation pass?
- The fetcher: can it write outside its folder, or leave unchecked bytes
  where Godot reads them?
- The docs: does every claim have a test or a measurement behind it?

## Findings

Each one is followed by what was done about it.

1. **The arena's "the overlay changed" check could not fail** (medium). The
   overlay carried `turn`, which every step increments. *Fixed*: the check
   compares who sees whom over ten decisions, and is asked of the same
   sight lines twice as a planted case. Applying this fix turned up a real
   defect, and a trap now in `docs/godot/3d-headless.md`: a body moved
   through its node is in the physics space only a frame later. Ten quick
   decisions found no sight lines at all. The arena now hands each move to
   the physics server.
2. **"The cover blocks sight lines" was not held** (low). Bots blocked each
   other too. *Fixed*: a ray passes through every bot but its target, and
   an arena with its cover removed must show all 128 pairs.
3. **R6 missed a relative path, a uid and a `.tres`** (medium). *Fixed*:
   any quoted `res://game3d/`, `../game3d/` or `./game3d/` path, any uid a
   `game3d/` file is known by, and `.tres` is scanned. Each has a planted
   case.
4. **`check_no_assets.py` missed Godot's own formats and the pack's other
   files** (medium). *Fixed*: A1 adds `.res`, `.scn`, `.mesh` and the
   texture formats the kit does not use. Each pack now has a members list,
   `godot/game3d/packs/<pack>.sha256`, with the hash of every file in its
   archive, written by `fetch_assets_3d.py --list-members`. A2 holds every
   tracked file against it. A4 refuses an `ArrayMesh` or an `Image`
   embedded in a `game3d/` scene. What it still cannot see is said in its
   docstring: a texture saved again by an editor has new bytes.
5. **An empty manifest passed** (low). *Fixed*: A0, with a planted case.
6. **The archive hash was never exercised** (low). *Fixed*: planted, the
   archive committed under another name.
7. **A wrong archive put there by hand was kept** (low). *Fixed*: it is
   removed and reported, with a planted case.
8. **Unchecked bytes could land where Godot reads them** (low). *Fixed*: a
   download goes to `.part` and is renamed once it matches; a file is
   hashed in memory before it is written.
9. **A manifest missing a key gave a traceback and exit 1, `into` was
   unchecked, and `download` had no type** (low). *Fixed*: exit 2, `into`
   held inside the repository, a `Download` type.
10. **`FALLBACKS` was copied into the Python test** (low). *Fixed*: read
    from `asset_shelf.gd`.
11. **`model()` on a "none" row returned a box silently** (low). *Fixed*:
    reported with `push_error`, and still drawn so the scene loads. The
    unreadable-manifest case already reports; *not changed*.
12. **"`height` tall, standing on its origin" was not true for a model**
    (low). *Fixed*: the box is merged across the hierarchy's transforms,
    and the model is scaled and lifted inside a holder. A new check holds
    0 to 1.8 m for a primitive, and for the downloaded model where
    `make assets-3d` has run.
13. **The FPS script decided on drawn frames, not physics frames** (low).
    *Fixed*: decisions on `physics_frame`, timing on drawn frames. Measured
    again: about 1,000 fps on the 610M, against 395 when every drawn frame
    asked 128 rays. Both numbers are in the docs.
14. **"A ray from `_physics_process`"** (low). *Fixed*: the header says
    what the test does, a ray asked after `await physics_frame`.
15. **The replay check had no planted case** (low). *Fixed*: a run pushed
    1% harder must differ.
16. **The docs said every answer was held** (low). *Fixed*: a column says
    which are held and which were measured once.
17. **The README's number did not say the chip is newer than the floor**
    (low). *Fixed*.

## After the fixes

`make check-affected BASE=origin/main` selects all of `make check`
(scripts, the Makefile and `project.godot` changed). The run is in the
pull request's CI, and the merge waits for it.
