# Review: wave/134, T131 -- the menu's cards speak Portuguese

T131: opened in Português, the menu translated only its chrome, and every
card's own words stayed `catalogue.json`'s English. The PR adds 187 rows to
`godot/locale/menu.csv` keyed by the catalogue's English,
`ExampleCatalogue.said` for each card field, the list titles and heading
worded in `menu.gd`, rule L10 in `check_translations_game.py`, and a
card-by-card reading in `test-locale-screen`.

A fresh context reviewed PR #81 at head fd46432. It read the code, every
new pt-BR row, the glossary and the other 18 tables, and ran narrow checks
in a throwaway worktree. It made no commit, push or PR comment.

**Verdict: changes requested, no blocker.** The mechanism is right and
both gates reject their planted faults. The pt-BR is natural and largely
consistent. The should-fixes are two places where the card says a word
differently from the demo it describes, and a layout limit nothing holds.

## What was reviewed

- The whole diff: `menu.csv` (every row read), `example_catalogue.gd`,
  `menu.gd`, `locale_screen.gd`, `check_translations_game.py`,
  `localisation.md`, the glossary row, the task file and the STATUS row.
- Every other table under `godot/locale/`, for collisions (L6/L8) and for
  the words each demo already uses (`maze.csv`, `demo_search.csv`,
  `rts.csv`, `infiltration.csv`, `botmatch.csv`, `fighting.csv`,
  `checkers.csv`, `skirmish.csv`).
- `docs/techniques/glossary.pt-BR.md`, against each term the cards keep in
  English.

## What was run (green at fd46432 unless stated)

- `python3 scripts/check_translations_game.py`: exit 0.
- `python3 scripts/check_translations_game.py --self-test`: ok.
- `python3 scripts/check_readability.py`: exit 0.
- A collision scan of `menu.csv` against every other table, keys compared
  without `?context`: only `seek`, `arrive`, `pursue` collide, all three
  with `demo_steering.csv`, and each says the same in both. No short key
  (`A*`, `Dijkstra`, `Checkers`, `Stealth`, `the fourth`, `another of the
  four`) is a key anywhere else. 202 rows in all (15 before + 187).
- A scratch script measured each list title at the list's font size
  (fallback font, 22 px) against `LIST_WIDTH` = 360 (below).

## Planted faults (invariant 4)

Each was one change, run against the narrow gate only, then restored.

| plant | gate | result |
|---|---|---|
| `Noughts and crosses,Jogo da velha` removed from `menu.csv` | L10 | `L10 ... examples[].title shows 'Noughts and crosses', which is not in godot/locale/menu.csv`, exit 1 |
| `Dijkstra,` (empty pt_BR) | L2 | `'Dijkstra' has no pt_BR`, exit 1 |
| every `"watch":` renamed `"what_to_watch":` | L10 | `the field examples[].watch finds no words`, plus 16 L3 orphans, exit 1 |
| one entry's `watch` renamed | L10/L3 | caught as an L3 orphan of that row only, exit 1; `check_demos.py` exit 1 too |
| talk card's title and controls reworded (decision 5) | L10 | both new sentences named as missing, both old rows as L3 orphans, exit 1 |
| `text_of` draws `watch` with `plain()`, not `said()` | `test-locale-screen` | `FAIL menu, card 0..15: ... shows the English <watch>`, every card by name, exit 1; no `SCRIPT ERROR` |

The one-entry rename is held, but by L3's wording ("is in no script of
menu"), which points the reader at a script, not at the catalogue. Loud,
so a nit.

## Decision 5 (T130 in parallel)

Confirmed by the plant above: a changed talk card fails L10 by name, and
the stale row fails L3. It cannot pass silently. Whichever of T130 and
T131 merges second must add the row, and `make check-affected` runs
`lint-translations-game` for any change to `catalogue.json`.

## Findings

### Blocker

None.

### Should-fix

1. **Pac-Man's move is "lance" on the card, "movimento" in the demo.**
   `menu.csv:145` (watch) and `menu.csv:147` (the value-iteration part).
   `maze.csv` says "movimento" four times ("seta numa casa: o movimento da
   política dali", "quanto vale cada movimento"). "Lance" is a board-game
   word; in a Pac-Man maze it reads oddly. Corrections below.
2. **"Four searches" says "casa", the demo says "célula".**
   `menu.csv:30-33`. `demo_search.csv` says "célula" every time, and the
   BFS part is nearly its row word for word ("cega ao custo de cada
   célula"). A person reads the card and then the demo, so they should use
   the same word. The other cards' "casa" is right: their demos say "casa".
3. **Long titles in the list: nothing holds them.** Measured with the
   fallback font at 22 px against a 360 px column: 10 of 16 pt-BR titles
   are wider (9 of 16 in English, so this is older than T131). The widest
   is "Corrida em 3D: pneus que derrapam, e pilotos que medem o próprio
   carro (3D)" at about 835 px. By Godot's defaults, an `ItemList` item is
   one line, trimmed with an ellipsis. That comes from the class
   reference; nobody looked at it on screen. `locale_screen.gd` measures a
   `Label`'s width, not an `ItemList` item's. No headless command can see
   the trim, so it belongs to `## Manual check`, which already asks. The
   owner decides between shorter titles and `max_text_lines = 2`. The
   heading over the card shows the whole title either way.

### Nit

4. **A new shown field is invisible to both gates.** `SHOWN_DATA`
   (`check_translations_game.py:140`) is a hand list. If a later task
   draws a new catalogue field through `said()` and adds no row, L10 does
   not know the field. The screen gate flags only text that is a key's
   English. So both pass. This was reasoned, not planted. Say it under
   "What it cannot see" in the docstring and in `localisation.md`.
5. **"16 rows" before.** The task's Goal and `localisation.md` say
   `menu.csv` held 16 rows; it held 15 (16 lines with the header).
6. **The one-entry rename's message** (see the plant table): L3 points at
   "no script of menu". A hint that a catalogue row can be the cause would
   save the next reader a search.
7. Translation nits, listed below with the corrections.

Readability: the new functions (`said`, `words_at`, `shown_from_data`,
`unowned_data`, `_every_card`, `_card_english`, `_planted_card`,
`_data_cases`) are all well under 40 lines and 3 levels of nesting. Each
doc comment says what the function does and why. `check_readability.py`
is green.

## Translation

The pt-BR is natural Brazilian Portuguese, not word for word: "dar nota",
"esterça", "a escaramuça", "jogo da velha", "a transição que fez" for the
FSM's arrow, "suprimento" for the RTS's room (as `rts.csv`), "reservas"
for claims (as `botmatch.csv`), "agarrar" for a throw (as `fighting.csv`'s
"agarrão"), "quadro" in the racer and "frame" in the fighter (each as its
demo). The glossary terms stay English and agree with it: *awareness*,
*utility*, *flow fields*, *behaviour tree*, *behaviour cloning*, *bandit*,
*ghost*, *heat line*, *lookahead*, *playout*, *self-play*, *pure pursuit*,
*seek/arrive/pursue*. "Busca em largura/profundidade" is allowed by the
glossary and is what `demo_search.csv` says. No row is wrong in meaning.

**Decision 3, "Stealth" → "Furtividade".** The glossary keeps *stealth*
for the genre in prose. As the title of one example, "Furtividade" reads
naturally and tells the card apart from "Infiltração", the 3D one.
Brazilian players also say "stealth" ("jogo de stealth"), so either works.
Recommend keep; the owner's taste decides.

**Decision 4, ply → "meio-lance".** Matches `checkers.csv`'s "1 meio-lance
à frente". Keep.

Corrections, `key → better pt-BR`:

- `The crossed square is the ghost's target ... the boxed number beside him is the move it takes.`
  → `... e o número na caixinha ao lado dele é o movimento que ele faz.` (should-fix 1)
- `with C, Pac-Man's move: the policy value iteration computed ...`
  → `com C, o movimento do Pac-Man: a política que a iteração de valor calculou em Python para o Blinky perseguindo para sempre, consultada numa tabela, com o valor de cada casa e o quanto vale cada movimento desenhados` (should-fix 1)
- `Which route to take from the start to the goal, and which cells are worth looking at on the way.`
  → `Que rota seguir do início ao objetivo, e quais células vale a pena examinar no caminho.` ("fazer uma rota" is awkward; "célula" per should-fix 2)
- `1-4 choose the search; space reveals one more cell, ...`
  → `1-4 escolhem a busca; espaço revela mais uma célula, enter o resto; arraste para pintar paredes e lama; B passa pelos tabuleiros`
- `The frontier spreading cell by cell, ...`
  → `A fronteira se espalhando célula a célula, na ordem em que a busca as examinou.`
- `spreads in rings: the fewest steps, blind to what a cell costs`
  → `espalha-se em anéis: o menor número de passos, cega ao custo de cada célula`
- `spreads in rings weighted by cost: the cheapest route`
  → `espalha-se em anéis ponderados pelo custo: a rota mais barata` ("pesados" reads as "heavy")
- `the cheapest route too, but leans towards the goal and stops early`
  → `também a rota mais barata, mas puxa para o objetivo e termina antes` ("pende ... e para antes": "para" reads first as the preposition)
- `Suck Up!'s doorstep: talk your way past the guard`
  → `Na porta do Suck Up!: convença o guarda a deixar você passar` (a game's name takes "o"; "de Suck Up!" reads as a person's or a place's)
- `Where each bot stands, ... -- on both teams, each switch yours to turn off.`
  → `... -- nos dois times, e cada chave você pode desligar.`
- `The brain's panel: ... with the step being run lit.`
  → `O painel do cérebro: o estado, o caminho na árvore ou o plano, com o passo em execução destacado.`
- `Three dots over Bram mean the model is answering ...`
  → `Três pontinhos sobre o Bram indicam que o modelo está respondendo ...` (nit)

## Items for the owner

1. Decision 3: "Furtividade" or "Stealth" for the 2D card's title.
   Recommend "Furtividade".
2. Long list titles (should-fix 3): shorter titles, or two lines per item.
   Look at it on screen in the manual check.
3. T130 and T131 touch the talk card's English: the second to merge adds
   its row (L10 says so).

## Applied (on the branch, after fd46432)

1. Should-fix 1, Pac-Man's "lance": applied. The watch row and the
   value-iteration part say "movimento", as `maze.csv` does.
2. Should-fix 2, "casa" on the search card: applied. Its five rows say
   "célula", as `demo_search.csv` does.
3. Should-fix 3, long list titles: not fixed here, as asked. The task's
   `## Manual check` now gives the measurement, and the PR body lists it
   for the owner (shorter titles, or `max_text_lines = 2`).
4. Nit 4, a shown field invisible to both gates: applied as a check, not
   only a sentence. L10 now also fails a card field a module script words
   with `said(card.get("x"))` when `SHOWN_DATA` does not name
   `examples[].x`. Planted: `examples[].watch` taken out of `SHOWN_DATA`
   gave `L10 godot/menu/example_catalogue.gd:67: the card field 'watch'
   is worded with said() and is not in SHOWN_DATA`. The self-test plants a
   drawn `hint` field. A field drawn some other way than
   `said(card.get(...))` is still not seen.
5. Nit 5, "16 rows": applied; the task says 15.
6. Nit 6, the one-entry rename: applied. When the module has shown data,
   L3's message adds "nor in its shown data: a catalogue entry renamed or
   reworded?".
7. Nit 7, the translation corrections: all twelve applied as written, and
   the `.translation` regenerated.

Decision 3: kept "Furtividade", as recommended; the owner decides.
