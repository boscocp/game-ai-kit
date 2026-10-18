# Review: wave/54-how-racing-ai-is-made

One fresh context reviewed it, in the main worktree, at the wave's first
commit (one commit on `main`). It wrote nothing in the repository.

**Verdict: merge after fixes.** Every gate passes. Every quote looked for
is in its source, word for word, and the count of 30 references is right.
The problems were of three kinds:
- fairness and wording in the rubber-banding material;
- promises in T23 and T54 that their gates did not yet hold;
- one place where T23 asked T22 for something T22 does not provide.

None of the fixes is code.

## What was reviewed

- `CLAUDE.md`, and the top two resuming sections of `tasks/STATUS.md`.
- T22, T23, T53 and T54.
- The head of `docs/concepts/shooter-ai.md`, for the pattern.
- The whole diff.

What was run:
- `make check`: exit 0. Its six `SCRIPT ERROR` lines are
  `demo_overlays.gd`'s planted crash.
- `check_commit_msg.py` on the message: 0. The author and committer is the
  owner alone, and there is no trailer.
- `check_acceptance.py` (55 task files), `check_status.py`, `check_links`,
  `check_doc_freshness` and `check_tiers`: 0 each.

**27 of the 30 references opened:**
- PDFs extracted: Game AI Pro chapters 38-42, Jenner & Ocio Barriales,
  Coulter, Loiacono 2010 and 2013, Togelius 2005, 2006 and 2006 (player
  modelling), Fuchs, Xue.
- Web pages read as raw HTML, not through a summary: Reynolds, OpenStax,
  Nature, Turn 10, Jimenez, Thompson, Mark, Compton, the GRIP thread,
  Engadget, Nintendojo, Xbox Wire, Heilmeier.

Checked and true:
- Game AI Pro's 98-99%, the biorhythm, the braking rule, Kd and Ki at about
  half Kp, P-only never reaching the line, the heat line's single
  manoeuvre, and both of Melder's sentences.
- Driver: San Francisco's no-cheat sentence and its backward speed limits.
- Coulter's four quotes.
- The 2009 championship's seven rules, "no clear benefits", the emergent
  avoidance, the imitation lesson and the standings.
- Togelius's 16.04 against 15.97, the generalisation failure, and 0.05 /
  half a lap.
- Fuchs's 56-73 h, 946,453 km and 0.35 ms.
- Xue's formula and its bottlenecks.

## Findings

| # | finding |
|---|---|
| M1 | The survey turned Game AI Pro's interface advice into "shipped games keep the AI in the player's car", and left out the same chapter's advice to balance the field in the vehicle physics. |
| M2 | "Shipped games mostly hide it as skill" is stronger than the sources. Pure and Melder support it; the chapter's physics advice and Forza's adjusted cars are counterexamples. |
| M3 | T54 promised that no knob moves with the player's position, and its acceptance did not check it. |
| S4 | T23's knob check could see only stored values, so a band applied where a knob is used would pass. It had no planted case, and lookahead could legitimately vary with speed. |
| S5 | The new rule also refuses Game AI Pro's biorhythm, and the page did not say so. The narrow-range warning bears on T23's manual check. |
| S6 | T54 still said "braking margin". |
| S7 | T23 asked `ai_steering` for pure pursuit, which T22 does not have. |
| S8 | T54's grip measured in a lap had no source and no note on invariant 6. |
| S9 | The Turn 10 entry was labelled paraphrased but quoted, and "fixed" overstated an announcement. |
| S10 | Pure's balancing "stops for the last fifth" overstated it: it tapers to zero. |
| S11 | Melder's quote showed only its negative half, and "[Melder 2013]" was ambiguous between two chapters. |
| S12 | GRIP's switch is not available everywhere: a player in the thread says the campaign forces it on. |
| S13 | The same Togelius paper's indirect cloning was left out. |
| notes | Driver: San Francisco's rule was visual, not about fairness; 98-99% is the default, not "hard"; the order of 70/50/30 mph; Fuchs's three settings; Togelius's increments still weak on two tracks; the "final arbiter" quote is about balancing; Reynolds, OpenStax and Nature are quoted although the header promises paraphrase for fetched pages; the speed profile is per track and level; a long line in T23; a P-only car with a large gain weaves rather than settling off the line. |

## What was done about them

All taken, in the wave's second commit. None was declined.

- **M1, M2**: the short version and the "for" side now carry the chapter's
  physics-balancing advice and Forza's adjusted cars. "What is shipped"
  now names two kinds and says the sources cannot tell how common each is.
  Driver: San Francisco's rule is given its visual reason.
- **M3**: T54's cheat script checks the knob values the controller used,
  with T23's planted case.
- **S4**: T23's check now records the values used inside the controller.
  Its planted case is a grip margin scaled by the gap to the leader, and
  the lookahead is a constant per level.
- **S5**: the survey and T23 say the biorhythm is refused too, and what the
  kit gives up. T23 notes the narrow-range warning against its manual
  check.
- **S6**: "grip margin" in T54.
- **S7**: T23 builds the lookahead point itself and steers with T22's seek.
- **S8**: T54 measures grip in one calibration lap before the race, never
  saved. It is called the kit's own choice, with a fallback to a Python
  step if `check_no_training.py`'s net catches it.
- **S9-S13**: each reworded as the finding asks.
- **Notes**: every note is fixed. The survey's header now says the three
  quoted web pages were checked against their raw pages, and T54's manual
  check covers the large-gain weave.
- `make check` was run again after the fixes: exit 0.
