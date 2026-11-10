# T165 — The valley remembers: the example

Size: L · Prereqs: T164 · Files: `godot/game/valley/`, `godot/test/valley/`, `godot/test/menu/demo_overlays.gd`, `godot/menu/catalogue.json`, `godot/locale/`, `modules/valley.json`, `Makefile`, `docs/concepts/`, `docs/godot/`, `docs/techniques/catalogue*.md`

## Goal

A 2D turn-based game. The player is a traveller in a valley with two
villages, a river, a bridge, a mill, a barn, fields and a well. There is
no combat and no opponent. The villagers live their day, and what the
player did to the valley in earlier sessions shapes it: the bridge burnt
in session 2 is still burnt in session 5, the bread queue moves to the
other village, and a new well draws people. The player's standing, read
from the same deeds, sets what the ferryman asks and which doors open.

## Decisions written down first

_The owner asked for a karma system on 2026-11-10: the player's actions and choices have a visible impact on the world and its people, and they persist between sessions like a save. The owner chose this design from a research brief: the valley remembers what the player did to **places**. It has no combat and no opponent, and it is 2D and turn-based. The owner approves the ADR (T163), and that approval gates T164-T166. The other decisions below are this session's proposal, and the wave confirms them._

- **The villagers plan over the world's facts only.**
  - Each villager's day is a set of goals: buy bread, take the wheat to
    the mill, fetch water. `ai_behaviour`'s GOAP or HTN planner plans
    them, and the wave picks one and says why.
  - Routes come from `ai_core`'s grid and `ai_search`'s A\*.
  - `ai_utility`'s `ActionChoice` picks between goals.
  - A villager's decision receives only the world's facts and its own
    state of the day. The function signature holds that, and a test
    checks it.
  - Nothing about a villager is saved. No villager reads another's
    state.
- **A few people read the player's standing**: the ferryman, the
  merchant and the priestess. Each has a fixed, authored manner
  (`VillagerManner`, in data), which reads the standing and the world and
  sets a price, a door or a greeting. The manner never changes and is
  never saved. The talk is flavour and changes nothing that persists.
- **Shown, as invariant 13 requires:** the chain from a deed to a fact
  to a replanned goal to a new A\* frontier. For example: "deed 14:
  bridge down → mill unreachable from the east → Ana's plan: bread from
  the west village". There is a second chain, from deeds to a virtue to a
  manner: "fear 6 (deeds 3, 14, 20) → the ferryman's price ×2".
- **Small at first:** six villagers, about eight places, one day per
  turn sequence, with the exact numbers in data. The wave chooses.
- **Registered in full**, following "Adding an example" in
  `docs/godot/examples.md`: `make demo-valley`, the overlay, the
  legend, a card, English and pt-BR strings, and the catalogue
  regenerated. The erase button sits on the example's own menu.
- **Taught:** a concept page `docs/concepts/karma-and-world-memory.md`
  and its pt-BR twin. It cites Ultima IV, Fable, KOTOR, Fallout, Elite,
  GTA's wanted level, Hades, RimWorld and Dwarf Fortress for how games
  remember, and Talk of the Town for the research. Its "when not to use
  it" names a case.

## Acceptance

```bash
make lint-demos
make test-demo-overlays
make test-demos-exit
make test-godot-some SUITES="test/valley"
make lint-modules
make lint-renderer
```

A headless, seeded run of three sessions with a scripted player checks
three things:
- the world of session 3 is the one the record rebuilds;
- no villager's saved state exists, and no standing is saved;
- erasing returns to day one.

## Manual check

- Play two sessions. Burn the bridge in the first, and in the second see
  the villages live with it and the overlay say why.
