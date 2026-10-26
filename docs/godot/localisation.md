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
  L, or Y on a pad switch it and save it. A translated example opened on
  its own (`make run`, `make demo-search`) applies it too, through
  `Language.apply_if_opened_alone` -- only when it is the main scene, so a
  test that opens it, or the menu, keeps the language it set.
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
  field says in English in Brazil (A\*, Dijkstra, minimax, alpha-beta --
  `docs/techniques/glossary.pt-BR.md`), and the `##` help of `make`
  targets. Breadth-first and depth-first are shown as "busca em largura" and
  "em profundidade", which the glossary allows.
- Code stays English, the owner's rule (2026-10-26): identifiers, and the
  docstrings in the code. Only the documentation and the prose on screen are
  translated. So a planner's identifiers stay as the code writes them even
  in pt-BR: STRIPS step names (`cross_the_river_ram`, `build_ram`), facts
  (`point_free`, `in_danger`), the guide's name (`h_max`), GOAP's goal name
  (`pressure`). A term with no good translation stays English and is defined
  in the pt-BR glossary.
- A refusal the board writes. `BoardState` words its refusals in English,
  and the logic, the RTS and the tests read those words, so they are not
  translated where they are written. `TacticalRefusal` copies the shapes the
  board writes as keys (`{kind} needs the {upgrade} upgrade first`) and
  translates a refusal where it reaches the screen; a test reads
  `board_state.gd` and holds every refusal it can return to one of the
  shapes, and `test-locale-screen` provokes one (T79's review).
- A Portuguese line is longer. `make test-demo-overlays` steps every example
  in English and again in pt-BR, and fails a legend line that runs off the
  window -- two of the search demo's did, and were shortened.
- Every table is loaded into the one `TranslationServer`, so a key has one
  translation in the whole game, whichever module's table holds it. T79
  found the stealth guard's "investigate" and the behaviour tree's said two
  things; rule L8 refuses that now. A context cannot keep two meanings
  apart either, while one table holds the key without one (L6). So the
  tactical match shows the controller "learned" as "learned policy": the
  roster and the league still call it "learned", and checkers' "learned"
  (its weights, "aprendidos") already holds that key.
- Names the code shows (T79). A brain's states, a tree's nodes, a deed's
  name (`walk_round`), a goal's fact (`player_caught`) are identifiers the
  logic compares, so they stay English in the code and are translated
  where they are drawn: the behaviour demo's panel translates each name of a
  line and keeps the addon's notation, "from -> to: why" and "name:
  answer". In English the screen still shows the identifier as it is
  written; in pt-BR it shows words. Text an addon writes in English
  (`WaysToDecide`'s table, a tree node's answer) is copied into the demo
  that translates it, and a test holds the copy to the addon's words, since
  a changed key would fall back to English without a sound.
- A sentence is not glued from English grammar. Where the English built a
  plural by trimming an "s", or a square's name with "the " in front, there
  is now a key per case, and the Portuguese puts the name where Portuguese
  puts it.

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
| A byte order mark? | Imported without complaint, and the key read correctly. The documentation still asks for UTF-8 without one, and some editors, and Excel's "CSV UTF-8", write one, so the gate refuses it (L4). |
| Is a scene opened by the engine already `current_scene` in its `_ready`? | **Yes** (`current_scene == self` printed `true` for a scene run as `godot --path p res://alone.tscn`). The menu sets `current_scene` after `add_child`, and a test never does, so `apply_if_opened_alone` tells the three apart. |
| A fresh checkout without the `.translation` files? | `--import` printed `ERROR: Cannot open file 'res://locale/....translation'` for each, because the engine loads the project's translation list before it imports -- and `make import` fails on any ERROR. Hence they are committed. The import is deterministic (same bytes from the same CSV, checked by hash). |

Not used: the project's `internationalization/locale/test` setting, which
the documentation warns ends up in version control; and `--language`, since
the menu sets the locale through `TranslationServer` and the gate does the
same.

## The gates

- `scripts/check_translations_game.py` (`make lint-translations-game`),
  for each module that has a table. L1 is inverted: in a translated
  module, every literal that says something -- a letter and a space, or a
  key of the table -- passes a translation call, is a key into data
  (`.get("x")`, `x["y"]`, `{"x": ...}`, a `res://` path), or carries a
  marker where its statement starts: `# shown through tr()` (an English key
  translated where it is shown, such as a rule's reason the vectors state in
  English, or a const list read as `tr(NAMES[i])`; L2 then holds it to the
  table) or `# not shown` (data, a comparison). A literal handed straight to
  `draw_string`, `set_text`, `Legend.set_entries` or a `.text` must be
  translated even as one word. The first L1 looked only inside the drawing
  statement, and the review ran it over the untranslated checkers and search
  with these tables: 0 findings for some ninety English strings; the
  inverted rule gives 132. Then: every key in its table with a `pt_BR` (L2);
  no orphan row (L3); the table well formed and without a BOM (L4); the
  same `{placeholders}` on both sides (L5); no context shadowed (L6); no key
  built inside the call, `tr("wins %s" % name)` (L7); no key translated
  two ways by two tables (L8, T79).
- What it still cannot see, said plainly: a one-word literal that is not a
  key of the table and does not go straight to a drawing call is taken for
  data; text written in a `.tscn` is not read (the scenes say "loading" and
  are filled from code); the `?plural` column and `tr_n()` are not checked,
  since nothing uses them yet.
- `godot/test/locale/locale_screen.gd` (`make test-locale-screen`) opens
  each translated example (checkers, the search demo, noughts and crosses,
  the stealth hall, the four-brained guard, the tactical match, the
  skirmish) and the menu in pt-BR, steps them, and fails on
  any Control line or legend entry -- whole, or one of its "  ·  "
  segments -- that is the English of a translated key, a `{placeholder}`
  matching any text. It fails an example that lacks the nodes it should
  show words in, or shows no line at all. Planted: a Label with
  auto-translation off, a formatted English segment ("cost 7"), and an
  empty scene. Before it runs, the target refuses a committed
  `.translation` that `make import` rewrote while its CSV did not change: a
  table committed with stale words.

## Adding a language string

Write the English in `tr()`, add the row to the module's table, run
`make import`, and commit the CSV with its `.translation`.
