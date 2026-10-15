# 0017 — A recording is the input log, and it is committed

Status: accepted · 2026-10-15 (T18; the data source decided by the owner)

## Context

Behaviour cloning learns from recorded play. T18 needs somewhere to keep it,
a form to keep it in, and a rule for who it is of. The owner decided the
data: the pipeline is built on scripted stand-ins, and the committed model is
fitted on the owner's own play, recorded before the merge.

## Decision

- **A recording is the input log alone** -- the two characters, one pair of
  inputs per frame, who played and against what. Not the rows. T16 made a
  log a replay, so the rows can always be cut again, and a recording
  outlives every change to the features cut from it.
- **Recordings live in `data/fights/` and are committed**, with the rows
  Godot cuts from them (`data/cloning/rows.json`) and the win rates it
  measures (`data/cloning/win_rates.json`). A model fitted from data nobody
  else has is a model nobody can reproduce; invariant 6 asks for the
  opposite, and N10 checks it.
- **Nothing is recorded unless asked.** The game keeps fights only when
  opened with `-- --record` (`make record-fights`), and says so on screen.
- **A recording says whose it is**: `person`, or `stand-in: <habit>`. The
  report prints which it is fitting, and a stand-in is never presented as a
  person.
- Outside the Godot project, so the editor never imports them.

## Consequences

- A recorded person's play is public once pushed. It is inputs and nothing
  else -- no name, no time of day beyond the file name -- and only the owner
  records.
- A recording replays under the current rules. A change to the frame data
  changes what the old recordings mean; `make test-clone-rows` then fails
  until the rows are cut again, which is the point.
