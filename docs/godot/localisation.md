# The examples in Portuguese

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html ; https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_spreadsheets.html ; https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-property-auto-translate-mode
invalidated_if: Godot changes when a Control translates its text, what atr() returns with auto-translation off, the CSV importer's columns or compression, or the startup locale
teaches: none
-->

> T78, wave 88. How the menu's EN / PT-BR switch works, what was measured
> on the pinned engine (4.7.2) before the gate was written on it, and how a
> translated example is held to its table.

## The mechanism

- One table per module, `godot/locale/<module>.csv`, owned by that
  module's manifest. The header is `en,pt_BR`: the first column is the key,
  and the key *is* the English text, so the code still reads as English and
  a missing row falls back to English, not to a key name. The engine
  ignores the first header cell; `en` is written there for the reader.
- `make import` turns each table into `<module>.pt_BR.translation` beside
  it, and `project.godot` lists those under
  `internationalization/locale/translations`. The `.translation` files
  are committed (below: the engine reads the list before importing).
- `Language` (`godot/game/language.gd`) chooses the locale: the choice
  saved in `user://settings.cfg`, otherwise `pt` on the system means pt-BR
  and anything else English. The menu applies it when it opens; its button,
  L, or Y on a pad switch it and save it.
- A `Label` or `Button` whose whole text is a key translates itself. Text
  built in code goes through `tr()`, or `TranslationServer.translate()` in
  a static function, where `tr()` -- a method of an object -- is not there.
  A sentence with a number is one key with a named placeholder,
  `tr("searched {positions} positions").format({positions = count})`, as
  the documentation recommends, never pieces glued in English order.
- Text set from code keeps the words it was given, and text drawn with
  `draw_string` is drawn once. So each translated scene rebuilds its words
  on `NOTIFICATION_TRANSLATION_CHANGED`.
- What stays English: key names (Enter, Page Up, WASD), technique names the
  field says in English in Brazil (A\*, Dijkstra, minimax), and the `##`
  help of `make` targets.

## Measured on 4.7.2

A scratch project, one table, the locale set with
`TranslationServer.set_locale("pt_BR")`:

| question | answer |
|---|---|
| Does a `Label`'s `text` change when it is translated? | **No.** `text` still reads `Play`; the screen shows `Jogar`. Its minimum width went from 33 to 40 px, the width of a Label holding the literal `Jogar`. The translation happens when the text is shaped, not in the property. |
| What does `atr()` return? | The translation, while the node may auto-translate (`Jogar`); the text unchanged when `auto_translate_mode` is `DISABLED` (`Play`) -- while `tr()` on that same node still returns `Jogar`. So `node.atr(node.text)` is what the screen shows, and `test-locale-screen` reads that. |
| Does `draw_string` translate? | No: it shapes the string it is given. (Not measurable headless -- nothing is rasterised -- so this is the class reference's silence plus the source; every overlay word goes through `tr()` before it is drawn, and `check_translations_game.py` holds that.) |
| When is `NOTIFICATION_TRANSLATION_CHANGED` sent? | On entering the tree and on each `set_locale`, synchronously. Inside `_ready`, `is_node_ready()` is already true, so a node that changes the locale in its own `_ready` gets the notification before the rest of `_ready` has run -- the menu sets the language after building its Controls for that reason (a SCRIPT ERROR found it). |
| Which locale does the engine start in? | **The system's.** With `LANG=pt_BR.UTF-8` the startup locale was `pt_BR`; with `en_US.UTF-8`, `en_US`. So on a Portuguese machine every test that reads English words would read Portuguese; the checkers and search suites set `en` in `before()`. |
| A `pt_PT` system? | `set_locale("pt_PT")` answered from the `pt_BR` table (the nearest language). `Language` says `pt` → pt-BR by rule anyway. |
| A table with only `en,pt_BR`? | Works: in English `tr()` returns the key itself. No `en` column needed. |
| `?context` (4.6+)? | A table with a `?context` column was stored uncompressed and kept its contexts apart. But a **compressed** table (the default, any table without contexts) answers its key whatever context is asked: with `Play` in one and `Play`/`a card` in another, `tr("Play", "a card")` returned the first's `Jogar`. A key with a context must not also appear without one -- rule L6. |
| A byte order mark? | Imported without complaint, and the key read correctly. The documentation still asks for UTF-8 without one, and Excel writes one, so the gate refuses it (L4). |
| A fresh checkout without the `.translation` files? | `--import` printed `ERROR: Cannot open file 'res://locale/....translation'` for each, because the engine loads the project's translation list before it imports -- and `make import` fails on any ERROR. Hence they are committed. The import is deterministic (same bytes from the same CSV, checked by hash). |

Not used: the project's `internationalization/locale/test` setting, which
the documentation warns ends up in version control; and `--language`, since
the menu sets the locale through `TranslationServer` and the gate does the
same.

## The gates

- `scripts/check_translations_game.py` (`make lint-translations-game`),
  for each module that has a table: no literal with a word in it handed to
  `draw_string` or assigned to a `.text` outside a translation call (L1);
  every literal key in its table with a non-empty `pt_BR` (L2); no orphan
  row (L3); the table well formed and without a BOM (L4); the same
  `{placeholders}` on both sides (L5); context shadowing (L6). It cannot
  follow a key through a variable -- a rule's reason, kept in English
  because the rules' vectors state it so, or a board's name.
- `godot/test/locale/locale_screen.gd` (`make test-locale-screen`) opens
  checkers, the search demo and the menu in pt-BR, steps them, and fails
  on any Control line or legend entry that is the English of a translated
  key -- which is where a key passed through a variable is seen. Its
  planted case is a Label with auto-translation off.

## Adding a language string

Write the English in `tr()`, add the row to the module's table, run
`make import`, and commit the CSV with its `.translation`.
