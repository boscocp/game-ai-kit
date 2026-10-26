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

## The real-time demos (T80)

The steering demo, both racers, the bot match, the infiltration level, the
RTS and the fighting game, by the same rules, with what they added:

- **Names, one class per demo.** Each 3D or real-time demo shows dozens of
  identifiers its logic compares -- an action, a squad's state, a unit's
  kind, a guard's phase, a zone. `BotMatchWords`, `InfiltrationWords`,
  `RtsWords` and `FightWords` list every one (`SHOWN`, marked
  `# shown through tr()`, so the table must hold each) and translate it
  where it is drawn. A test per demo holds the list to the data and the
  constants that write the names (`actions.json`, `guard_types.json`,
  `RtsKinds`, `FightAction.ACTIONS`...): a name added there and not here
  would show English with no sound. Where another table already translates
  the same English word for another sense -- checkers' "red" pieces, its
  "played" move, the bot match's "sprint" pace against the infiltration's
  "sprint" sound -- the name is shown through a key of its own (`SAID_AS`),
  as L8 requires. In English the bot match's watched line says "(blue
  team)" where it said "(blue)"; its switches have a key per team, so they
  still read "blue: claims on, ...". A kind of unit takes its article from
  `RtsWords`' own keys ("a lab", "the tower", "3 workers"): Portuguese
  gives a tower and a barracks different genders, so no sentence glues an
  article before a name.
- **English that is data, translated where shown, by shape.** The RTS
  rules (`ai_rts_core`, no table) word their refusals in English and the
  AIs read them; `RtsRefusal` copies their shapes as `TacticalRefusal`
  does, and a test reads `rts_rules.gd` and holds every refusal to one.
  The fighting rules write each frame's events in English into the frame's
  digest, which `test-replay` compares; `FightWords.event` matches them by
  shape, a reason in brackets on its own, and a test replays every recorded
  fight in `data/fights/` and holds each event it makes to a shape (it
  found "trade", which no shape had). The perception addon's eye reasons
  (`VisionShape.percept`) are copied the same way, in `InfiltrationWords`.
- **Reasons the AI keeps are keys, not words.** An RTS queue's wish, a
  squad's focus and its last arrow, the clone's "found" are kept as a
  `Sentence` (`godot/game/sentence.gd`): the English key and its values,
  a value a number, an identifier or another sentence. `RtsThinking` and
  `FightingPanel` word it with `Sentence.translated` where they show it;
  the overlays and the tests read `Sentence.english`. A fighting
  opponent's decision is kept as identifiers -- the option drawn, whether
  it was fumbled late or came out as another, the move or the step in --
  and its `choice` stays the English it always was. So the AI's state and
  every overlay are the same in any language, and a language switched mid
  match rewords the panel at once. T80 first worded these where they were
  made, as T79 had the tactical teams do; the review refused it -- the
  owner's rule is that code and identifiers stay English and the prose is
  translated where it is shown -- and T104 brings the tactical match to
  the same shape.
- **What stays English on screen**: a plan's step names and facts in the
  RTS (`build_lab`, `mortars_ready`), as the tactical planner's; a fighting
  move's name and the frame data's terms (`jab`, startup, active, recovery,
  hitstun) and the characters; the clone's case key and its feature names,
  which are the recordings' columns; the frame data's own refusals, which
  speak to whoever edits the JSON, in its keys' language. The glossary
  defines the terms. The pad's legend line (`PadAsKeys.add_to`, in
  `game_shared`, which has no table) is still English: key and button
  names, and the words "pad" and "stick" (T103).
- **Numbers.** A number a person reads as prose follows the language's
  decimal separator, through `Language.decimal`: the 2D racer's winning
  margin ("vence por 1,4 s") and the 3D racer's last lap time. Every other
  number on these panels -- speeds, PID terms, scores, grip, probabilities
  -- is a measurement, and keeps the point in both languages, as every
  number a gate or a log parses does. km/h, m, s and m/s^2 are not
  translated.
- **Every frame.** The 3D racer's status, the bot match's and the
  infiltration's panels and HUDs are rebuilt every frame, as they were
  before: each sentence is one lookup and one `format()`. A lookup measured
  0.56 µs (pt-BR, 100,000 lookups, eight tables loaded); a `format()` with
  a dictionary 0.52 µs, against 0.35 µs for the `%` it replaced. The bot
  match's panel makes about forty lookups a frame -- a fortieth of a
  millisecond. Text drawn in a loop that does not change with the frame
  (the steering lanes' titles) is looked up once per language, on
  `NOTIFICATION_TRANSLATION_CHANGED`. `test-rts-budget` and
  `test-rts-match` hold the RTS's frame shares as before.
- **A line that fits.** `test-locale-screen` now opens these seven demos
  too, reads a `Label3D` as it reads a `Label`, provokes an RTS refusal,
  and fails a line of a Label that does not wrap and runs past the
  1280-pixel window, measured in the Label's own font (planted: a line of
  400 "x"). It found the bot match's errand line and four of the search
  demo's lines too long in pt-BR (shortened, the bot match's split in two),
  and the tactical match's header too long in English as well -- a layout
  fix, not a translation one, so it is named in `NOT_YET_FITTED` and left
  for T102. Only a visible Label that does not wrap is measured: a Button,
  a Label3D, a HUD drawn with `draw_string` and a panel shown only when
  toggled are not.

## The tactical screen fits, and a wrapped Label is measured (T102, wave 100)

- **The header wraps, over the board and the legend.** The tactical header
  was three lines, each its own width, the rule line 2,005 px in English
  and 2,408 in pt-BR. It now wraps at 12 px inside x=304..1256, over the
  board and the legend only, and its last line ends at y=125 at worst (the
  learned policy's description in pt-BR), 19 px above the board.
- **The status has the whole left column.** It runs from y=8, level with
  the header, to the gutter above the window's bottom, at 13 px. The line
  naming every controller C cycles through has a line of its own under the
  board, `Interface/Keys`, shown on either turn (it ends at y=689). On the
  computer's turn one blank line, before the decision, is kept; the news,
  the keys, the count and the plan follow without one. Nothing the status
  said was dropped.
- **Measured over played games, not the opening screen.** T102's first
  version measured round 1 only, and its review played whole games: the
  planner's turn in round 3 -- a strike's news, a long "stays" reason, four
  decisions played, six plan steps -- ended at y=771 in English and 834 in
  pt-BR, plan steps 5-6 off the window. `test/tactical/tactical_layout_test.gd`
  now plays ten rounds of a seeded game under every controller in both
  languages, twice (the person waiting, and the person sending each unit
  at the nearest enemy, a strike or a refusal), and takes the lowest the
  status's words go at every computer decision and with each of the
  person's units in hand. Worst now: y=656 (planner, round 3, pt-BR) and
  593 in English, against a limit of 696. That is what is measured: other
  games, longer than ten rounds or with the person walking, are not.
- **A wrapped Label is measured whole.** Measured on the pinned engine: a
  Label that wraps reports, as its minimum height, the height of its
  wrapped words, and grows to it past the size it was given (the tactical
  status, given 552 px, held 569). `test-locale-screen` now measures every
  visible wrapped Label too: its rectangle inside the window's width, and
  its words ending the gutter (24 px) above the bottom -- planted: a
  wrapped Label too tall and one too wide. It found three more, named in
  `NOT_YET_FITTED` and left for T107: the behaviour demo's status (711 in
  both languages), the skirmish's (716 in pt-BR) and the RTS card's info
  (741 in pt-BR, 721 in English: past the window). Each is named with the
  y it was measured at, a ceiling: one that gets lower still fails.
- **What stays English.** A plan's steps show as the code names them
  (`buy_the_forge`, `cross_the_river_ram`) in pt-BR too, as the glossary
  says (`docs/techniques/glossary.pt-BR.md`). Every difficulty preset says
  "plans 0 actions ahead": that is the data, not a fault of `describe()` --
  each preset's `plan_horizon` is 0, no plan at all, because a plan was
  measured to make a side weaker on this board (`Difficulty.presets()`).
- **An addon's English, worded by the game that shows it.** The difficulty
  levels on the tactical header said `Difficulty.describe()`'s English in
  pt-BR (`ai_planning`). No addon here calls `tr()` -- an addon depends on
  `ai_core` only, never on a game's tables -- so `describe()` stays
  English, for the logs and `difficulty_knobs.gd`, and `DifficultyWords`
  in the tactical game copies its sentence as keys. A test holds the copy
  to the addon: equal in English, no English word left in pt-BR, and every
  field of `Difficulty` named in `DifficultyWords.FIELDS` (a planted
  field, and a reworded `describe()`, each fail it).

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
  skirmish, and since T80 the steering demo, both racers, the bot match,
  the infiltration level, the RTS and the fighting game) and the menu in
  pt-BR, steps them, and fails on any Control or `Label3D` line, or legend
  entry -- whole, or one of its "  ·  "
  segments -- that is the English of a translated key, a `{placeholder}`
  matching any text. It fails an example that lacks the nodes it should
  show words in, or shows no line at all. Planted: a Label with
  auto-translation off, a formatted English segment ("cost 7"), a line
  too wide for the window, and an empty scene. Before it runs, the target refuses a committed
  `.translation` that `make import` rewrote while its CSV did not change: a
  table committed with stale words.

## Adding a language string

Write the English in `tr()`, add the row to the module's table, run
`make import`, and commit the CSV with its `.translation`.
