# Exporting the menu: what was measured on 4.7.2

<!-- doc-meta
half_life: practice
verified_on: 2026-10-19
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html ; https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html ; https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html
invalidated_if: .godot-version changes, the pack format moves past 4, or self-contained mode stops reading export templates from editor_data/
teaches: none
-->

> What `make export` (T24) relies on, each item measured on the pinned
> engine after reading the documentation for it. Read the documentation
> again before trusting any of it on another version.

## Templates, in self-contained mode

- `make bootstrap` downloads `Godot_v4.7.2-stable_export_templates.tpz`
  (1.28 GB, every platform) and unpacks only `linux_release.x86_64`,
  `linux_debug.x86_64` and `version.txt`. With `._sc_` beside the binary the
  editor looks for them in
  `editor_data/export_templates/4.7.2.stable/` beside it, and an export
  from `scripts/godot` found them there: nothing went to `$HOME`
  ([ADR 0002](../adr/0002-toolchain-on-the-large-disk.md)).
- The archive's SHA-512 is pinned in `bootstrap.sh`, and the release
  template's own SHA-512 in `export.py`, rather than read from the release's
  `SHA512-SUMS.txt`: a file replaced upstream is refused, not trusted.

## The export itself

- `--headless --path godot --export-release "Linux x86_64" <absolute path>`
  exported the whole project in about 2 seconds. The preset's name is the
  `name=` in `godot/export_presets.cfg`, which is now committed: since 4.1 the
  secrets an export may carry go to `.godot/export_credentials.cfg`, and
  `.godot/` stays ignored.
- `.json` files ship under `export_filter="all_resources"` with no include
  filter: the pack held all nine with `include_filter=""`.
  `exclude_filter` takes paths relative to `res://`; `test/*`,
  `addons/gdUnit4/*`, `assets/generated/*` and `reports/*` all stayed out.
- With `binary_format/embed_pck=false` the export writes the engine binary
  and a `.pck` beside it, which `export.py` reads.

## The pack's directory

Format 4, little-endian: `GDPC`, the format version (4), the engine's major,
minor and patch (4, 7, 2), flags, the offset where files begin, and the
offset of the directory. At the directory: a count, then per file its
path's length, the path (padded to four bytes, without `res://`), its
offset and size (8 bytes each), its MD5 (16) and flags (4). Reading 498
entries that way ended exactly at the end of the file. Scripts ship as
`.gdc` with a `.remap` beside them; scenes as binary `.scn` under
`.godot/exported/`.

## Running what was exported

- The exported binary honours `--headless` and `--quit-after N` and exits
  0, which is how `export.py` proves a build starts.
- It writes `user://` like any Godot program, under `XDG_DATA_HOME`;
  `export.py` sets that to the toolchain's `xdg/`, as `scripts/godot` does.
