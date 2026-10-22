# Review: wave/74-the-stealth-research

A fresh context reviewed the wave at `f845ec2`, rebased onto main: a
documentation-only wave -- `docs/concepts/stealth-ai.md`, the research for
the owner's stealth example (Assassin's Creed, Splinter Cell, Metal Gear),
and T52 rewritten and split in two. It was not allowed to edit the
worktree. It opened 16 of the page's 20 sources, the seven Game AI Pro
chapters in full, and checked quotes against them; it measured
`scripts/next_wave.py` on the new task names; and it ran the doc, tier,
acceptance, link and status lints.

**Verdict: fix before merge.** The research was well sourced -- no quote
invented, every article about a talk labelled as one -- but the first
task could not have passed the addon dependency gate, one of its gated
properties contradicted itself, and `make wave` could not see either task.

## What was reviewed

- The page against its sources, at the strength each claim is made;
  Metal Gear kept to its game design, as the owner asked.
- The tasks against invariants 2, 3, 4, 5, 6 and 13 and the owner's rule
  that guards weigh rather than follow if/else.
- Names, prerequisites and file lists against the repository.

## Findings

Each one is followed by what was done about it.

1. **The first task broke invariant 2** (high): awareness in
   `ai_perception` "with its rate from `ai_fuzzy`", and a hearing flood and
   a belief diffusion over `SearchGraph`, which is `ai_search`'s.
   *Fixed*: `ai_perception` takes the rate, the path lengths and the
   neighbours as plain data; a new `infiltration` example module wires the
   fuzzy rule base and an `ai_search` flood to it, as T14 wired its
   suspicion. The second task's coordinator takes its sight lines and
   belief as data too.
2. **The belief contradicted itself** (medium): seeded where the player was
   seen, and zeroed in every cell seen. *Fixed*, as McIntosh and Isla
   describe it: all of it on the seen cell while the player is perceived;
   spread, zeroed where seen and renormalised only while not; reseeded over
   the unseen cells if a step would clear it, and said so on the overlay.
3. **`make wave` could not see the tasks** (medium): `next_wave.py` reads
   only whole numbers, and would have read T52.2's prerequisite as "T52".
   *Fixed*: renumbered T69 and T70.
4. **Five planned claims named no planted case** (medium). *Fixed*: guard
   data naming a cell of one level; a belief that never diffuses; a guard
   type with no light term; two flank requests both granted; a guard that
   reads a post from the first level's file.
5. **The page understated The Last of Us's cheating** (medium): its
   developer wrote the bots did not cheat "in most circumstances", and
   admitted a 5 m rule. *Fixed*: three admitted cheats, quoted so.
6. **The arbiter's claim would make a glimpse fire** (low-medium).
   *Fixed*: it applies in the alert phase, with a stated reaction window.
7. **"Awareness follows exposure" could fail on a correct vision shape**
   (low-medium). *Fixed*: compared within one zone, nearer along the
   guard's facing.
8. **The second task misstated what is on main** (low). *Fixed*: T66 is
   merged and its parts named; T67 is wave 72.
9. **Citations stronger than their sources** (low): lanterns, the radar,
   Metal Gear's boxes, an overlay idea credited to McIntosh, Hocking's
   role, a venue the paper does not name, a fourth Hitman talk. *Fixed*,
   each to what its source says.
10. **Readability** (low): a long line, a stale "T52's arbiter", and the
    resume text still asking the owner's four questions. *Fixed*.

## What was done about them

All of it is in `a7f18fe`, after `f845ec2`. The doc freshness, tier,
acceptance, link, status, addon dependency, modules and employer-terms
lints pass, and `next_wave.py` reads the new rows: it picks T56 today,
since T69 and T70 wait on T67. `make check-affected BASE=origin/main` runs
on the pull request.

## What the review found sound

Every quote it checked, verbatim, from the developers' chapters and the
articles; the labelling of every secondary source; Metal Gear kept to
design; every acceptance criterion a command; nothing trained at game time
and nothing above tier 1; the overlay's demands; and the guards as agents
whose phases are a reading of a number, not a table of transitions.
