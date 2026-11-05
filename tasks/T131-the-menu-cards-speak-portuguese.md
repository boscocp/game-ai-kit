# T131 — The menu's cards speak Portuguese

Size: M · Prereqs: T78 · Files: `godot/locale/menu.csv`, `godot/locale/menu.pt_BR.translation`, `godot/menu/`, `godot/test/locale/locale_screen.gd`, `scripts/check_translations_game.py`, `docs/godot/localisation.md`, `docs/techniques/glossary.pt-BR.md`

## Goal

On 2026-11-05 the owner opened `make menu` in Português. Only the menu's
chrome was translated: the headings ("O que a IA decide", "Como ela
decide", "O que observar", "Teclas"), Jogar and the footer. Every card's
own words stayed English -- the titles, what the AI decides, each
technique's name and part, what to watch, the keys. They come from
`godot/menu/catalogue.json`, and `menu.csv` held only the chrome, 15 rows.
No decision to leave the cards English was found; `example_catalogue.gd`
said they were English "until the catalogue is translated". The owner
answered "as 3" to the proposal: translate the cards.

## Decisions written down first

- **Keys in `menu.csv`, not a table of the cards' own.** The rule is one
  table per module, owned by its manifest (`docs/godot/localisation.md`),
  and L4 refuses a table that names no module. The catalogue is the
  menu's file, so its words are rows of the menu's table, keyed by their
  English. No `?context`: the keys are whole sentences, and L6 then has
  nothing to shadow.
- **The catalogue stays English.** It is the one list `check_demos.py`
  reads, and its English is the key. The menu translates where a card is
  drawn, as the demos do.
- **What stays as it is**: a mode's title (Advance Wars, XCOM: the games'
  own names), the `docs` path and the `make` target. Technique names the
  glossary keeps English stay English (*minimax*, *alpha-beta*, A\*,
  *seek*, *GOAP*, *Monte Carlo tree search*...); a term with no row there
  is added (MDP).
- **A gate per half.** `check_translations_game.py` holds the words to the
  table (L10, statically); `test-locale-screen` holds what the menu draws,
  card by card.

## Steps

1. The rows: every shown field of the catalogue, written in Brazilian
   Portuguese, keyed by the English; `make import` and the `.translation`.
2. `ExampleCatalogue.said` words each card field where `text_of` draws it;
   the menu words the list's titles in `_retranslate` and the heading in
   `select`.
3. L10 in `check_translations_game.py`: `SHOWN_DATA` names the
   catalogue's shown fields; a word with no row, a field that finds
   nothing, or a catalogue whose module has no table fails; the words count
   as mentioned for L3. Self-test cases for the three.
4. `test-locale-screen` reads a `RichTextLabel` and an `ItemList`, splits a
   technique's "name -- part", and selects every card of the menu. Planted:
   a card and a list left in English.
5. The localisation page and the glossary.

## Acceptance

```bash
python3 scripts/check_translations_game.py
python3 scripts/check_translations_game.py --self-test
make test-locale-screen
make test-menu-walk
make test-demo-overlays
make test-godot-some SUITES="test/menu"
python3 scripts/check_translations_docs.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Open `make menu`, press L for Português, and walk the list from top to
bottom: does every card read as natural Brazilian Portuguese, with no
English sentence left, and the technique names the glossary keeps in
English kept? Press L again: does the card on screen switch back at once?
Does any title in the list run past its column? Nothing holds this:
measured with the fallback font at 22 px against the 360 px column, 10 of
16 pt-BR titles are wider (9 of 16 in English, so older than T131), the
widest about 835 px, and an `ItemList` item is one line trimmed with an
ellipsis by default. The owner decides between shorter titles and two
lines per item (`max_text_lines = 2`); the heading shows the whole title.

## Notes

- 187 rows: 16 titles, 16 each of decides, controls and watch, 72
  technique parts and 51 technique names. `seek`, `arrive` and `pursue`
  are rows of `demo_steering.csv` too, the same in both (L8).
- Planted on the real repository: `Checkers,Damas` removed from
  `menu.csv` gave `L10 godot/menu/catalogue.json: examples[].title shows
  'Checkers', which is not in godot/locale/menu.csv`, exit 1. In
  `locale_screen.gd`, the `RichTextLabel` and `ItemList` readings switched
  off made both planted cards fail by name; leaving the menu's old code in
  (the decides line and the list untranslated) failed every card.
- Review (`docs/reviews/134-the-menu-cards-speak-portuguese.md`): changes
  requested, no blocker; all applied. The search card says "célula" and the
  Pac-Man card "movimento", as their demos do; ten more rows reworded; L10
  also refuses a card field worded with `said()` that `SHOWN_DATA` does not
  name (planted: `watch` taken out of the list), and L3 names the shown data
  as a possible cause.
- A card's English changed later -- T130 may change the talk card -- now
  fails L10 until its row follows. That is the point.
