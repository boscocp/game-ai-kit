# T50 — The 3D tier, measured before anything is built

Size: M · Prereqs: ADR 0018 · Files: `godot/game3d/`, `scripts/check_renderer.py`, `scripts/check_no_assets.py`, `docs/godot/`, `Makefile`, `README.md`

## Goal

ADR 0018 proposes how 3D enters the kit, and almost everything it leans on
was read rather than measured: whether 3D physics, ray casts and navigation
run under `--headless`; whether a physics run replays identically on the
pinned binary; what frame rate the Compatibility renderer holds on
integrated graphics; what an asset pack's archive really contains. This
task measures those first -- the order CLAUDE.md asks for -- and builds only
the floor the three 3D examples (T51, T52, T54) stand on.

Nothing here is AI. It is the gates and the plumbing, kept small so that the
examples after it are about their bots.

**Blocked until the owner accepts ADR 0018** (or picks another option; this
task is then rewritten to match).

## Steps

1. **Measure, in a scratch scene under `godot/game3d/`**, headless through
   `./scripts/godot`: a `RigidBody3D` dropped on a floor comes to rest; a ray
   cast from `_physics_process` hits a box and misses past it; a navmesh
   baked from collision shapes gives a path round a wall; and a `game3d/`
   scene with a `Legend`, `step_decision()` and `decision_overlay()` loads
   in `demo_overlays.gd` headless -- if it does not, invariant 13's gated
   half fails for every 3D example. Each answer goes
   in `docs/godot/3d-headless.md` with the docs URL and `verified_on`.
2. **Replay.** Run the same drop and a car-like body twice and compare
   positions frame by frame. Write down whether it is identical, and if not,
   the largest difference -- the number later tolerances are stated in.
3. **Frame rate.** A test scene of the size T51 needs (16 capsules, a
   blocky arena, one light with shadows) timed on the integrated-graphics
   machine available. The README's new tier row states what was measured.
4. **The assets' manifest and download.** `godot/game3d/assets.json` (ADR
   0018's fields), `make assets-3d` into the gitignored folder the ADR
   settles on, sha256 checked, a mismatch refused with exit 1. One pack
   first: confirm a stable archive URL exists (itch.io's do not) or record
   a manual download; list the archive and confirm its formats and rig
   before writing the row; measure that Godot imports it from that folder.
5. **The fallback.** A loader that hands back a primitive when the file is
   not on disk, and a test that plants a missing asset.
6. **The gates.** `check_renderer.py` keeps forbidding 3D nodes under
   `game/` and `demos/` (with `VehicleBody3D`, `RayCast3D`,
   `NavigationRegion3D` and the rest added to its list), and refuses a
   `load`, `preload` or `ext_resource` there that points into `game3d/`.
   `check_no_assets.py` refuses a tracked 3D-asset file, a tracked file
   whose sha256 is in the manifest, and a manifest row with no sha256. Both
   born with a planted case each. If the owner wants ADR 0018's tier-1 rule
   held, a check that every `game3d/` example names a `teaches:` topic
   taught at tier 1 or below.
7. Jolt set explicitly in `project.godot`; the 2D suite still green.

## Acceptance

```bash
python3 scripts/check_renderer.py --self-test
python3 scripts/check_renderer.py
python3 scripts/check_no_assets.py --self-test
python3 scripts/check_no_assets.py
test -f docs/godot/3d-headless.md
python3 scripts/check_doc_freshness.py
make test-godot
```

```bash
./scripts/godot --headless --path godot -s res://test/game3d_floor.gd
```

`game3d_floor.gd` holds: the dropped body rests within 0.05 m of the floor
after 120 physics frames; the ray hits the box and misses beyond it; the
baked path goes round the wall; a scene whose assets are missing loads with
primitives. It reads its own output for `SCRIPT ERROR` (CLAUDE.md's trap).

## Manual check

Open the test arena with the assets downloaded and without, on the
integrated-graphics machine, and say whether both are readable. Note the
frame rate the editor's monitor shows.
