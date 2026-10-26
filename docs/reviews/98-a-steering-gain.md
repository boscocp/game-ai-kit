# Review: wave/98-a-steering-gain

T105: seek and pursue take arrive's `time_to_target` (Millington's form),
all three through `Steering.towards_velocity`. The default is one second,
which is the old implicit gain. The racing example asks for a tenth of a
second instead of multiplying seek's force by `RESPONSE = 10`.

A fresh context reviewed PR #36.

**Verdict: no blockers.** Two should-fix findings and four nits. Every one
was applied on the branch.

## What the reviewer found sound

- The default of one second changes nothing. The reviewer's own numbers
  were identical to main's on every steering gate. All eight vectors come
  out byte-identical when `derive.py` writes them again.
- Every mutation was killed: seek ignoring its time, in either language,
  turns the new vectors, the new unit tests and the racing example red.
- The sources are right: Reynolds' per-step `acceleration = steering_force
  / mass`, and `aicore`'s `velocity += steer.linear * duration` and seek at
  full acceleration.

## Findings, and what was done

1. **should-fix: "the same at any frame rate" was false for short times.**
   Explicit Euler multiplies the gap by (1 - dt / time) each step. Below
   half a frame that factor is under -1, so the velocity overshoots and
   chatters, bounded only by `max_force`. The reviewer's probe was a car
   going east at 10 that seeks far north with force to spare, measured by
   the sideways speed after one second. Times of 1 and 0.1 gave the same
   answer at 30, 60, 120 and 240 Hz. A time of 0.01 at 30 Hz alternated
   ±7.00, 0.005 at 60 Hz ±5.97, and a time of 0 (floored to 0.001)
   chattered at every rate.
   *Done:*
   - `docs/concepts/steering.md` qualifies the claim to "while it is
     several frames long", explains the decay factor, and tabulates the
     probe (measured again here, the same numbers).
   - A time of zero or less is still floored, not refused. Arrive has
     floored its time since T22, and a test holds that contract in each
     language (`test_arrive_waits_a_tenth_of_a_second_unless_told_otherwise...`), so refusing would break it.
   - The doc comments say plainly what the floor does and does not do:
     `Steering.SHORTEST_TIME`, `towards_velocity`, seek, pursue and arrive,
     and their Python twins.
   - New tests in both languages:
     - the same answer at 60 and 120 Hz for times of 1 and 0.1;
     - chatter for 0.005 at 60 Hz but not at 240 Hz;
     - the floor for seek and pursue.
2. **should-fix: "within `time_to_target` seconds" misdescribed the knob.**
   It is a time constant: unclamped, about two-thirds of the gap closes in
   that time. Millington's "reach it in this time" is loose the same way.
   *Done:* reworded in `steering.gd`, `seek_behaviour.gd`,
   `pursue_behaviour.gd`, `arrive_behaviour.gd`, the Python docstrings,
   the knob table of `ai_steering.md` and `.pt-BR.md`, and
   `racing_driver.md` and `.pt-BR.md`. `translation_of` was recomputed for
   both pages.
3. **nit: Python's `Pursue` did not floor its time, while Godot's did.**
   *Done:* `Pursue.__post_init__` floors it at `SHORTEST_TIME`, as `Seek`
   and `Arrive` do. A test holds this in both languages.
4. **nit: `arrive_behaviour.gd:12` was 120 characters long.**
   *Done:* rewrapped.
5. **nit: `aicore`'s kinematic arrive is not "the same idea".** It divides
   a position offset by `timeToTarget` to get a velocity.
   *Done:* the concept page now says the name comes from velocity matching
   and the dynamic arrive, and that `aicore`'s kinematic arrive uses the
   same name for a different quotient.
6. **nit (pre-existing): `RacingDriver.pursuit_turn` adds seek's force to
   a velocity without `dt`.** That is right only because of the
   one-second default.
   *Done:* a comment there says the sum relies on that default. The
   behaviour is unchanged.

## Run after the fixes

- `make test-godot-some SUITES="test/ai_steering test/demo_racing test/racing3d"`
- `make test-steering-vectors`
- `make test-steering-properties`
- `make test-racing-ladder` and `make test-racing-does-not-cheat`
- `make test-racing3d-ladder` and `make test-racing3d-does-not-cheat`
- `make test-python-some PYTESTS="test_steering test_steering_vectors"`
- `check_translations_docs.py` and its `--self-test`
- `check_readability.py`
- `catalogue.py --check`
- `make lint-modules lint-tasks lint-status`

The numbers equal main's:

- 8 vectors, 44 samples, 0 failures;
- 100 starts, arrive settled in 100;
- the 2D ladder at 32.52 / 31.30 / 29.89 s, and its does-not-cheat over 3931 frames;
- the 3D ladder at 50.61 / 48.43 / 47.20 s on the loop and 43.90 / 41.86 / 40.41 s on the kidney, and its does-not-cheat over 6198 frames;
- 70 suite cases, 0 failures, no `SCRIPT ERROR`;
- 24 Python steering tests OK.
