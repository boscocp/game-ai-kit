# Review: wave/38-how-fighting-game-ai-is-made

One fresh context reviewed it, in its own git worktree, at de07178. A docs
wave, so the review was of the citations: it opened the sources and read
them against what the page says.

## What was reviewed

Commit de07178: `docs/concepts/fighting-game-ai.md`, and T36, T37, T17, T18
and STATUS as rewritten from it.

## Checked and true

- `make check-no-engine` exited 0; the link, freshness and tier gates pass;
  the employer-reference gate, run with the author's list, is clean.
- Read against their sources and found as stated: the 15-frame quote and
  "most fighting games utilize pre-scripted AIs" (Lu et al.); the
  competition's rules; the 2015, 2016, 2019 and 2020 slides' counts and
  places; Tang et al.'s learning during play and its 2019 second place;
  Firoiu et al.'s 2 frames against 200 ms and the crouch at the edge; Oh et
  al.'s 62% against five professionals; Graepel et al.'s quotation; the 2007
  paper's Street Fighter Zero 3, Virtua Fighter 4 and Tekken 5 DR; the 2009
  paper's real-time learning; Siliconera, Automaton, GamesRadar and Game
  Developer as cited; the Lee-Urban slides' words; Ishihara 2018's
  believability; the Demediuk records; Khan, Halina, Gajardo and Saini from
  their abstracts or records.

## Findings

### Must fix

1. **The ghost papers do not use nearest neighbour.** The 2007 paper looks
   the situation up exactly, as a packed identifier; the 2009 paper groups
   values into ranges. Only Killer Instinct is nearest-neighbour. The page
   and T18 said otherwise.
2. **Tekken's ghosts were called case-based**; the 2007 paper says their
   method "remains undisclosed".
3. **"Beat the field from 2019 on" was wrong**: in 2019 minimax with rules
   won and the opponent-model entry came second. Page and T17.

### Should fix

4. Chance was said to stop repetition; the director said it makes the
   computer react more like a person.
5. "The textbook's warning" was the course slides'.
6. The 2016 winner was given an opponent model the slides do not describe.
7. Firoiu's delay result was overstated: delayed agents were *trained* with
   the delay, and the authors suspect more than the handicap.
8. "Opened, bar two" was untrue: both Demediuk papers, the GDC talk and the
   book could be read only as abstracts, records or overviews.
9. "Deep RL has not won" covered years not read; the 2017 winner was known
   from the 2019 slides.
10. "Mostly by hand" rested on one game; Lu et al. supports it.
11. "The complaint players make most" and "the famous complaint" had no
    source.
12. T37's acceptance was one command, with no numbers for its levels and no
    test named for its gate.
13. The Lee-Urban slides' title was the file name.

### Notes

The "current" rules ended in 2021 and summed Formula 1 points; the 2015
winner was unnamed; "a situation self-play had never shown it" is the
authors' hypothesis; "the learned policies" were some of them; "existing
engines" was M.U.G.E.N; Oh et al. is in print in 2022; the Shadow quote is
Bruce Hayles's.

## What was done about them

Every finding and note is corrected in the page, and the three must-fixes
in T17 and T18 as well:
- the ghosts look the situation up exactly; Killer Instinct alone retrieves
  the nearest; Tekken's method is "undisclosed"; T18's ghost column says
  both, the exact lookup being the simplest form;
- the competition's history says what won each year read, and that an
  opponent model came second in 2019 and won in 2020; deep RL "did not win
  in any year read, 2015 to 2020";
- the six sources read only as abstracts, records or overviews are named in
  the page's opening, and the GDC talk is cited only for what it is about;
- T37 cites Lu et al. for scripting, Siliconera for chance and for "inhuman
  reflexes" in place of the unsourced complaint, and its acceptance names
  `fight_opponent_test.gd`, `opponent_levels.gd` -- 60 wins of 100 seeded
  fights against the level below -- and the demo overlay check.
