# What 3D does under `--headless`, and on integrated graphics

<!-- doc-meta
half_life: practice
verified_on: 2026-10-21
tier: 2
source: https://docs.godotengine.org/en/stable/classes/class_navigationserver3d.html ; https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html ; https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html ; https://kenney.nl/assets/mini-characters
invalidated_if: the pinned engine changes, a navigation region's async iteration stops dropping a mesh set on its second frame, or Jolt stops replaying a run identically on one binary
teaches: none
-->

> What T50 measured before any 3D example was built (ADR 0018). Read in the
> documentation first, then measured on 4.7.2-stable, Jolt, this machine.
> The last column says which answers `make test-game3d-floor`
> (`godot/test/game3d/game3d_floor.gd`) holds; the rest were measured once.

## What the documentation says, and what it does not

- **Navigation from collision shapes.** The navigation-mesh page: visual meshes
  "need to be received from the GPU, stalling the RenderingServer", and "for
  runtime (re)baking prefer using physics shapes as parsed source geometry".
  That is also the only way a bake can work headless, where nothing is drawn.
- **The navigation server works in its own time.** Its class reference: it
  "keeps tracks of any call and executes them during the sync phase", and a
  map iteration id of 0 "means the navigation map has never synchronized". A
  region may sync "on a background thread" (`region_set_use_async_iterations`,
  on by default in the project setting).
- **Not documented:** whether 3D physics, rays and navigation run under the
  dummy renderer, whether a run replays identically, and the trap below.

## What was measured

| question | answer on 4.7.2 | held |
|---|---|---|
| does 3D physics run headless? | yes: a 0.5 m ball dropped from 3 m rests at 0.484 m after 120 frames (GodotPhysics: 0.490) | rests within 0.05 m; with no floor it does not |
| do rays work headless? | yes: hit a box's face at x = -0.5 exactly, and miss 3 m past it | yes |
| does a navmesh bake from collision shapes headless? | yes: 12 polygons round a 10 m wall, and a path round its end | the path goes round; with no wall it does not. The polygon count was measured once |
| does a run replay identically? | yes: a dropped ball and a 1200 kg box pushed into a crate, 600 frames, bit-identical in three separate processes and with `--fixed-fps 60` | 300 frames twice in one process; a push 1% harder differs. Across processes measured once |
| does a 3D scene with a `Legend`, `step_decision()` and `decision_overlay()` work headless? | yes: the test arena loads; who sees whom changes as the bots walk; the cover blocks some sight lines, and with it removed all 128 pairs see each other | yes |
| does the engine import a pack's GLB from `godot/game3d/downloaded/`? | yes: `--import` writes `.import` beside each file (gitignored with the folder); Kenney's `character-male-a.glb` loads with its 32 animations | the shelf's model stands 0 to 1.8 m, where `make assets-3d` has run; the animations were counted once |

**Replay is identical, and it is still a measurement.** Jolt promises
determinism only for the same binary calling the API in the same order. So a
gate may compare two runs on one machine exactly. A recorded run compared
across machines or engine versions may not match, and no gate here does that.

## The traps it found

- **A navmesh set on its second physics frame never reaches the map.** A
  `NavigationRegion3D` already in the tree, given its mesh on physics frame
  2, had no polygons on the map 120 frames later, in six runs out of six. On
  frame 1, 3, 4 or 6 the mesh arrived. With async iterations off for that
  region (`region_set_use_async_iterations(rid, false)`) it arrived on frame
  2 as well. The docs say nothing about this. So **give a region its mesh
  before it enters the tree**, as the floor test does, or turn its async
  iterations off. Then wait for the answer: a query before the map has synced
  answers empty, and errors with "made before first map synchronization".
- **Every node under `root` shares one navigation map.** A test that builds a
  world, frees it and builds another got the first world's path back: a freed
  region leaves the map at a later sync, not when it is freed. Each check
  makes its own map (`map_create`, `map_set_active`, `set_navigation_map`)
  and frees it after.
- **A body moved through its node is in the physics space a frame late.**
  Setting a `StaticBody3D`'s `position` and casting a ray at once missed it
  where it went; one physics frame later the ray hit. The same move through
  `PhysicsServer3D.body_set_state(rid, BODY_STATE_TRANSFORM, ...)` was hit at
  once, in and out, twice. So a decision that moves bodies and then looks
  must either wait a physics frame or tell the server itself. The test arena
  tells the server; before it did, its sight lines were a step stale, and
  ten decisions in a row found none.
- **`--fixed-fps` makes Jolt warn once a run** (measured by T54,
  2026-10-21): "Jolt Physics job system exceeded the maximum number of jobs
  ... Waiting for jobs to become available". The floor test, run that way,
  counts it as an engine error and fails; the racing checks forgive that
  one warning by its text (`docs/godot/racing3d.md`). And `Engine.time_scale`
  is no way to run physics faster: it scales the physics step itself.
- **`agent_radius` is rounded up to whole cells.** 0.4 with the default
  0.25 m cell warns "ceiled to cell_size voxel units"; 0.5 does not.
- **Choosing the integrated GPU took X11.** With an NVIDIA card driving the
  Wayland session, Godot drew on the NVIDIA card whatever `DRI_PRIME` and
  the glvnd variables said. It used the integrated Radeon only with all three
  and `--display-driver x11`:

      DRI_PRIME=1 __GLX_VENDOR_LIBRARY_NAME=mesa \
      __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json \
        ./scripts/godot --display-driver x11 --path godot -s res://test/game3d/arena_fps.gd

  The startup line `Using Device:` says which one ran. Read it before
  believing a number.

## The frame rate (not a gate)

`make measure-3d`: the test arena (sixteen capsules or Kenney characters,
seven blocks of cover, one directional light with shadows), 1280x720, vsync
off, 10 s after 3 s of warm-up. Every bot asks its 8 sight lines on every
physics frame, 60 a second, as a match would; the drawing runs as fast as
it can.

| GPU | models | primitives | worst frame |
|---|---|---|---|
| AMD Radeon 610M (integrated, Ryzen 5 9600X; RDNA2, 2 CUs, 2022) | 1068-1071 fps | 1013-1014 fps | 2.7-3.5 ms |
| NVIDIA GeForce RTX 5070 | 4769 fps | not measured | 1.7 ms |

A first version asked the sight lines on every *drawn* frame instead, so
128 rays a frame: 394-398 fps on the 610M, 578-587 on the RTX. A cold
first run once showed a 48 ms frame, shaders compiling.

The 610M is newer than the 2015 integrated graphics the 2D kit targets, and
nothing older was available to measure on. So the 3D tier's floor is stated
as this measurement, not as a promise about 2015 hardware. Against a 30 fps
target that leaves a margin of about 34 times on this chip.

## The assets

`godot/game3d/assets.json` names one pack so far: Kenney's Mini Characters
1.0, CC0. Its page links the archive directly. ADR 0018 had found no direct
link on Kenney's pages, and there is one in the page's HTML. The URL carries
a hash and a timestamp, so expect it to change when the pack is updated. Then
`make assets-3d` refuses the new archive's sha256, and the manifest row is
updated by a person who looked at it. The archive has FBX, OBJ and GLB
versions of twelve characters. The GLBs are rigged, two skins, 32 animations
(`idle`, `walk`, `sprint`, `holding-both-shoot`, `die`, ...), and they share
one texture, `Textures/colormap.png`, which the manifest lists as a file of
its own.
