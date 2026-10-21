# 0018 — 3D enters as its own tier, and its assets stay out of git

Status: accepted · 2026-10-21 (proposed in wave 53; the owner's decision of
2026-10-21, opening wave 69 and T50)

## Decision

The owner, 2026-10-21: **option A, and the assets out of git, referenced by
their links.** So the 3D lives in `godot/game3d/` inside the one project; the
renderer stays `gl_compatibility` and Jolt is set explicitly; nothing from a
3D pack is committed, whole or cut, and `godot/game3d/assets.json` records
each file's page, archive URL and sha256 for `make assets-3d` to fetch and
check. The parts below that were proposed and not ruled on are taken as
proposed until T50's measurements say otherwise: the download folder inside
the project, a primitive for every missing model, `check_no_assets.py`. Still
the owner's, and not decided here: the tier's name (T50 measures its target
first), whether the tier-1 rule for a 3D example gets a gate, and whether the
assets rule reaches back to the 2D art.

**What T50 measured and corrected (2026-10-21)**, in `docs/godot/3d-headless.md`:
physics, rays and a navmesh baked from collision shapes all run headless; a
run replays bit-identically on one binary; Kenney's pages *do* link their
archive directly (the URL carries a hash and a timestamp, so it changes when
a pack is updated, and the sha256 catches that). The licence of each pack is
in the manifest's `packs` table, not a separate `LICENCES.md`.

## Context

ADR 0001 made the kit 2D on the Compatibility renderer, so that it runs on
integrated graphics from around 2015, and said: "No 3D lessons. If the kit
ever grows them, they are a separate tier with their own ADR." This is that
ADR. `scripts/check_renderer.py` holds 0001 today: it fails if the rendering
method is not `gl_compatibility`, or if a 3D node appears under `game/` or
`demos/`.

The owner has asked for three examples that are 3D by nature (memory note of
2026-10-15, asked again 2026-10-18):

- a shooter where bots play each other, as a team match, with no networking;
- a single-player shooter where bots cooperate against the player, with
  optional stealth for the player;
- a racing game in 3D with physics more complex than T22/T23's crude car.

And one rule for their assets (2026-10-18): open or free assets are
**referenced** in the repository and **kept out of git** -- not even crops,
unlike ADR 0015 -- so the repository carries only what is about AI.

Four invariants are in play: 1 (readable), 5 (no lesson above tier 1), 8
(toolchain on the large disk) and 13 (every example can be watched).

## What was measured and what was read (2026-10-18)

Read in the Godot 4.7 documentation (the pinned 4.7.2) and the class
reference XML at the `4.7.2-stable` tag. **Nothing below was measured on
this machine yet**; the measurements are T50's first step.

- **The Compatibility renderer draws 3D.** Forward single-pass lighting,
  shadows (no soft PCSS), glow, SSAO, fog, MSAA, and baked lightmaps played
  back. It has no SDFGI, VoxelGI, SSR, volumetric fog or decals, and cannot
  *bake* a lightmap (that needs a RenderingDevice machine). Its floor is
  OpenGL 3.3 -- the docs' example is Intel HD 2500, 2012. Forward+ and Mobile
  need Vulkan 1.0, D3D12 or Metal; their example is Intel HD 510, 2015.
  <https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html>,
  <https://docs.godotengine.org/en/stable/about/system_requirements.html>
- **The renderer is a project setting**
  (`rendering/renderer/rendering_method`), overridable per platform and per
  run with `--rendering-method`. A sibling project has its own. On Windows
  Compatibility also runs on Direct3D 11; lights with shadows are drawn in
  extra passes.
- **Jolt is built in** since 4.4 and written into new projects since 4.6, but
  the setting's `DEFAULT` value still means GodotPhysics3D -- so a project
  that wants Jolt must say so explicitly.
  <https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html>,
  <https://docs.godotengine.org/en/stable/classes/class_projectsettings.html>
- **`VehicleBody3D` is a raycast vehicle** whose own reference says it "has
  known issues and isn't designed to provide realistic 3D vehicle physics",
  and points to writing your own on `RigidBody3D`.
- **Determinism is not documented** by Godot. Jolt's own documentation
  promises it only for the same binary calling the API in the same order
  (<https://jrouwe.github.io/JoltPhysics/index.html>). A gate that replays a
  3D race and expects the same result must measure that first.
- **Headless 3D is not documented** either: whether physics, ray casts and
  `NavigationServer3D` run under the dummy renderer is a measurement, not a
  reading. The navigation docs advise baking from collision shapes, not
  visual meshes, which a dummy renderer may not hand over.
- **glTF 2.0 is the recommended format**; FBX imports natively through ufbx.
- **CC0 packs exist for all three examples**: Kenney (Blaster Kit, Racing
  Kit, Car Kit, Mini Characters, Prototype Textures), Quaternius (Toon
  Shooter Game Kit -- characters with 17 animations, Ultimate Guns, Cars),
  KayKit (Character Animations, with shooting and aiming; Prototype Bits,
  blocky cover). Each page was opened and says CC0; file formats and rigs are
  T50's to confirm by listing an archive.

## Options

### Where the 3D lives

- **A. A folder of its own inside the one project: `godot/game3d/`.**
  `check_renderer.py` keeps forbidding 3D nodes under `game/` and `demos/`,
  unchanged; the new folder is where the examples live. Every addon
  is reachable as it is today, the same `scripts/godot`, the same `make
  test-godot`. The cost: one `project.godot` for both, so a physics engine
  or a rendering setting chosen for 3D is chosen for the 2D kit too.
- **B. A sibling project: `godot3d/project.godot`.** Its own settings, its
  own import cache, and a 2D kit that never imports a glTF. The cost: the
  addons are in the other project. Copied, they drift; symlinked, they
  break on Windows checkouts; a script that syncs them is a third thing to
  keep. Invariant 2 says an addon is copyable, but the kit itself copying
  them is a duplication a reader has to trust.
- **C. 3D only as addons, no examples.** Fits 0001's letter; fails the
  owner's request, which is examples you play.

**Where 3D is allowed.** Today `check_renderer.py` forbids 3D nodes under
`game/` and `demos/` only; `addons/` and `test/` are exempt on purpose, and
the 3D examples' addons and tests will need them there. So the rule
proposed is the current one, unchanged, plus one path rule: nothing under
`game/` or `demos/` loads (`load`, `preload`, `ext_resource`) from
`game3d/`. The type list (`THREE_D_TYPES`) also lacks `VehicleBody3D`,
`RayCast3D`, `NavigationRegion3D` and others, which T50 adds.

**Proposed: A.** The renderer stays `gl_compatibility` for the whole
project -- 3D on Compatibility keeps the 2012 floor, which is lower than
Forward+'s and higher than nothing -- and the physics engine is set to Jolt
explicitly, which changes nothing for the 2D kit (it has no 3D bodies).
If A's shared settings ever bite, B is the way out, and this record is reopened.

### Which tier

- **A fifth row in the README's table:** Godot plus a machine that
  draws a 3D scene at a stated target. The target is a measurement T50
  makes on integrated graphics (proposed: 1280x720 at 30 fps, the 2D
  kit's half), not a promise written first. Its name is the owner's;
  pages about it carry a number in `tier:` (`check_tiers.py` rejects
  anything else), so either it is written `2` with the 3D said in the
  page, or the gate learns a new value in T50.
- **Or tier 3**, beside the GPU work. Rejected as proposed: tier 3 means a
  graphics card with VRAM, and nothing here needs one.

### How invariant 5 holds

No lesson may live only above tier 1. A 3D example teaches what its bots
decide, and the deciding must not need the 3D. Proposed, and the tasks are
written this way:

- **The decision runs on a plain snapshot.** A bot's choice -- which cover,
  which role, where to search, how hard to brake -- is a function of
  positions, sight lines and costs, as every decision in this kit already
  is. The 3D scene builds the snapshot and plays the answer; the decision
  never calls the physics server itself.
- **The decision has a Python twin and conformance vectors**, as `ai_fuzzy`,
  `ai_opponent` and the tactical rules do, so it is runnable at tier 1.
- **Every technique gets a concept page at tier 1 or below** (`teaches:`
  set), as `docs/concepts/shooter-ai.md` is. **This half is prose, not a
  gate**: `check_tiers.py` reads only `doc-meta` blocks under `docs/`, and a
  Godot scene has none, so nothing checks that a 3D example's topic is
  taught below it. What is gated is the Python twin, through `make
  test-vectors`. If the owner wants the rest held, T50 names a check.
- **Physics is the exception and says so.** How a car's tyres grip is not a
  lesson in AI; the racing controller is. The 3D racer's lesson (a
  controller that drives a physics it does not fully know) has its tier-1
  half in T22/T23's 2D car and a Python model of the controller.

### The assets

Not an option -- the owner's rule -- only its form:

- **Nothing 3D is committed.** No `.glb`, `.gltf`, `.fbx`, `.obj`, `.blend`,
  texture or archive from a pack, whole or cut. `.gitignore` excludes the
  download folder.
- **A manifest is committed**: `godot/game3d/assets.json`, one row per file
  used -- the pack, its page URL, the archive's URL and sha256, the path
  inside it, the file's sha256, the licence as the page states it, and the
  date checked. `LICENCES.md` lists the packs.
- **`make assets-3d` downloads into a gitignored folder** on the large disk
  (invariant 8), checks every sha256 against the manifest, and refuses on a
  mismatch, as `tools/fighters/crop.gd` does for ADR 0015's sheets. Where
  that folder is decides how Godot reads it, and T50 measures both:
  inside the project (`godot/game3d/downloaded/`, imported like any asset,
  and kept clear of `.gitignore`'s `!godot/assets/**/*.import` exception),
  or outside it under `build/`, loaded at run time with
  `GLTFDocument.append_from_file`, skipping the import step. Proposed:
  inside, so import settings apply and the editor sees the models.
- **Not every pack has a stable download URL.** KayKit is on itch.io, whose
  download links expire, and the Kenney and Quaternius pages showed no
  direct archive link either. Where none exists, the manifest records the
  page and the archive's sha256, the person downloads it by hand into the
  folder, and `make assets-3d` checks it the same way.
- **Every example runs without them.** A missing model is drawn as a
  primitive -- a capsule for a bot, a box for cover, a box on four cylinders
  for a car -- the way ADR 0015's fighters fall back to blocks. So `make
  check` and CI never download anything, and a test plants a missing asset
  and holds that the scene still loads.
- **A gate**, proposed: `check_no_assets.py` fails on any tracked file with a
  3D-asset extension; on any tracked file whose sha256 is a file's sha256 in
  the manifest (this is what catches a pack's `.png` texture, which an
  extension test cannot tell from the kit's own 2D art); and on a manifest
  row with no sha256. Born with a planted case (invariant 4): a manifest
  file committed under another name.

### Physics and reproducibility

- **Jolt, set explicitly** in `project.godot`.
- **No gate relies on physics replaying identically** until T50 has
  measured it on the pinned binary. The tests hold the decisions, which run
  on snapshots and are deterministic by construction; a physics replay is
  measured, and if it is not repeatable the record says so and the gate is
  a tolerance stated as a number.
- **Fixed physics rate**, and `--fixed-fps` for headless runs.

### For the owner to decide besides the options

- **Does the assets rule reach back to 2D?** The owner asked that open
  assets stay out of git "so the repo carries only AI content". This record
  applies it to 3D. The kit already commits CC0 2D art (ADR 0012) and the
  fighters' cut strips (ADR 0015). Whether those should leave git too, and
  be downloaded the same way, is a separate decision, not taken here.

## Consequences

- If accepted, ADR 0001's "No 3D lessons" is amended by this record, not
  erased: the 2D kit stays 2D and its gate stays as strict.
- T50 measures before anything is built: headless physics, ray casts and
  navigation; a frame rate on integrated graphics; one pack's real formats.
  If headless 3D does not run, invariant 3 can only reach the snapshot-level
  decisions, and the tasks say so in `## Manual check`.
- Invariant 13 gets harder and more important: a bot's chosen cover, its
  role, its suspicion and the racer's line are drawn in the 3D view and on a
  2D map of the same match, which is the view a person can read at once.
- The repository grows by manifests and code, not by megabytes.
