# The examples in Portuguese

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html ; https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_spreadsheets.html ; https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-property-auto-translate-mode ; https://docs.godotengine.org/en/stable/classes/class_label.html ; https://docs.godotengine.org/en/stable/classes/class_control.html
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
  match rewords the panel at once. The owner's rule is that code and
  identifiers stay English and the prose is translated where it is shown;
  the tactical match and the skirmish keep theirs the same way since T104
  (below).
- **What stays English on screen**: a plan's step names and facts in the
  RTS (`build_lab`, `mortars_ready`), as the tactical planner's; a fighting
  move's name and the frame data's terms (`jab`, startup, active, recovery,
  hitstun) and the characters; the clone's case key and its feature names,
  which are the recordings' columns; the frame data's own refusals, which
  speak to whoever edits the JSON, in its keys' language. The glossary
  defines the terms. On the pad's legend line, the key names and the names
  printed on the pad (A, LB, View, Menu, LT); the rest is translated since
  T103, below.
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

## Three panels fitted, each over a played game (T107, wave 105)

- **The behaviour demo's status** is 13 px (16 before): its three lines,
  under the board, end at y=696 -- the gutter, with no pixel to spare --
  under each of the four brains over 300 turns, in both languages. They
  ended at 711 at 16 px. `behaviour_layout_test.gd` holds it.
- **The skirmish's status** runs the whole left column from the gutter at
  the window's top, at 16 px (18 before); the legend stays level with the
  board. The opening screen was not its longest: blue's reasons stay on it
  into red's turn, a refused click and a held node each add a line, and at
  18 px red's round-2 turn with a refusal ended at y=861 in pt-BR.
  `skirmish_layout_test.gd` plays twelve rounds with red waiting, refused,
  and walking onto the nodes. The column is what makes the room: kept level
  with the board, even 14 px ended at 717. With the column, 18 px still
  fails (833 in pt-BR) and 16 px, the largest that fits, ends at 671 in
  pt-BR (red walking, a refusal) and 593 in English. `BoardLayout.lay_out`
  now takes the status column's top, so the tactical match (the header's
  top) and the skirmish (the gutter) share one layout instead of each
  moving the status after it.
- **The RTS card's info** takes the whole card when it has no buttons --
  with nothing selected, how to play -- and its own 330 px beside them
  otherwise (the width the scene gives it, read in `_ready`): y=661 in both languages, where it was 741 in pt-BR, a line cut
  off. `rts_layout_test.gd` selects nothing, each unit alone (yours and the
  computer's, revealed) and a box over yours, over six minutes the queues
  play; it measures `Why`, the reasons under the buttons, too: 695 at worst.
- **`NOT_YET_FITTED` is empty**, and kept with its planted cases.
- **Measured: Control's combined minimum size lags a resize by a frame.**
  The 4.7 Control page: `get_combined_minimum_size()` "returns the combined
  minimum size from custom_minimum_size and get_minimum_size()", and
  `update_minimum_size()` "invalidates the minimum size cache". Measured on
  4.7.2, a wrapped 12 px Label, after a frame in the tree:
  - its width 330 -> 748 px: `get_minimum_size().y` is right at once (137),
    `get_combined_minimum_size().y` still says 317, the old width's height,
    until the next frame;
  - its font 12 -> 16 px: the same, 257 at once, 137 cached for a frame;
  - its text changed: both right in the same frame.

  So the Label is reshaped at once; what lags is Control's cached combined
  size, after a resize or a font change and not after a text change. The
  screen is drawn after the layout, so it is right; `rts_layout_test.gd`,
  which widens the info, waits a frame before reading it. The behaviour and
  skirmish tests change only the text, and need no wait.
- **The planted cases are sharper.** The wrapped Label planted too tall
  now ends 4 px past the gutter, not 200 lines past it, and one more ends
  2 px under a ceiling it is given as if `NOT_YET_FITTED` named it: with
  the ceiling read as an exemption, that one passes and the check fails.

## The pad's line (T103, wave 109)

- **`game_shared` has a table**, `godot/locale/game_shared.csv`, for the
  one line it writes on every real-time demo: the pad's, under the legend
  (`PadAsKeys.add_to`). "pad: {bindings}" is "controle: {bindings}" (the
  menu already said "No controle"), "stick {keys}" is "analógico {keys}"
  -- "left stick", "analógico esquerdo", where the right stick looks too
  -- the D-pad's directions are words ("D-pad cima"; "D-pad" stays, as the
  menu's line keeps it), and the right stick looking and RT clicking are
  two keys. The names printed on the pad (A, LB, LT, View, Menu) stay, as
  do key names a key prints (Shift, Tab, W). Not the engine's English for
  keys that print no word: `OS.get_keycode_string` writes "Space", "Up",
  "Period", and the first version left them in the pt-BR line (wave 109's
  review). They are "espaço", "cima"/"baixo"/"esquerda"/"direita" and "."
  now, as the kit's other tables say them; the four arrows together are
  "setas", and the D-pad's four directions bound together are one binding,
  "D-pad setas". Arrows would be shorter, and the legend's font has none
  (`ThemeDB.fallback_font.has_char(0x2190)` is false). The glossary names
  D-pad, the pad's printed names and the stick.
  Every demo with a pad already called `add_to` after `set_entries` in the
  legend rebuild it runs on `NOTIFICATION_TRANSLATION_CHANGED`.
- **A pad planted for the checks.** None can be connected headless, and
  the line is written only when one is. `PadAsKeys.planted` writes it
  anyway; nothing in a game sets it. `test-locale-screen` plants it and
  fails an example with a pad whose legend does not show the pad's lines
  as the pad writes them now, and reads each binding as well as the line
  ("stick A/D/W/S" is the English of "stick {keys}", "LT Down" ends in
  the English of "Down"). Planted: a legend whose pad line was written in
  English and not rebuilt. `test-demo-overlays` plants it too, so the
  legend is measured with the pad's lines, in both languages, and fails an
  example with a pad none of whose lines reached the legend (planted: one
  such example) -- without that, a plant ignored would measure nothing.
  `make test-pad` reads the line for English words in any case: the
  first claim was lowercase and case-sensitive, and passed "Space".
- **The line breaks at the legend's width, not every three bindings.**
  Planted, the English line ran off the window at three a line in the 2D
  racer (x=1355), the stealth hall (1358) and the 3D racer (1303): it had
  never been measured, since no gate had a pad. `legend_lines` now puts on
  a line as many bindings as fit `Legend.words_width()`, the legend's own
  width past its swatch, measured in the legend's font.
- **The legend's height, fitted (T108, wave 117).** No gate measured how
  far down a legend's lines go, and with a pad some went past their box:
  the bot match's ended at y=742 of a 720-pixel window, the 2D racer's at
  256 (en) and 276 (pt-BR) over its status at 200, the 3D racer's at 214
  over its status at 164, the maze's at 222 against its `Decision` at 220
  -- and the infiltration's at 742, which nobody had listed (a pixel or
  two lower than T103's figures: the gate counts the last line's descent,
  `Legend.drawn_height()`). `test-demo-overlays` now fails, for every
  example with a pad, in both languages, a legend whose last line ends
  below the gutter (y=696) or less than 8 px above any visible Control
  that starts below its top and shares its width. 8 px is chosen, not
  measured: half a line, enough to read two blocks as two. Planted: a
  legend past the window, one over the Label below it, one touching it
  (the maze's case), and one 8 px clear, which must pass. Every pad line
  is kept; per example:
  - the bot match's legend starts at y=480, not 540, and ends at 682;
  - the infiltration's at 440, not 500, and ends at 682;
  - the maze's at 8, not 20, and ends at 210, 10 px above `Decision`;
  - the 2D racer's status follows the legend, 12 px under its last line
    (`BELOW_LEGEND`; 268 in English, 288 in pt-BR, 208 with no pad), and
    the minimap moved to the view's bottom-left corner (16..326 x
    476..644) to leave it the room: in pt-BR its words end at 684. They
    used to end at 596, over the minimap at 544, which nothing measured;
  - the 3D racer's status follows its legend the same way (226), the
    trace moved under it (528..600), and the map to the view's
    bottom-left corner (12..374 x 518..696).
  Not measured: the RTS has no pad, and its legend ends at y=160, 6 px
  above `Thinking` at 166 -- the rule, applied there, would fail it.

## The tactical AI keeps its reasons as keys (T104, wave 108)

- **What changed.** Every reason a tactical team gives -- the rules, the
  planner, the difficulty levels, the learned policy, the four techniques
  -- and the skirmish's learned opponent's is a `Sentence` now:
  `TacticalDecision.reason` and `LearnedDecision.reason`, the planner's
  `why_planned`, a technique's `thinking()`, the policy's
  `why_unusable_sentence()` and the weights' `error_sentence()`. Before,
  each was worded with `tr()` when the team decided (T79), so the reason
  an AI kept was in the language on screen at that moment.
- **Values.** A piece with its article is a nested sentence
  (`TacticalStatus.the_piece_sentence`, `a_piece_sentence`: "the bolt
  tower" has its own key, as before); several pieces or deeds are a chain
  of nested sentences (`listed`, "mortar, ram"; `in_order`, "hunt then
  siege"), each worded on its own. A string value is worded by
  `TacticalStatus.word`: a board's refusal by its shape
  (`TacticalRefusal`), and every other string through the tables. A
  piece's name or a deed is a key there and is translated; a plan step, a
  fact, a GOAP goal's name, a number, a W or M code is not, and comes back
  as it is -- for now. A step or fact that one day became a key of any
  table would be translated in every reason that holds it.
- **Keys that are only shape.** `"{first}, {rest}"`, `"{only}"`,
  `"{step}: {reason}"`, `"{reason} -- {more}"`,
  `"{deed} -- {thinking}: {reason}"`, `"{code} {said}"`,
  `"{said} ({source})"`, `"{refusal}"` and `"{error}"` join sentences and
  say nothing of their own, so they are deliberately not in the table: the
  engine returns a key it has no row for as it is, and the gate counts only
  literals with a word in them.
- **Where it is worded.** `TacticalStatus.said` on the screen: the
  status's "next" line, the plan's lines (`plan_lines(say)` takes the
  wording, `said` for the status and `Sentence.english` for the
  overlay), the skirmish's "blue this turn" and the number over blue's
  next move (`PlanView.number_sentence`). Both scenes already rebuild
  their status on `NOTIFICATION_TRANSLATION_CHANGED`, so a language
  switched mid-turn rewords the reason on the panel.
- **What is English whatever the language**: `decision.english()`, the
  overlays (`why`, the plan, `to_move`, the skirmish's `reason` and
  `number`), and so every test that compares a reason. Measured:
  `tactical_reasons_test.gd` plays six rounds of a seeded game under every
  controller in English and in pt-BR and finds the same overlay at every
  decision; `skirmish_reasons_test.gd` the same for blue; `make
  test-decisions` now plays its three scenarios in both languages. With
  the overlay's `why` worded for the screen instead, the first fails; with
  `LearnedDecision.english()` worded, `test-decisions` fails in pt-BR
  ("contra", not "against").
- **Games where something happens.** That scene's person never moves, so
  no walker of the computer's ever retreats, falls back or defends, and
  the review planted a `tr()` in the fall-back's reason that every suite
  passed. So `tactical_reasons_test.gd` also has every controller play two
  whole seeded games against the rules, one in each seat, and holds every
  decision's English and the plan's lines equal in both languages; and it
  fails unless some game gave a fall-back, a defence, a retreat and a
  broken HTN plan. The planted `tr()` fails it now, and lint rule L9
  refuses a translation call inside `Sentence.of(...)`.
- **Pins dropped.** Five suites that pinned English only to read reasons
  (`technique_teams_test`, `tactical_bridge_test`, `learned_policy_test`,
  `tactical_spending_test`, `tactical_planner_test`) pin nothing now, and pass with the engine
  started in pt-BR (`LANG=pt_BR.UTF-8`). The suites that read the screen
  -- a header, a side's name, a refusal -- keep theirs.
- **Not in it.** The news of what was played (`TacticalCombat.told`,
  "built a runner at ...", the points paid) is still worded when it
  happens, and keeps the language it happened in until the next event:
  it is the game's report, not a team's reason, and the task's scope was
  the reasons. A state machine's arrow is the addon's own English string
  (`"advance -> take point: a control point is free"`) and a GOAP goal is
  named by its fact (`pressure`): both stay English inside a pt-BR
  reason, as they did before T104.

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
  two ways by two tables (L8, T79); no translation call inside
  `Sentence.of(...)`, a sentence an AI keeps (L9, T104's review; a value
  translated through a variable or a helper is not seen).
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
