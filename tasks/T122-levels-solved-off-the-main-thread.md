# T122 — The infiltration's levels are solved off the main thread

Size: S · Prereqs: T95 · Files: `godot/game3d/infiltration/`, `godot/test/infiltration/`, `docs/godot/infiltration.md`, `docs/concepts/`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's 2026-11-04 item B10: solve on
`WorkerThreadPool`, as a small follow-up.

T95's solver places the infiltration level on the main thread. A level
stalls the window for 120-140 ms, and 2.2-2.5 s on the slowest seed
(144). Today that is cached by seed, so N and K do not solve again, and
written down as a known cost on `docs/godot/infiltration.md`. T95's
review (`docs/reviews/120-levels-by-constraints.md`, finding 2) offered
the background solve as the other answer: the solver touches no scene.

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **Read the documentation first.** `WorkerThreadPool` and thread safety
  for the pinned engine (`.godot-version`), before writing a line: what a
  task may touch, and how the main thread learns it finished. What
  survives the reading and a measurement goes in `docs/godot/`, with its
  URL and `verified_on`.
- **The solver is unchanged.** Same seed, same level, cell for cell. Only
  where it runs changes.
- **While it solves, the window says so**, and the old level stays until
  the new one is ready. The solver's counts beside the map (T95) appear
  when it ends.
- **Headless tests keep the synchronous call**, so a seeded test does not
  wait on a thread.

## Steps

1. Read and measure, as above.
2. Solve a new level on the pool; the scene polls or is told.
3. A test that a level solved on the pool equals the one solved inline,
   for three seeds including 144.
4. The page: the stall paragraph becomes what happens now.

## Acceptance

```bash
make test-godot-some SUITES="test/infiltration"
make test-infiltration
make test-infiltration-properties
make test-constraints-vectors
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play `make demo-infiltration`, L to a generated level, seed 144 among
them: does the window keep drawing while it solves, and does the level
that appears play as before?

## Notes

- **One of the follow-ups the owner deferred.** On 2026-11-05 the owner
  said "deixa os followup pra depois" when choosing waves 125-127. This
  is one of them, so it waits for the owner's word on when, not only for
  its prereq.
- Shares no folder with T88. T96 writes `godot/addons/ai_constraints/`;
  this task does not, so the two can run side by side.
