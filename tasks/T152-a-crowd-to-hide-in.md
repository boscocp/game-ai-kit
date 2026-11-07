# T152 — A crowd to hide in

Size: M · Prereqs: T150, T115 · Files: `godot/game3d/infiltration/`, `godot/test/infiltration/`, `docs/techniques/`

## Goal

Stealth games have long used a crowd as cover: walk among people and the
guard loses you. The infiltration level has guards, light and sound, but
no one else is there.

The three flocking rules from T150 can drive a crowd of civilians in
small groups that wander, keep their spacing and part around obstacles.
The guards' perception (T70) then has to tell one figure in the crowd
from the rest.

## Decisions written down first

_The owner asked for this task on 2026-11-06. The decisions below are this session's proposal; the wave that takes the task confirms them, or brings them back to the owner._

- **The civilians come from `ai_steering`'s flock (T150)**, on the ground
  plane (x, z), in two or three groups with a wander target each. They
  are game code in `godot/game3d/infiltration/`, not a new addon.
- **The player blends in by walking, not running.** A player who walks
  inside a group and in step with its heading lowers the guard's
  certainty. Sprinting or crouching in a crowd raises it. This is a rule
  of this game, weighed in the existing guard percept. It is not trained
  (invariant 6).
- **Only one level gets a crowd**, a market square or a hall, picked by the
  wave. The other levels stay as they are, and their tests must not
  change.
- **Shown**, as invariant 13 requires: the group the player is counted in,
  and the guard's certainty with the reason ("in a crowd, walking").
- **After T115.** T115 changes the same guard's evidence: a Bayesian
  network reads it. The crowd becomes one more piece of evidence in that
  network, not a second, separate rule.

## Notes

_Wave 159, after the fresh-context review of PR #117._

- The first version stopped emitting the player's footstep while it
  blended in. The review found that a second rule, hidden and with no
  number in data, and it carried the result: without it, walking in step
  was alert at 10.7 s. Decided (the coordinator): one rule at one site, in
  data, shown. The footstep is always emitted; `InfiltrationCrowd.weigh`
  weighs the guard's percept -- the sight certainty by `certainty_scale`
  and the footstep's reach by `footstep_scale`, both in `crowd.json` --
  and the crowd line says what the eye and the ear were left with.
- Sight and hearing are weighed in the percept, as this task's decision
  says; the network gets the reading as its `figure` evidence.
- With the accumulator off, a weighed certainty still counts as seen: left
  as is and written under "Not done" in `docs/godot/infiltration.md`.

## Acceptance

```bash
make test-godot-some SUITES="test/infiltration"
make test-demo-overlays
make lint-demos
```

## Manual check

In `make demo-infiltration`, on the crowd level:

1. Walk into a group as a guard looks your way. Does its certainty drop,
   and does the overlay say why?
2. Sprint through the same group. Does the guard notice?
3. Do the civilians part around you and the guards without anyone
   passing through anyone else?
