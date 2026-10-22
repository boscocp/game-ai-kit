# T77 — The demos speak Portuguese: the switch, the gate, the board games

Size: M · Prereqs: T70 · Files: `godot/locale/`, `godot/menu/`, `godot/game/`, `godot/demos/search/`, `godot/demos/behaviour/`, `godot/project.godot`, `scripts/check_translations_game.py`, `godot/test/locale/`

## Goal

The owner, 2026-10-22: "e localizar os jogos tbm pra deixar as demos com
opcao de mudar pra PT br." (the whole request is quoted in T74.)

Every demo gets a language option, English or Brazilian Portuguese, using
Godot's own translation system. Nothing in the kit is translated today:
no `TranslationServer` call, no `.po` or `.csv` translation, no locale
setting in `project.godot` (checked 2026-10-22). This task builds the
mechanism, the gate and the menu's switch, and translates the turn-based
games. T78 does the real-time and 3D ones with the same mechanism. It
comes after the current work (T69, T70).

## Decisions written down first (the owner confirms them in review)

- **Godot's CSV translations, not gettext.** Godot reads both (official
  docs, "Internationalizing games" and "Localization using gettext", 4.7,
  read 2026-10-22). gettext's tools (`msginit`, `msgmerge`) are not in
  Python's standard library and its template generator runs only in the
  editor's UI. A CSV (`keys,en,pt_BR`) is read and checked by stdlib Python,
  so the gate stays tier 1. One file per module under `godot/locale/` keeps
  T58's ownership: a module owns its strings.
- **The key is the English text**, so the code still reads as English
  (invariant 1), and a missing translation falls back to English rather
  than to a key name. Text with numbers uses `tr()` then `String.format()`
  with named placeholders, as the docs recommend, never a sentence glued
  together from pieces a translator cannot reorder.
- **The default follows the system**: `OS.get_locale_language()` is `pt`
  → pt-BR, otherwise English. The menu's switch overrides it and is
  remembered in `user://settings.cfg` (redirected by `scripts/godot`,
  CLAUDE.md's trap). `godot --language pt_BR` forces it for a test or a
  screenshot (docs: "Testing translations"). The project's `Test` locale
  setting is never committed (the docs warn against it).
- **Keys and names that stay English**: key names on screen (WASD, Tab),
  technique names the field uses in English in Brazil (A\*, minimax,
  GOAP), shared with T74's glossary.

## Steps

1. **The mechanism**: `godot/locale/` with one CSV per module, imported
   (CLAUDE.md: an import after adding resources); `project.godot`'s
   translations list; a small `Language` helper in `game_shared` that
   reads the system, the saved choice, and sets
   `TranslationServer.set_locale`.
2. **The menu's switch**: a visible EN / PT-BR toggle in `godot/menu/`,
   applied at once (Controls whose text is a key retranslate; text built
   in code is rebuilt on the locale-changed notification).
3. **The board games and turn-based demos**: `make run` (checkers),
   `demo-skirmish`, `demo-tictactoe`, `demo-search`, `demo-tactical`,
   `demo-stealth`, `demo-behaviour` -- every status panel, legend, button,
   help line and end-of-game message. The decision overlays (invariant 13)
   are what the lesson is; their words are translated first.
4. **The gate, in two halves**, each born with a planted case:
   - `scripts/check_translations_game.py` (stdlib): every key a script
     passes to `tr()` exists in its module's CSV with a non-empty `pt_BR`;
     no CSV key is unused; the CSV parses. Planted: one missing key, one
     empty `pt_BR`, one orphan key.
   - a headless Godot check (`godot/test/locale/`) that opens each
     translated demo with `--language pt_BR`, steps it a few frames, walks
     every visible `Label`, `Button` and `RichTextLabel`, and fails on text
     that is still the English of a known key -- the string someone forgot
     to wrap in `tr()`. Planted: a label set without `tr()`. Read its
     output for SCRIPT ERROR (CLAUDE.md's trap).
5. **The `##` help of each `demo-*` target stays English** (it is the
   command line's); the demo's in-game help is translated.

## Acceptance

```bash
python3 scripts/check_translations_game.py
python3 scripts/check_translations_game.py --self-test
make test-godot-some SUITES="test/locale"
python3 scripts/check_readability.py
make lint-modules
make lint-tasks lint-status
```

## Manual check

Switch the menu to PT-BR and play each translated demo: is every word on
screen Portuguese, does the decision overlay still fit its panel (Portuguese
runs about a fifth longer), and does the choice survive closing the game?
