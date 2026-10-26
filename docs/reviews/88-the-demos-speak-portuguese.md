# Review: wave/88-the-demos-speak-portuguese

A fresh context reviewed T78 at b41a1d4 (PR #27). That commit held the
translation tables, `Language`, the menu's switch, checkers and the search
demo in pt-BR, `check_translations_game.py`, `locale_screen.gd` and
`docs/godot/localisation.md`. The reviewer ran the gates, ran the demos
under `LANG=pt_BR.UTF-8`, and planted cases of its own.

**Verdict: fix first.**

## What was reviewed

- **Whether each gate can pass on nothing (invariant 4).** The static
  gate was run over origin/main's untranslated demos with the new tables,
  and the screen script was given an empty scene. Both were given planted
  shapes taken from the real code.
- **The demos under a Portuguese system.** `make test-demo-overlays`,
  `test-menu-walk` and the suites were run under `LANG=pt_BR.UTF-8` as well
  as `en_US`.
- **The saved choice.** Who applies it, and whether a test can read or
  leave the shared `user://settings.cfg`.
- **The claims in `docs/godot/localisation.md`.** Each one against the 4.7
  documentation, and the `.translation`'s determinism.
- **The wiring.** Ownership, the gates in `make check`, and what
  `check-affected` selects.

## Findings

1. **A pt-BR legend line ran off the window** (blocker). Under
   `LANG=pt_BR.UTF-8`, `make test-demo-overlays` failed: the search demo's
   "contorno branco: a célula que ela pega em seguida" reached x=1347 on a
   1280 px window. It passed in en_US. No gate measured fit in pt-BR, and
   `demo_overlays.gd` took whatever locale the machine had.
2. **L1 saw only literals written inside the drawing statement**
   (should-fix, invariant 4). Checkers and search build their text in
   helpers (`CheckersPanel.status` and `describe`, `_help_text`,
   `_status_line`, `value_words`) and in `Legend.set_entries`. Run over
   origin/main's untranslated checkers and search with the new tables, the
   gate found nothing in some ninety English strings. These planted shapes
   went unreported:
   - an untranslated legend entry;
   - "Edit the board" with no `tr()`;
   - "1-4 choose ..." with no `tr()`;
   - `var words := "you lose"; draw_string(font, p, words)`.
3. **`locale_screen.gd` could pass on nothing** (should-fix).
   - An empty scene added to its list produced no failure, and it did not
     count the lines it read.
   - It matched only a whole line equal to a key, so a `{placeholder}` key
     and one segment of a "  ·  " line were invisible. A planted
     `_route_cost` that returned the English "cost %d" was not reported.
4. **Only the menu applied the saved language** (should-fix). `make run` and
   `make demo-search` open a scene directly and ignored it.
5. **`menu_walk.gd` read the real shared `user://settings.cfg`**
   (should-fix): it used the menu's default path and did not pin the
   locale.
6. **Nits:**
   - The weights table's `%10s` misaligned under "▶ aprendidos" (12 chars).
   - `tr("wins %s" % name)` was not reported.
   - The docstring said nothing of `?plural` or `tr_n`, nor that `.tscn`
     texts are not read.
   - Nothing caught a stale committed `.translation`.
   - The BOM sentence needed rewording.
   - `search_demo_test.gd`'s `before()` sat above the consts, and neither
     suite restored the locale.
   - "não mais" read badly.
   - The `.gitignore` exception was wider than needed.

Sound, by the reviewer's reading:
- The `.translation` regenerates byte-identically from its CSV.
- The engine-error counter in `locale_screen.gd` works.
- Behaviour is unchanged apart from the text: the rules, the overlays'
  data and the tests' English assertions are the same.
- The CSV claims (first header cell ignored, `?context` from 4.6, UTF-8
  without a BOM, compression) agree with the 4.7 documentation.
- The wiring is right: `make check-affected` selects `test-locale-screen`
  through the menu's manifest.

## What was done about them

1. **The legend fits in pt-BR, and a gate checks it.**
   - Shortened: "contorno branco: a próxima célula". The pt-BR run then
     found a second line too long, "linha: a rota que a busca escolhida
     achou", now "linha: a rota da busca escolhida".
   - `demo_overlays.gd` takes `-- --locale=xx`, English by default and never
     the machine's.
   - `make test-demo-overlays` runs it twice, in en and in pt_BR. Both pass
     under `LANG=en_US.UTF-8` and under `LANG=pt_BR.UTF-8`. Before the
     second shortening the pt_BR run failed on that line, which shows the
     second run sees overflow.
2. **L1 is inverted.**
   - In a translated module, every literal that says something (a letter
     and a space, or a key of the table) must pass a translation call, be a
     key into data, or carry `# shown through tr()` or `# not shown` where
     its statement starts.
   - Marked keys are held to the table by L2, so the rule reasons and board
     names are now checked against it.
   - `set_entries` is a sink.
   - All four of the reviewer's shapes are planted, with a one-word key, a
     marker on a sink, and a lookup.
   - Over origin/main's untranslated checkers and search with these tables
     it now reports 132 L1 findings.
   - The card headings in `example_catalogue.gd` turned out to be
     untranslated too; they are now translated.
   - What it still cannot see is said in its docstring and in
     `docs/godot/localisation.md`: a one-word literal that is not a key, a
     `.tscn`'s text, and `?plural` / `tr_n`.
3. **`locale_screen.gd` can no longer pass on nothing.**
   - It reads each line whole and in its "  ·  " segments, and matches a
     key's `{placeholders}` as wildcards.
   - It fails an example that lacks the nodes listed for it, or shows no
     line at all.
   - Planted: a Label with auto-translation off, the formatted line "cost
     7", and an empty scene.
   - Mutated three ways, each failed for its own plant:
     - with the zero-lines check off, the empty scene;
     - with placeholders matched literally, "cost 7";
     - with `_route_cost` returning English "cost %d", the search demo's
       status line.
4. **A demo opened on its own applies the saved language.**
   `Language.apply_if_opened_alone(self)` runs last in checkers' and the
   search demo's `_ready`. It applies only when the scene is
   `current_scene`; measured on 4.7.2, a scene the engine opens as main
   already is, in its `_ready`. The menu and the tests are left alone, and a
   test holds that. Not an autoload: it would run in every test too, and
   read the shared settings file there.
5. **`menu_walk.gd` uses its own settings file,
   `user://menu_walk_settings.cfg`, and sets English after the menu opens.**
6. **The nits:**
   - The weights table pads each column by its translated heading; the
     English output is unchanged.
   - L7 refuses a key built with `%` or `+` inside the call.
   - The docstring says the limits.
   - `make test-locale-screen` first refuses a committed `.translation` that
     `make import` rewrote while its CSV did not change.
   - The BOM sentence is reworded.
   - Both suites set `en` in `before()` and restore the locale in
     `after()`, and `checkers_learned_test.gd` does too. Under pt_BR it
     failed on the panel's English, found by running the suites under both
     LANGs.
   - "não mostra mais".
   - `.gitignore`: `!godot/locale/*.csv.import`.
   - The glossary (T74) keeps "alpha-beta" in English; the table now does.

Each branch of the gate was mutated in turn:
- markers ignored on a sink;
- one-word keys not counted as words;
- only sinks;
- L7 off;
- marked keys not held to the table;
- lookups not excused;
- orphans off;
- the BOM check off;
- placeholders off.

Every mutant failed the self-test. The BOM mutant first survived, because
the header check also fired; that plant now expects the BOM message itself.

Re-run after the fixes:

| Command | Result |
|---|---|
| `check_translations_game.py` | 0 |
| `check_translations_game.py --self-test` | ok |
| `make test-locale-screen` | 0 failures |
| `make test-demo-overlays` under en_US and under pt_BR | 14 examples in each locale, 0 failures; the three `free` SCRIPT ERRORs per run are the planted crash, as on main |
| `make test-menu-walk` under both LANGs | 14 examples, 0 failures |
| `make test-godot-some SUITES="test/locale test/checkers test/demo_search"` under both LANGs | 107 cases, 0 failures, no SCRIPT ERROR |
| `check_readability.py`, `check_doc_freshness.py`, `check_links.py` | green |
| `make lint-modules`, `lint-status`, `lint-tasks` | green |

`make check` was not run (the owner's instruction for this round).

Not yet done, and only a person can do it: T78's manual check. Play
checkers and the search demo in PT-BR, look at whether the overlay fits its
panel, and see whether the choice survives closing the game.
