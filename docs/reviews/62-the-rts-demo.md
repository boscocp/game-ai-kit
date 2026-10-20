# Review: wave/62-the-rts-demo

One fresh context reviewed it at cfc1e68, in a worktree of its own. It
committed nothing; its probes lived outside the tree, every mutated file
was restored byte for byte from a copy and checked, `__pycache__` was
purged after the Python run, and gdUnit4 and the forbidden-term list were
copied in and removed after.

**Verdict: do not merge yet** -- two high findings that break the game for
a person and for the commander, a fog leak in the core, and tests that
could not fail on what their names claim. Every scoped command was green.

## What was reviewed

- `CLAUDE.md`, T20 with its split, ADRs 0010, 0019 and 0020,
  `docs/concepts/rts-ai.md`, and the whole diff `main...cfc1e68`: the core
  (`ai_rts_core`), the game (`godot/game/rts/`), the tests, the art
  downloader.
- Run, all green: gdUnit `rts_core_test.gd` (34) and `rts_game_test.gd`
  (13), `make test-rts-simulation`, `make test-rts-budget`, `make
  test-rts-match`, `demo_overlays.gd` and `menu_walk.gd` (10 examples
  each; the only `SCRIPT ERROR`s the overlays' own planted crash), `make
  test-python` (309), `fetch_rts_art.py --self-test`, and eleven static
  gates. `make rts-measure` once (544 s).
- 27 mutations across the core and the game. Fifteen survived every test
  (listed under finding 8 and in "What was done").
- Determinism: no new hazard -- the screen reads only pure functions and
  the scores and sites a side kept; a second run and the replay agreed.
- Scope: nothing of T55 or T56 had slipped in.

## Findings

1. *high* -- a half-built building could never be finished: BUILD always
   places a new site, and REPAIR refused a site ("build it, do not repair
   it"). One raided builder left the plan's top wish waiting for ever.
2. *high* -- retreat did nothing: in FIGHT every member is on attack, and
   the walk home skipped members on attack; the screen said "falling back"
   while the squad fought on.
3. *medium* -- an attack order followed its target into the fog, and its
   end told the side an unseen unit had died; strike-back handed a side the
   id of an unseen striker.
4. *medium, older than the wave* -- "there is no unit N" against "unit N is
   not yours" told a side which unseen ids still lived.
5. *medium* -- the acquisition-through-what-the-side-sees check had no test.
6. *medium* -- BuildSchedule waited for `needs` but not for the producer,
   and priced one runner where the step means a squad of four.
7. *medium* -- the concept page and ADR 0010 quoted records the code no
   longer produced, and a 15 - 5 seat bias went unmentioned; stale text in
   several headers.
8. *low-medium* -- tests that could not fail: separation into a wall, the
   squad's region hysteresis, repair in one tick, strike-back "from beyond
   sight" (it was not), the enemy snapshot's private fields, and the replay
   claim, which never compared digests.
9. *low* -- the board drew the computer's squads through the person's fog.
10. *low* -- the dice were added after a building divided the blow.
11. *low* -- the repair button's messages, and a mixed selection's repair
    refused whole.

## What was done about them

- **1** cb0e42f, 7c9923e: repair takes up a site left half-built; the
  computer sends a worker to one; `rts_core_test` finishes a site from 300
  ticks of 600.
- **2** 7c9923e: a squad falling back breaks off; `rts_game_test` gives it
  six runners against twelve shields and sees one move order for all six.
- **3** cb0e42f: an attack on a unit out of the side's sight ends; strike
  back only at a striker the side can see.
- **4** cb0e42f: one refusal, "unit N is not one of yours", for both; a
  test compares the two answers.
- **5** cb0e42f: a test with a runner seven cells off, left alone unseen
  and attacked once a tower sees it.
- **6** 7c9923e: the schedule waits for the producer and prices and times
  the batch; a test with ore for everything at once, so only the barracks
  can hold the runners back.
- **7** the records below re-measured on the final code; the stale headers
  fixed in cb0e42f and 7c9923e.
- **8** each test rewritten until its mutation fails it: nudge into walls,
  strike-back while walking, acquisition through fog, the mortar through a
  wall, a chase into the fog, repair in one tick, the region and the focus
  hysteresis, the producer wait, the retreat; `rts_match.gd` compares the
  replay's digest. Writing the separation test found a second bug -- two
  units on one point were pushed the wrong way, the made-up direction's
  length of 1 turning the push negative -- fixed in cb0e42f.
- **9** 7c9923e: while a person plays, the computer's squads and sites are
  drawn only where the person's side sees.
- **10** cb0e42f: `RtsKinds.blow` takes the dice first.
- **11** 7c9923e.

Not done, and said so: the 15 - 5 seat bias went 9 - 11 after these
fixes, re-measured but not held -- T57 makes the mirror match a gate; G08, G09, G13 and G14 (the
computer never mending, the queues always training runners, building in
the fog without walking first, never replanning on the cadence) are still
held only by `make rts-measure`'s records, not by a test that fails.
