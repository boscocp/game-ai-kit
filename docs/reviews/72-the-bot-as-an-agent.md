# Review: wave/72-the-bot-as-an-agent

A fresh context reviewed the wave at its tip after it was rebased onto
main (waves 71 and 73 merged): T67 -- percepts through `ai_perception`
into one record, the priority list replaced by `ActionChoice` (a utility
choice in `ai_teamwork`) for the action, the posture and the pace,
`ErrandChoice` for the errands, Python twins and vectors, random mirrored
arenas for portability, and the effects test. It was not allowed to edit
the worktree. It ran the readability and modules gates, the teamwork
vectors on both sides, the Python tests, the gdUnit suites of `botmatch`,
`ai_teamwork` and `ai_perception`, and three probe scripts of its own; it
did not run the effects test.

**Verdict: fix before merge.** The top question was the yards' mirror:
with posture and pace weighed, a 20-match run put blue ahead by 3.1
standard errors, and the author had raised the run to 40 matches, which
passed. The review found the fault behind it.

## What was reviewed

- `CLAUDE.md`, the T67 and T66 task files, `docs/godot/botmatch.md`, the
  review of wave 71, and `git diff main...HEAD`.
- First, the yards' mirror: every nearest-thing lookup, fixed sign and
  id-order loop in posture, pace, percepts and the two choices, probed
  with mirrored setups where a candidate turned up.
- Then correctness, the planted cases, the twins, the copy of the bot's
  actions in `derive.py`, what is still fixed, readability and the docs.

## Findings

Each one is followed by what was done about it.

1. **The decision loop showed red blue's new posture and blue red's old
   one** (high). Each bot perceived and then decided in id order, and a
   decision set its posture at once; perceiving read the others' posture
   through the worth of a shot. Probed on the yards: in 312 of 12,325
   mirrored two-a-side setups the two sides decided differently; with
   every bot perceiving first and deciding after, in none. *Fixed*: two
   loops. A test plays the probe's mirrored setup and plants the one-loop
   order, which fails it.
2. **The yards' run was raised to 40 matches after it failed, for a wrong
   reason** (medium): "a fault does not reverse with the seeds" -- a bias
   of about 30 s does reverse across batches of 20 that swing this much,
   and 3.1 errors is unlikely as noise. *Fixed*: back to 20 matches, the
   owner's decision for a found fault; at 20 the yards now measure +8.9 +-
   32.0 s, 11-9.
3. **An exactly-behind turn was no mirror** (low): it wrapped to the same
   sign on both sides, turning blue north and red south. *Fixed*: both
   sweep towards +z; a test holds red's facing to blue's mirror.
4. **`derive.py`'s copy of the bot's actions was tied to nothing**
   (medium). *Fixed*: a test compares each such vector with the actions
   the bot reads; one weight changed in the data fails it.
5. **A cover test could pass on an empty case** (low). *Fixed*: it asserts
   it found the open floor first.
6. **The docs' numbers predated the rebase and the T66 review's fixes**
   (low), with the commander's bar at 1.2 where main has 1.5. *Fixed*:
   re-measured and rewritten, with the match count and run time.
7. **The twins did not validate their data** (low): GDScript ignored an
   unknown key and read any curve but "step" as a line; Python raised on
   unknown keys only. *Fixed*: both check keys, names, percepts and curves
   first, each with a planted misspelling; the actions shared by every
   bot are documented as read once and never written.
8. **More is still fixed than the docs said** (note): the target choice,
   `danger_of` and its range, the cover values, the reload lost when
   another action wins, an errand overriding the spot. *Fixed* in the
   docs: each named, with where it would move -- danger and cover with
   T68, the target and the errand after it.

## What was done about them

All of it is in the four commits after the T68 task's, rebased onto main
with wave 74 in it. `make test-botmatch-effects` ran on the fixed code:
149 matches in 1279 s, 0 failures. Both mirrors fair at 20 matches each
(lanes +31.5 +- 22.8 s, 13-7; yards +8.9 +- 32.0 s, 11-9); claims, the
commander (2.69 points against 1.33), retreat, honesty, sprint, aim (4.53
against 3.80 a shot), ammunition and portability on six random arenas all
held, and every planted case was caught. The gdUnit suites (1,184 cases),
the 48 teamwork vectors on both sides, the Python tests, the demo overlays
and the lints pass. `make check-affected BASE=origin/main` runs on the
pull request.

## What the review found sound

`ActionChoice` and `ErrandChoice` in both languages on every path, with
their clamps, steps, ties and the absent percept pinned by vectors; the
other mirror candidates it ruled out -- cover lookup ties, heard-shot
order, target ties, the danger maximum, the vision cone, the fetcher, the
random arenas; no action that can never win or always wins; no reload,
posture or pace path that sticks; and no planted case in the effects test
that asks a claim of itself.
