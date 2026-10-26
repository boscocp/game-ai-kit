# Review: wave/91-turn-based-demos-speak-portuguese

A fresh context reviewed T79 at 8d06646 (PR #30). That head held tables
for five more modules (skirmish, tictactoe, tactical, stealth,
demo_behaviour), the five demos through `tr()`, rule L8 in
`check_translations_game.py`, the fix to `locale_screen.gd`'s error count,
and the suites that pin English. The reviewer ran the gates under both
LANGs, opened the demos in pt-BR, and planted cases of its own.

**Verdict: no blockers; two should-fix and nits, to be applied before the
merge.**

On the same day the owner set a rule and approved the proposed
translations. Code, identifiers and the docstrings in the code stay
English. Only documentation and prose on screen go to pt-BR. A term with no
good translation stays English and is defined in the pt-BR glossary. Of the
translation choices: "pode seguir como sugerido".

## Findings

1. **Board refusals showed English in pt-BR** (should-fix).
   - `BoardState.why_*_refused` reaches the screen through
     `refused: {why}` (`TacticalStatus`, skirmish `main.gd`), and
     `tactical.gd:_explained` appended Portuguese to an English
     "… is blocked".
   - Probe: the tactical match in pt-BR, the red workshop, a ram before the
     forge. The screen read `recusado: ram needs the forge upgrade first`.
   - No gate saw it: `locale_screen` never provoked a refusal, and the
     board has no table.
2. **The `RIGHT_WHEN` test could pass on nothing** (should-fix). It looped
   over the addon's rows. A row renamed to "finite state machine", with its
   text changed, gave 21 cases and 0 failures, while `_when_right()` then
   showed "" on the screen.
3. **Nit:** nothing said why the controller shows "learned policy" while
   the roster and the league say "learned".
4. **Nits, pt-BR:**
   - "beats" was "bate" in the legend and "vence" elsewhere.
   - MENACE took an article in some lines and not in others.
   - "(vantagem dele)" and "{name} não podia mais ser feito" did not agree
     with feminine names.
   - The stealth guard's state read "investigar". L8 forced it, because the
     tree node shares the key.
5. **Nit:** `tree_team.gd:_answered` translated before it tested
   `ends_with(": running")`, and its `# not shown` sat on a line that is
   shown.
6. **Nit:** `planned_blue.gd` crossed 400 lines this wave (403), and
   `learned_blue.gd` grew from 413 to 421.

Sound, by the reviewer's reading:
- The AI's decisions are unchanged. Only the words changed, and
  `make test-decisions` and the tactical suites agree under both LANGs.
- Translated strings are fed to logic only in tests, and those tests pin
  `en`.
- The `locale_screen` fix is real: a parse error planted in tactical made
  it fail, and before the fix it passed.
- Every committed `.translation` is fresh against its CSV.
- T78's review findings did not recur:
  - every pt-BR legend line fits;
  - no suite depends on the machine's locale or on the shared settings
    file;
  - no sentence is glued from English grammar;
  - every scene applies the saved language when it is opened alone.

## What was done about them

1. **`TacticalRefusal`** (`godot/game/tactical/tactical_refusal.gd`)
   translates a board refusal where it is shown.
   - It holds the shapes the board writes as keys, such as `{kind} needs
     the {upgrade} upgrade first`, matches a refusal against them, and
     translates the piece and upgrade names inside it.
   - Copy rather than a table for `board`: the board's English is data.
     The AI compares it, and the RTS and the tests read it. Translating at
     the source would change what callers in untranslated modules read.
   - Used by `TacticalStatus`, skirmish `main.gd`, `_explained`, and the
     rules' and the planner's reasons that quote a refusal.
   - `tactical_refusal_test.gd` reads `board_state.gd` and holds every
     refusal it can return to a shape. Rewording "is off the board" made it
     fail.
   - `locale_screen` now provokes the ram-before-forge refusal and fails if
     none is shown. With `TacticalStatus` mutated to show the raw refusal,
     it reported `recusado: ram needs the forge upgrade first` as English.
   - The planner's identifiers stay English by the owner's rule:
     `cross_the_river_ram`, `build_ram`, `h_max`, `pressure`, the facts.
     `docs/godot/localisation.md` and T79's manual check say so, and the
     glossary defines them.
2. **The test asks `_when_right()` by each of the four brains' own
   names.** It asserts a non-empty answer that is in `RIGHT_WHEN`. The
   rename mutation now fails, with "state machine: no row in WaysToDecide".
3. **`docs/godot/localisation.md` explains "learned policy":** one key has
   one translation (L8). A `?context` would not keep the two apart either,
   because checkers' context-free "learned" row answers for it (L6).
4. **pt-BR:**
   - "beats" is "bate" throughout tactical. The legend needs the short
     word.
   - "MENACE" is a key, "o MENACE", so perfect play reads "o MENACE vence".
   - The HTN's reasons read "o passo {name} já não podia ser feito" and
     "o método {name} ficou possível".
   - The fight reads "(vantagem inimiga)".
   - The stealth guard names its states through its own keys
     (`STATE_WORDS`). Its English reason line now says "investigating", and
     pt-BR says "investigando".
5. **`_answered`** tests for the running answer first and translates the
   label after. Each marker comments on what it excuses.
6. **Line counts:**
   - `planned_blue.gd` is 399 lines: `_mark` is shorter.
   - `learned_blue.gd` is back to 413 lines, its size on main, by joining
     short `.format` continuations. Getting it under 400 would take a split
     that did not read better.

The glossary (`docs/techniques/glossary.pt-BR.md`) gained the English the
five demos leave on screen, after wave 90 merged and this branch was
rebased on it.

Re-run after the fixes, under `LANG=en_US.UTF-8` and `LANG=pt_BR.UTF-8`:

| Command | Result |
|---|---|
| `check_translations_game.py` | 0 |
| `check_translations_game.py --self-test` | ok |
| `make test-locale-screen` | 8 examples, 0 failures |
| `make test-demo-overlays` | 14 examples in en and in pt_BR, 0 failures; the `free` SCRIPT ERRORs are the planted crash, as on main |
| `make test-godot-some SUITES="test/tictactoe test/stealth test/demo_behaviour test/locale test/skirmish test/tactical"` | 467 cases, 0 failures, no SCRIPT ERROR |
| `make test-decisions` | 3 scenarios, 0 failures |
| `check_readability.py`, `make lint-modules lint-tasks lint-status` | green |
| `check_translations_docs.py` and `--self-test`, `check_links.py`, `check_doc_freshness.py` | green |

`make check` was not run (the owner's instruction for this round).

Not yet done, and only a person can do it: T79's manual check.
