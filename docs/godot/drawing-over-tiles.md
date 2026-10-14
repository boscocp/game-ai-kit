# Drawing over a TileMapLayer, and laying out a screen you cannot see

<!-- doc-meta
half_life: practice
verified_on: 2026-10-13
tier: 2
source: https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html ; https://docs.godotengine.org/en/stable/classes/class_canvasitem.html
invalidated_if: TileMapLayer stops drawing its tiles on canvas items of their own, or the headless root viewport stops being 100x100
teaches: none
-->

> Two facts T8 ran into while making the board legible. Both were measured on
> 4.7.2 with a real window and a saved screenshot, because a headless run
> rasterises nothing.

## A TileMapLayer paints its tiles over its own `_draw`

The class reference says a rendering quadrant is "a group of tiles to be drawn
together on a single canvas item". It does not say where those canvas items
sit, and the answer matters: they draw **after** the layer's own `_draw`, the
way a child draws over its parent.

**Measured:** the first version of `BoardView` drew the grid, the reachable
tint and the cost numbers in its own `_draw`. Every call ran, and a screenshot
showed none of it. The board looked exactly as it had before.

**What the kit does instead:** `BoardView` adds a plain `Node2D` child and
draws on it from the child's `draw` signal. That child draws above the tiles,
and siblings that come after the layer in the scene (units, routes) still draw
above the child. A `z_index` would also lift it above the tiles, but it would
lift it above the units too.

## Headless, the root viewport is 100x100

**Measured:** `root.size` in a `--headless` `SceneTree` script is `(100, 100)`,
whatever `project.godot` asks for. So a layout computed from
`get_viewport_rect()` is centred on a 100 px square under test and on the real
window when played. It cannot be tested where the tests run.

**What the kit does instead:** the board is centred in the window the project
asks for, `display/window/size/viewport_width` and `viewport_height`.
`board_view_test.gd` checks it against the same two settings.

## How to look at a screen from here

`--headless` rasterises nothing (see [examples.md](examples.md)). When a
display is available, a `SceneTree` script run *without* `--headless` can wait
for `RenderingServer.frame_post_draw` and save `root.get_texture().get_image()`
as a PNG. That is how both facts above were seen. It is a tool for the person
doing the work, not a gate: CI has no display.
