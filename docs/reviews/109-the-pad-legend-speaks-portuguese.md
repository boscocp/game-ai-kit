# Review: wave/109-the-pad-legend-speaks-portuguese

T103: with a controller connected, every real-time demo adds the pad's line
to its legend (`PadAsKeys.add_to`), and it was English in pt-BR because
`game_shared` had no table. It now has one. A pad is planted for the
checks, which cannot connect one headless, and the line breaks at the
legend's width.

A fresh context reviewed PR #46 at head b727b71.

**Verdict: approve after two should-fixes, no blockers.** Two should-fix
findings and five nits. All were applied on the branch, except the legend
heights, which the coordinator left to the owner.

## What was reviewed

The diff against main:

- `godot/locale/game_shared.csv`, its import and `.translation`, the
  manifest and `project.godot`;
- `PadAsKeys`: the translated words, `planted`, `legend_lines` and the
  width break; `Legend.words_width` and `Legend.width_of`;
- the plant in `test-locale-screen` and `test-demo-overlays`, and the five
  new claims in `make test-pad`;
- the T103 section of `docs/godot/localisation.md`, `a-controller.md` and
  the STATUS row.

The reviewer imported a clean checkout, ran the gates, and ran its own
mutations.

## What the reviewer found sound

- **The plant is safe and in the house style.** `PadAsKeys.planted` is a
  static seam like `Art.generated`, false by default, set only in `-s`
  scripts; nothing in a game sets it.
- **A real pad and the plant share one path.** `add_to` writes
  `legend_lines(legend)` either way; only the connection test differs.
- **The width is measured as it is drawn.** `Legend.width_of` uses the
  same fallback font at `TEXT_SIZE` as `_draw`, and a legend's width is
  known at `_ready` (the scenes set it by offsets).
- **The width break is correct** in both languages on all seven demos.
- **No collision with T107**: `NOT_YET_FITTED` untouched.
- **No false positives** from key or button names in the screen check.
- **A clean checkout imports reproducibly**: the committed `.translation`
  is the one `make import` writes.
- **Module selection is correct**: the table is owned by `game_shared`;
  `project.godot` and the manifest select all of `make check`.

## The reviewer's mutations

Nine mutations. Every one was caught by some gate except one:

| mutation | caught by |
|---|---|
| `add_to` ignoring `planted` | **nothing** -- `test-demo-overlays` stayed green in both languages (finding 2) |
| `Legend.width_of` 4 px smaller | `test-demo-overlays` only |
| `words_width` ignoring the swatch | `test-demo-overlays` only |
| the six others (the words, the plant, the rebuild) | `test-locale-screen` or `test-pad` |

## Findings

1. **The pt-BR line was not free of English** (should-fix).
   `OS.get_keycode_string` wrote "Space", "Up", "Down", "Left", "Right" and
   "Period" into it: "controle: analógico Left/Right/Up/Down", "A Space".
   - Every other table translates them: "espaço" (checkers, skirmish, the
     maze, the search demo, fighting, noughts and crosses), "setas"
     (`maze.csv`, `demo_racing.csv`), "." (`demo_steering.csv`).
   - The glossary says a key's name is what the key shows, and a space bar
     shows no word, an arrow key an arrow.
   - The test missed it: `ENGLISH_WORDS` was lowercase and its regex
     case-sensitive.
   - The legend's font has no arrows
     (`ThemeDB.fallback_font.has_char(0x2190..0x2193)` is false), so
     words, as the coordinator decided; the owner can revisit.
2. **The plant in `demo_overlays.gd` had no check of its own**
   (should-fix, invariant 4). Ignore `planted`, and the width check
   measures no pad and stays green.
3. **`_right_edge_of` added a hard-coded 8.0** (nit): `Legend.WORDS_GAP`.
4. **`"%s %s" % ["LT", key]` is roundabout** (nit): say why, or write it
   plainly.
5. **The glossary named none of it** (nit): D-pad, the pad's printed
   names, the stick.
6. **"analógico A/D/W/S" beside "analógico direito olha"** (nit), in the
   bot match and infiltration: which stick walks?
7. **The maze belongs on the legend-height list** (nit).

## What was done about them

1. **Keys that print no word are translated.**
   - The claim was made case-insensitive, with "space", "arrows" and
     "period" added, and seen red against the old line first
     (`legend_portuguese did not hold`).
   - `PadAsKeys.KEY_WORDS` (`# shown through tr()`): Space "espaço",
     Left/Right/Up/Down "esquerda/direita/cima/baixo", Period "." in both
     languages. Four arrows together are "arrows", "setas", as the kit
     says it; and the D-pad's four directions bound together are one
     binding, "D-pad setas" or "D-pad A/D/W/S", rather than "D-pad cima
     cima" four times. Key names a key prints (Shift, Tab, W) stay.
   - `make test-pad` reads a second table (all four D-pad directions to
     the arrows, B to Period); a plant holds the first pt-BR line,
     "Space", "Up" and "Period" in it, to its six English words.
   - `test-locale-screen` reads each binding's key name alone too: with
     the key names untranslated, it fails the stealth hall ("A Space"),
     both racers ("LT Down", "RT Up") and the maze.
2. **`test-demo-overlays` fails an example with a pad none of whose lines
   reached its legend**, and a planted example with a pad and no line is
   refused. With `add_to` ignoring `planted`, it fails all seven demos.
3. Applied.
4. Kept, with a comment: "LT %s" is a literal with a word and a space,
   which `check_translations_game.py` reads as prose.
5. Three rows in `docs/techniques/glossary.pt-BR.md`.
6. "left stick {keys}", "analógico esquerdo", where the right stick looks
   too; elsewhere a stick is just "stick". Everywhere would not fit: the
   2D racer's first binding would run past its legend.
7. Added, with every height measured again after finding 1 (the D-pad
   binding shortened some): the bot match's legend ends at y=740 of 720;
   the 2D racer's at 254 (en) and 274 (pt-BR), its status at 200; the 3D
   racer's at 212, its status at 164; the maze's at 220, touching its
   `Decision` at 220. Not fixed here, and no task file written.

## The reviewer's runs

- `make test-pad`: 24 claims, 0 failures.
- `make test-locale-screen`: 16 examples, 0 failures.
- `make test-demo-overlays`: 15 examples in English and in pt-BR, 0
  failures; the SCRIPT ERRORs were the planted `free` ones.
- `make test-godot-some` over `test/game_shared` and `test/locale`: 24
  cases, 0 failures.
- The lints: green.

## Open for the owner

Decided by the owner, 2026-10-29, as recommended: the pt-BR pad words
stay ("controle", "analógico", "D-pad cima" and the other directions,
the right stick's and RT's words), arrows as words, and "D-pad setas";
the legend's height is a task of its own, T108. The width break and the
plant in `demo_overlays.gd` stay open.

- **The pt-BR words.** The reviewer finds them fine. "D-pad para cima"
  would read more naturally than "D-pad cima", at a width cost; "mira"
  is an option for the shooters' right stick.
- **The width break, and the plant in `demo_overlays.gd`**, both beyond
  the task's file list. The reviewer finds them justified: the English
  line already ran off the window with a real pad.
- **A task for the legend's height.** The reviewer says yes, with a gate
  that measures a legend's last line against the window and the panels
  next to it.
