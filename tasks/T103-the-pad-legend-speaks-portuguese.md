# T103 — The pad's legend line speaks Portuguese

Size: S · Prereqs: T80 · Files: `godot/game/pad_as_keys.gd`, `godot/locale/`, `modules/game_shared.json`, `godot/test/game_shared/`, `godot/test/locale/locale_screen.gd`

## Goal

With a controller connected, every real-time demo adds a line to its
legend saying what the pad's buttons do (`PadAsKeys.add_to`, wave 84):
"pad: stick ←/→, A Space, ...". `game_shared` has no translation table,
so in pt-BR the words "pad" and "stick" stay English on every demo that
lists a pad. T80 left it and said so.

## Steps

1. Give `game_shared` a table, `godot/locale/game_shared.csv`, owned by
   its manifest, and pass the line's words through `tr()`; key and button
   names stay as written, as the glossary says.
2. Rebuild the pad line when the language changes: each demo already
   calls `add_to` after `set_entries` in its legend's rebuild.
3. `test-locale-screen` cannot connect a pad headless: plant one in
   `PadAsKeys` for the check (its `describe` without a pad), and fail if
   the line is English in pt-BR.

## Acceptance

```bash
python3 scripts/check_translations_game.py
make test-locale-screen
make test-pad
make lint-modules
```

## Manual check

With an Xbox controller connected, open the racer and the bot match in
PT-BR: is the pad's line in Portuguese, the button names as printed on
the pad?
