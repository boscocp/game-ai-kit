# T120 — `Xorshift` becomes `GakXorshift`, before anything is published

Size: S · Prereqs: T109 · Files: `godot/addons/ai_core/`, `godot/test/ai_core/`, `godot/addons/ai_adversarial/`, `godot/test/ai_adversarial/`, `godot/addons/ai_bandit/`, `godot/addons/ai_perception/`, `godot/game/maze/`, `godot/test/maze/`, `modules/ai_core.json`, `spec/vectors/core/README.md`, `spec/squad/positions.json`, `docs/techniques/`, `docs/godot/maze.md`, `docs/adr/0024-the-library-prefixes-its-ports.md`, `README.md`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's 2026-11-04 item B6: `GakXorshift`, before
anything is published.

T109 put one seeded generator in the kernel, `ai_core`, and left it
unprefixed. ADR 0024 prefixes the kernel, and `Xorshift` is a name a
user's project may well have: `class_name` is global and GDScript has no
namespaces. Renamed now, it costs one wave. Renamed after a release, it
breaks every game that names it. That is why T112, the review before the
repository opens, waits on this task.

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **"Both languages" is read as the pages in English and in pt-BR.** The
  GDScript `class_name` becomes `GakXorshift`; every technique page that
  names it changes, in both languages.
- **The Python twin keeps `gameaikit.core.Xorshift`.** ADR 0024: "The
  Python names stay. ... Python's modules are the namespace GDScript
  lacks." The Python ports are unprefixed today (`AdversarialGame`). If
  the wave reads the owner's word otherwise, it asks.
- **The file name stays `xorshift.gd`.** ADR 0024: "File names do not
  change."
- **No draw moves.** Every vector family that reads the generator passes
  unchanged: `core`, `adversarial`, `bandit`, `perception`, `maze`, and
  the squad's search vectors.

## Steps

1. Rename the `class_name` and every use in GDScript. Run
   `./scripts/godot --headless --path godot --import` once, and commit
   any `.uid` it writes (CLAUDE.md's trap on a new `class_name`).
2. The pages, both languages, `modules/ai_core.json`'s `summary`, the
   README and the vector READMEs that name the GDScript class.
3. ADR 0024's table gains the row, as a tenth prefixed name, dated.

## Acceptance

```bash
! git grep -n -w "class_name Xorshift" -- godot
git grep -q -w "class_name GakXorshift" -- godot/addons/ai_core/xorshift.gd
make test-core-vectors
make test-adversarial-vectors
make test-bandit-vectors
make test-perception-vectors
make test-maze-vectors
make test-squad-search-vectors
make test-godot-some SUITES="test/ai_core test/ai_adversarial test/ai_bandit test/ai_perception test/maze"
make test-python
make library-check
python3 scripts/check_translations_docs.py
python3 scripts/check_readability.py
make lint-modules
make lint-tasks lint-status
```

## Manual check

Open the maze (R, a few seeds) and the MCTS example: do they play as
before?

## Notes

- Shares `godot/addons/ai_adversarial/`, `godot/test/ai_adversarial/`
  and `docs/techniques/` with T88, and `spec/squad/` (one line of
  `positions.json`) and `docs/techniques/` with T96. Run it before or
  after them, not beside.
- ADR 0024's amendment of 2026-11-05 records the promise of 0.1.0 as the
  nine `Gak` names. Whether that promise grows to ten with this rename is
  not in the owner's answer. The wave asks, and the ADR says what was
  answered.
