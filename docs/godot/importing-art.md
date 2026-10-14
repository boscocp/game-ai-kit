# Pictures need importing before a run can load them, and keeping after

<!-- doc-meta
half_life: practice
verified_on: 2026-10-14
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html ; https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
invalidated_if: a project run starts importing resources itself, or the import process stops writing .import sidecars
teaches: none
-->

> What T9 ran into when the first PNG arrived. Read in the documentation
> first, then measured on 4.7.2.

## What the documentation says

The import process page: Godot keeps "the imported resources hidden in a
`res://.godot/imported/` folder", and of the `.import` file written beside
each source file, "commit these files to your version control system". The
`.godot/` folder itself should stay out.

The command-line page: `--import` "starts the editor, waits for any resources
to be imported, and then quits".

Neither page says whether running a project, rather than opening it in the
editor, imports anything.

## What was measured

In a copy of the project with no `.godot/` folder -- which is what a fresh
clone and a CI runner have:

```text
$ ./scripts/godot --headless --path <copy> -s res://probe.gd
ERROR: No loader found for resource: res://assets/terrain/plain.png (expected type: unknown)
loaded: <Object#null>
```

After `./scripts/godot --headless --path <copy> --import` (exit 0), the same
script printed a `CompressedTexture2D` and the image's size, `(16, 16)`.

So **a run imports nothing**. Only the editor does, and `--import` is the
editor doing it with no window.

## What the kit does

- `make import` runs `--import`, and every target that opens a scene depends
  on it: `test-godot`, `test-demo-overlays`, `test-decisions`, `run` and each
  `demo-*`. CI calls those targets, so CI imports too. When nothing changed it
  took 1.7 s here.
- The `.import` sidecars under `godot/assets/` are committed, as the
  documentation says. Elsewhere in the tree `.gitignore` still drops them.
- The importer's defaults are kept: lossless, no mipmaps. Pixel art is kept
  sharp where it is drawn instead -- `UnitView` sets its own
  `texture_filter` to nearest, and the board scales its tiles with
  `Image.INTERPOLATE_NEAREST` when it builds the atlas.

The same step also refreshes the global class list, which is the trap in
`CLAUDE.md` about a new `class_name` being invisible until the project is
imported.

## A picture that fails to import poisons its sidecar

Found by the wave 30 review, and measured again:
- with garbage written over `terrain/trees.png`, `--import` **exits 0** and
  prints three `ERROR` lines (`ERR_FILE_CORRUPT`);
- it rewrites the committed `trees.png.import` to `valid=false`;
- putting the right picture back does **not** recover. A plain `--import`,
  even after touching the file, leaves the sidecar invalid and the picture
  unloadable;
- `git checkout -- trees.png.import` and importing again does.

So `make import` treats any `ERROR` in the engine's output as a failure, and
any sidecar under `godot/assets/` marked `valid=false` as another, and says how
to recover. T31 will write pictures, which makes this its trap more than T9's.

## A texture loaded in `_draw` must outlive `_draw`

Not in the documentation, and found by looking at a screenshot.

**Measured:** `UnitView._draw` called `load()` for each unit's picture and
drew it. In a real window, every blue building and the blue shield were
**white squares**, while every red piece and the blue runner drew correctly.
Redrawing a few frames later changed nothing.

The pieces that drew were exactly the ones the legend's entry list also held.
`load()` hands back a resource counted by reference; a `_draw` that loads one,
draws it and returns lets the count reach zero, the texture is freed, and the
draw command is left naming a texture that no longer exists.

**What the kit does:** `Art.texture` keeps every picture it loads in a static
dictionary for as long as the game runs. Thirty small textures. A test holds
the cause, since headless nothing is drawn: a texture asked for and let go is
the same object when asked for again. Comparing two held at once proves
nothing, because Godot's own cache returns one copy while anybody holds it.

A second fact followed from the first. A texture that stays loaded hands back
the **same** `Image` from every `get_image()` -- measured, one instance id
twice. Once `Art` kept its textures, `BoardView` resizing that image in place,
and laying trees over the open ground, changed the next tile built from it:
seven tiles came out as six pictures. `BoardView` copies the image first, and
`test_every_tile_in_the_atlas_is_a_different_picture` is what caught it.
