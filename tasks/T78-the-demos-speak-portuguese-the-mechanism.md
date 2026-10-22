# T78 — The demos speak Portuguese: the mechanism, the gate, the switch

Size: M · Prereqs: T70 · Files: `godot/locale/`, `godot/menu/`, `godot/game/checkers/`, `godot/demos/search/`, `godot/game/`, `godot/project.godot`, `modules/`, `scripts/check_translations_game.py`, `Makefile`, `godot/test/locale/`

## Goal

The owner, 2026-10-22: "e localizar os jogos tbm pra deixar as demos com
opcao de mudar pra PT br." (the whole request is quoted in T74.)

Every demo gets a language option, English or Brazilian Portuguese, using
Godot's own translation system. Nothing in the kit is translated today:
no `TranslationServer` call, no `.po` or `.csv` translation, no locale
setting in `project.godot` (checked 2026-10-22). This task builds the
mechanism, the gate and the menu's switch, and proves them on two demos;
T79 translates the other turn-based games and T80 the real-time and 3D
ones. It comes after the current work (T69, T70).

## Decisions written down first (the owner confirms them in review)

- **Godot's CSV translations.** Godot reads CSV and gettext `.po` alike,
  and a `.po` is plain text that loads without the gettext tools too
  (official docs, "Internationalizing games" and "Localization using
  gettext", 4.7, read 2026-10-22). CSV is chosen because one row holds the
  key and both languages side by side, which a reviewer reads at a glance
  and stdlib `csv` checks; and because Godot's own template generator for
  `.pot` runs only in the editor's UI. The gate rejects a CSV with a BOM.
- **One CSV per module**, `godot/locale/<module>.csv`, owned by that
  module's manifest (T58: a module owns its strings).
- **The key is the English text**, so the code still reads as English
  (invariant 1) and a missing translation falls back to English rather
  than a key name. The cost, said plainly: one English word can need two
  Portuguese ones ("Play" a game, "Play" a card). Godot 4.6+ CSV takes a
  `?context` column for those, and a context disables the automatic
  translation of a `Control`'s text -- such a string is set through
  `tr(text, context)` in code. Text with numbers uses `tr()` then
  `String.format()` with named placeholders, as the docs recommend, never
  a sentence glued from pieces a translator cannot reorder.
- **The default follows the system**: `OS.get_locale_language()` is `pt`
  → pt-BR, otherwise English. The menu's switch overrides it and is
  remembered in `user://settings.cfg` (redirected by `scripts/godot`,
  CLAUDE.md's trap). The project's `Test` locale setting is never
  committed (the docs warn against it).
- **What stays English**: key names on screen (WASD, Tab), technique names
  the field uses in English in Brazil (A\*, minimax, GOAP; T74's glossary),
  and the `##` help of each `make demo-*` target (the command line's).

## Steps

1. **Measure first** (CLAUDE.md: the documentation, then a measurement):
   with a one-row CSV and the locale set to `pt_BR`, does a `Label`'s
   `text` property still read the English key while the screen shows the
   Portuguese (auto-translation at draw time), or is the property changed?
   What does `atr()` return? Does `draw_string` translate anything (it is
   expected not to)? Write the answers in `docs/godot/localisation.md`
   with the source and `verified_on`, and build the gate on them.
2. **The mechanism**: the CSVs imported (an import after adding
   resources); `project.godot`'s translations list; a small `Language`
   helper in `game_shared` that reads the system and the saved choice and
   calls `TranslationServer.set_locale`.
3. **Ownership** (`make lint-modules`): each `godot/locale/<module>.csv`
   in its module's `owns`; `godot/test/locale/` owned by `menu`, which
   already depends on every demo.
4. **The menu's switch**: a visible EN / PT-BR toggle in `godot/menu/`,
   applied at once -- Controls retranslate themselves; text built in code
   and everything drawn with `draw_string` is rebuilt on the
   locale-changed notification.
5. **Two demos, end to end**: `make run` (checkers) and `demo-search` -- a
   board with a decision overlay and a demo with a legend and buttons.
6. **The gate, mostly static.** The decision overlays are drawn with
   `draw_string` in fourteen files (`board_view`, `plan_view`,
   `intent_view`, `rts_view`, `rts_thinking`, `stealth_view`,
   `checkers_view`, `tictactoe_view`, `legend`, `brain_panel`,
   `steering_lane`, `unit_view`, `botmatch_hud`, `botmatch_map`) and with
   `Label3D` in `botmatch_drawing.gd`; no walk over `Label`s sees them.
   - `scripts/check_translations_game.py` (stdlib), `--self-test`, exit
     codes 0/1/2: a string literal passed to `draw_string`,
     `draw_multiline_string`, a `.text =` assignment, `set_text` or a
     `Label3D`'s text without `tr()`/`atr()` is a finding, in the files of
     modules marked translated (two now, all after T80); every key a
     script passes to `tr()` exists in its module's CSV with a non-empty
     `pt_BR`; no CSV key is unused; the CSV parses and has no BOM.
     Planted: a bare `draw_string` literal, a `.text =` literal, one
     missing key, one empty `pt_BR`, one orphan key, a BOM.
   - a headless `-s` script (`godot/test/locale/locale_screen.gd`, with
     its own `make` target, as the racer's and bot match's gates are, so it
     can pass `--fixed-fps 60`; it sets the locale with
     `TranslationServer.set_locale`, not `--language`) that opens each
     translated demo in `pt_BR`, steps it a few frames, and checks what the
     screen shows for `Control`s (by step 1's measured rule) is not the
     English of a key that has a translation. Planted: a `Label` whose
     auto-translation is disabled. It counts engine errors and fails on
     any (the SCRIPT ERROR trap).
7. **Wire the gates in**: `Makefile` targets, both in `make check`, the
   stdlib one's self-test in `make lint-selftests`.

## Acceptance

```bash
python3 scripts/check_translations_game.py
python3 scripts/check_translations_game.py --self-test
make test-locale-screen
python3 scripts/check_readability.py
python3 scripts/check_doc_freshness.py
make lint-modules
make lint-tasks lint-status
```

## Manual check

Switch the menu to PT-BR and play checkers and the search demo: is every
word on screen Portuguese, does the decision overlay still fit its panel,
and does the choice survive closing the game?
