# What an addon in this kit actually is

<!-- doc-meta
half_life: practice
verified_on: 2026-10-12
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html ; https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html ; https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
invalidated_if: Godot changes how class_name registers, or the Asset Library starts requiring plugin.cfg
-->

> How the addons in this repository are shaped, and why they are not editor
> plugins. Checked against the Godot 4.7 documentation on 2026-10-12.

## An addon here is a library, not an editor plugin

The two are different things that share a folder name, and conflating them was
an early mistake in this repository.

An **editor plugin** is a folder under `addons/` containing a `plugin.cfg` whose
`script` field points at a `@tool` script extending `EditorPlugin`. Godot lists
it in Project Settings → Plugins, where a user ticks it on. You need one to add
editor UI, docks, import plugins or custom type registrations.

A **library** is a folder of scripts you call from your own code. It needs none
of that, because `class_name` already does the work:

> Named classes are globally registered, which means they become available to
> use in other scripts without the need to `load` or `preload` them.
> — [GDScript basics](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)

So `ai_search`, `ai_planning`, `ai_learning` and `ai_llm` have **no
`plugin.cfg`** and nothing to enable. You copy the folder in, and
`AStarSearch.find_path(...)` is available. One less thing between a reader and
the algorithm.

`gdUnit4` is the exception in this repository: it *is* an editor plugin, it is
third-party, and it is installed by `make bootstrap` rather than committed
(see [ADR 0004](../adr/0004-gdunit4-is-installed-not-vendored.md)).

## What the Asset Library actually requires

Checked rather than assumed, because the rules shape the release step:

- **No `plugin.cfg` requirement.** Putting files in `addons/asset_name/` is
  described as common practice to avoid collisions, not as a rule.
- **A `LICENSE` or `LICENSE.md` at the repository root**, containing both the
  licence text and a copyright statement with year and holder.
- The documentation **recommends a copy of the licence and readme inside the
  addon folder itself**, so a user who installs one addon keeps them. That is
  exactly what `check_license.py` enforces, and now for a reason from the
  source rather than a guess.
- **Apache-2.0 is an available licence.** The tutorial page lists only a few
  examples, which briefly looked like a problem for this project; the live
  filter on the Asset Library includes Apache 2.0 among twenty-odd options.
- Two asset types: **Addons** (visible in-editor) and **Projects** (visible in
  the Project Manager).
- "Above all, the asset must work" in the stated Godot version, or it is
  rejected.

## Names to get right in Godot 4.7

| use | not |
|---|---|
| `TileMapLayer` | `TileMap` — deprecated; one layer per node now |
| `AStarGrid2D` for production pathfinding | this kit's `ai_search`, which is written to be read |

`AStarGrid2D` is engine core, written in C++, and supports Euclidean, Manhattan,
Octile and Chebyshev heuristics with four diagonal modes. It will beat anything
here on throughput. That is the honest recommendation in the README, and this
kit's job is to explain what it is doing.

## Testing constraint

gdUnit4 refuses headless mode unless given `--ignoreHeadlessMode`, because Godot
does not deliver `InputEvent` in that mode. Tests here therefore assert logic
and never simulated input. `make test-godot` passes the flag.
