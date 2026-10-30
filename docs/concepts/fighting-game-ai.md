# How fighting-game AI is made: the literature, the shipped games, and what this kit takes

<!-- doc-meta
half_life: concept
verified_on: 2026-10-15
tier: 1
source: https://www.ice.ci.ritsumei.ac.jp/~ftgaic/
invalidated_if: T37, T17, T18 or T99 stop doing what the last section says they take from here
teaches: fighting-game-ai
-->

> Before writing an opponent for the fighting scenario, read how others have.
> This page is a survey from two sides -- what researchers have tried, and
> what shipped games do -- and it ends with what T37, T17 and T18 take from
> each. Every reference was opened before it was cited. Six could be read
> only as an abstract, a record or an overview -- Yoshida et al. 2016,
> Ishihara et al. 2016, both Demediuk et al. papers, the GDC 2016 talk and
> the Millington & Funge book -- and each is cited for no more than that
> page says. What could not be checked at all is listed at the end, and is
> not used.

## The short version

- **Shipped fighting games mostly script their opponents.** The research
  platform's paper says so of most fighting games [Lu et al. 2013], and one
  director describes it: designers enter what the computer does after a hit,
  a block, a whiff, a knockdown, and add chance so it reacts more like a
  person [Siliconera 2011]. Street Fighter 6
  organises those hand-written actions into situational "decks" and makes the
  computer *execute* them like a player, mistakes included [Automaton 2024].
- **The shipped opponents that copy a player record situations and
  answers.** Killer Instinct's Shadows retrieve the nearest recorded
  situation [Thompson 2017]; the published ghost papers look the situation
  up exactly, in ranges [Thunputtarakul & Kotrajaras 2007; Lueangrueangroj &
  Kotrajaras 2009]. Tekken's ghosts are the famous case, and their method was
  never published.
- **Research has its own arena**, the Fighting Game AI Competition, which has
  run from 2013. In the years whose results were read, hand-written rules won
  early; then Monte Carlo tree search with rules; then minimax with rules;
  then, in 2020, evolutionary planning with a model of the opponent learned
  during the fight. Deep reinforcement learning entered and placed third in
  2020, and did not win in any year read, 2015 to 2020 [FTGAIC slides].
- **The unfairness a player feels is mostly reaction time.** The competition
  hands every AI the game state 15 frames late to simulate a person's delay
  [Lu et al. 2013]; a deep RL agent competitive with ranked Smash players
  reacted in 2 frames, a tenth of a person's time -- and versions trained
  with a delay were "fairly strong" at 2 or 4 frames and dropped off sharply
  around 6 to 10 [Firoiu et al. 2017].

## The academic side

### The arena: FightingICE and its competition

FightingICE is a fighting game built at Ritsumeikan University for AI
research, with a competition held every year since 2013 [FTGAIC site]. Its
platform paper [Lu et al. 2013] gives two reasons for it: most fighting
games use pre-scripted AI that behaves the same way in the same situation,
and the engine fans used, M.U.G.E.N, made anything but rule-based AI hard to
write. Two design choices in it matter here:

- **The AI is given the state 15 frames late** -- "to give more risks to the
  defense play style and simulate the reaction delay of human players". A
  frame is 1/60 s, so 15 frames is a quarter of a second.
- **The AI presses buttons through the same interface as a person.**

What it measured (the last rules of the original competition, which ran to
2021 [FTGAIC rules]): round-robin games of three rounds, ranked by rounds won
with remaining health as the tie-break, and a speed league -- how fast an
entry beats a sample MCTS opponent -- each run per character, with the
overall winner on Formula 1 points summed across the leagues. Data for two
of the three characters is hidden, so an entry cannot be tuned to them in
advance.

What won, from the organisers' own slides:

| year | what the field and the winners were |
|---|---|
| 2015 | 17 entries, mostly rule-based or finite-state machines; a few predicted the opponent (k-NN, decision trees). The winner, Machete, was rule-based (named in the 2016 slides) |
| 2016 | 13 entries: 6 rules + MCTS, 5 rule-based. The winner extended MCTS to take the opponent's moves into the search, and for one character used Machete, the 2015 winner |
| 2019 | the winner swapped its MCTS for minimax plus per-character rules; second was rolling-horizon evolution with a learned opponent model |
| 2020 | 14 entries, 6 using deep learning (4 deep RL); first was evolutionary planning with an opponent model, third a deep RL agent (SAC) |

The same author won 2016 to 2019 -- the 2019 slides say so -- and the 2021
winner's method was not found. The 2020 runner-up's description is worth
reading on its own: it predicts
the opponent's three likeliest actions and searches against them. The
rolling-horizon entry is published [Tang et al. 2020]: the opponent model is
learned *during* play, it beat every 2018 entry in the authors' own tests,
and in the 2019 competition it came second.

Since 2022 the competition has run as DareFightingICE, whose AI track plays
from sound alone, for players who cannot see the screen [Khan et al. 2022].

### Search: MCTS, and difficulty from it

MCTS -- simulate many short futures, keep the action whose futures went best
-- was shown to work on FightingICE early [Yoshida et al. 2016; Ishihara et
al. 2016], the second paper noting that rule-based fighting AIs are
predictable to people. Two groups then used it to make an opponent *as good as
the player* rather than as good as possible: one aims MCTS at a health
difference of zero at the end of the fight [Demediuk et al. 2017], and
measured later whether players enjoyed it [Demediuk et al. 2019]; the other
adds a "believability" term so the adjusted opponent does not do unnatural
things such as taking damage without resisting [Ishihara et al. 2018].

### Learning from a player

- **"Ghosts" from recorded cases.** A player's fights are cut into
  situation-action cases; the ghost looks the situation up -- exactly, as a
  packed identifier -- and draws among the answers the player gave there, by
  how often they gave them [Thunputtarakul & Kotrajaras 2007, on Street
  Fighter Zero 3]. That paper's
  introduction is also the best source found on two shipped systems: Virtua
  Fighter 4 let players train an AI, and players found training it case by
  case hard; Tekken 5: Dark Resurrection built ghosts from normal play, by a
  method that "remains undisclosed". Offline ghosts were soon beaten by the
  people they faced, so a later paper makes the ghost learn during the
  match, groups values into ranges so similar cases match, and weights how
  often each imitated move is used [Lueangrueangroj & Kotrajaras 2009].
- **A data-driven state machine.** Recorded play split into tactics and
  strategy; a classifier maps tactics to states, and a learned state machine
  decides when to switch [Saini, Chung & Dawson 2011].

### Reinforcement learning

- **Tao Feng (2004).** SARSA, against the game's own state-machine AI. Some
  of the learned policies found "simple repetitive patterns of actions that
  exploit gaps in the rule-based built-in AI" [Graepel, Herbrich & Gold
  2004] -- a learner optimises the opponent it was trained against.
- **Super Smash Bros. Melee (2017).** Deep RL with self-play, competitive
  with ranked professionals -- reacting in 2 frames against a person's 200 ms
  or more, as the authors point out, and beaten by a player who crouched at
  the stage's edge -- because, the authors offer as one hypothesis, self-play
  had never shown it that [Firoiu et al. 2017].
- **Blade & Soul (2021, in print 2022).** Deep RL with a self-play curriculum and three
  reward-shaped styles; 62% against five professionals [Oh et al. 2021].
- **Difficulty by diversity.** Agents trained to be equally hard and
  different in strategy [Halina & Guzdial 2022].

### Predicting the next move: n-grams

The n-gram predictor -- "after these two moves, the player did this one N
times" -- is taught from Millington and Funge's textbook [Millington & Funge
2009, chapter 7, Learning], and a course built on it describes n-grams as
synonymous with combo-based melee games, able to make an unbeatable opponent,
and so often deliberately weakened [Lee-Urban 2019]. The book's own wording
could not be read for this page and is not quoted.

An overview of finite-state machines, behaviour trees and MCTS for
fighting-game opponents is a good next read [Gajardo, Besoain & Barriga
2020].

## The shipped side

- **Hand-authored, with chance.** Soulcalibur V's director: balancers enter
  the computer's reactions -- after a hit, a guard, a miss, a counter, a
  knockdown -- by hand, with probabilities so it reacts more like a person;
  without the time to do that well, the AI has "inhuman reflexes" or is
  one-dimensional [Siliconera 2011].
- **Decks, and execution.** Street Fighter 6's computer opponent, from a 2024
  talk by its planner: actions are cards in situational decks; a higher level
  has more decks and better execution; the computer must enter commands as a
  player does and can fail them, and a "pressure" gauge makes it fail more
  [Automaton 2024]. Level 6 has few tactics and clean execution, level 7 more
  tactics and shakier execution -- difficulty on two axes, not one.
- **Shadows.** Killer Instinct's Shadows (2015) copy a player. Bruce Hayles,
  of the studio that made them: "Everything your shadow does in a fight is
  something you've actually done before. If you never block while training
  your shadow, then it will never block" [McGee 2015]. Underneath it is
  case-based reasoning -- nearest-neighbour retrieval over 40-odd
  measurements of the fight, with the player's actions grouped into setups,
  combos and counters [Thompson 2017]. The team's GDC talk is about the same
  system [Hayles & Neal 2016].
- **Ghosts.** Tekken 5: Dark Resurrection made ghosts of players from
  ordinary play and used them as opponents [Thunputtarakul & Kotrajaras 2007;
  Lu et al. 2013]. How it built them was not published, and which game
  first had them was not established.

## How an opponent cheats, and how a player can tell

Two ways, and the sources treat them differently.

- **Reacting faster than a person.** The Smash agent's 2-frame reaction was
  its authors' own caveat; agents trained with a delay held up at 2 or 4
  frames and dropped off around 6 to 10 -- which the authors suspect is not
  only the handicap but the further separation of actions from their rewards
  [Firoiu et al. 2017]. The competition answers
  with a fixed 15-frame delay [Lu et al. 2013]. Soulcalibur V's director names
  "inhuman reflexes" as what an under-tuned AI has [Siliconera 2011]. A
  player tells by blocking: a low blocked on the frame it was pressed.
- **Reading the input** -- the computer answering the button, not the move
  on screen. No developer statement confirming or
  denying it in a shipped game was found, so this page makes no claim about
  any game. The rule this kit holds is the same either way: the opponent sees
  only what is on screen, as late as a person would.

## What this kit takes, and what it leaves

**T37, the fixed opponent**, takes the shipped side's shape and the
competition's honesty:
- **Hand-written reactions, by situation, with chance**, as Soulcalibur V's
  balancers write them -- grouped like Street Fighter 6's decks over T34's
  triangle -- guard, strike, throw -- and its heights: low, high, overhead, and
  the crouch that ducks a high (T34, T39).
- **Two knobs, not one**: how many tactics the level has, and how well it
  executes them (Street Fighter 6). Plus **reaction time in frames** -- the
  third, and the one the competition fixes at 15.
- **A reaction time of at least 15 frames at the top level**, and a gate that
  the opponent reads nothing newer than that. Nothing in the sources argues
  for faster, and the competition fixes it there for every entry.

**T17, the opponent model**, takes the n-gram, and a lesson from the
competition: a model of the opponent learned *during* the fight came second
in 2019 and won in 2020 [Tang et al. 2020; FTGAIC slides]. So the model is
updated as the round goes, and decays. Its predictions are drawn on screen,
as T17 already asks. It keeps the course's warning [Lee-Urban 2019] on
purpose: a perfect predictor is no fun, so T17's opponent uses the
prediction to choose, through T37's levels.

**T18, learning from a recorded player**, takes the ghost: recorded
situations and the player's answers. Killer Instinct's Shadows retrieve the
nearest situation; the 2007 and 2009 papers look it up exactly, in ranges.
The comparison T18 already asks for gains a third column: the n-gram (T17),
the nearest-neighbour ghost, and the small model T18 trains -- and the exact
lookup is the ghost's simplest form, worth a row of its own. If the ghost is as good as the model here, T18
says so.

**T99, the bandit opponent**, takes the bandit (AIMA 4th ed., 17.3; GAP2
ch. 25) and keeps everything T37 decided but the draw. Each situation gets a
UCB1 bandit [Auer et al. 2002] over the options its level knows there; an
option is paid the change in the health lead while it played and for half a
second after, scaled into [0, 1] by a hundred health. The n-gram predicts
what *you* will do; the bandit only measures what *its own* answers earned
against you. ADR 0016's amendment lets it count during the fight, on the
n-gram's three conditions, and `check_no_training.py`'s N13 holds the shape.

Measured with `make measure-bandit` on 2026-10-30: lancer mirrors, 100
fights per row, the bandit or T37's fixed opponent at the same level
against each of T18's stand-ins and the owner's ghost (T40's frozen copy of
the nine fights the owner recorded). "Settled after" is the median, over
the 100 fights, of the pull after which the arm its busiest situation's
bandit had pulled most stopped changing; beside it, how many pulls that
bandit had in all.

| against | level | T37 fixed wins | bandit wins, UCB1 at 0.5 | settled after | of | bandit wins, UCB1 at the square root of two | settled after | of |
|---|---|---|---|---|---|---|---|---|
| rushdown | medium | 68 | 78 | 25 | 55 | 71 | 41 | 59 |
| rushdown | hard | 88 | 83 | 44 | 51 | 76 | 46 | 52 |
| turtle | medium | 20 | 42 | 45 | 87 | 17 | 72 | 88 |
| turtle | hard | 73 | 90 | 53 | 71 | 91 | 68 | 83 |
| jumper | medium | 100 | 100 | 34 | 67 | 100 | 58 | 83 |
| jumper | hard | 100 | 100 | 54 | 70 | 99 | 67 | 74 |
| the owner's ghost | medium | 30 | 44 | 46 | 83 | 36 | 59 | 78 |
| the owner's ghost | hard | 84 | 88 | 46 | 65 | 82 | 61 | 68 |

What it says:

- **At the textbook's constant it barely settles in a fight.** The square
  root of two is sized for payoffs anywhere in [0, 1]; these lie near 0.5
  (four in five within a quarter of it, two in five on it), so the
  exploration term outweighs every difference in mean, and the busiest
  bandit is still changing its mind four-fifths of the way through the
  fight. Against T37 it wins about as often -- more against the hard
  turtle, less against the hard rushdown: it pays for exploring and is not
  around long enough to collect.
- **At 0.5, the constant the opponent ships with, it settles sooner** --
  between half and seven-eighths of the way through its pulls, at medium
  nearer half -- and the medium bandit beats
  every opponent here at least as often as T37's medium: the turtle 42
  times against 20, the owner's ghost 44 against 30.
- **Hard gains less, and against the rushdown loses** (83 against 88).
  T40 tuned hard's weights against the owner's ghost, and a fixed draw that
  is already good leaves a bandit little to find and the price of trying
  everything first -- ten options in neutral, each once.

So the answer to the task's question -- how many pulls before it settles
-- is 25 to 54 of its busiest situation's, at 0.5: half to most of what one
fight gives it. And the lesson the
table teaches is the bandit's own: exploring costs, and the constant that
prices it should match how far apart the payoffs are.

**Left, and why:**
- **Deep reinforcement learning.** Tier 1 cannot train it, and the sources
  show its two failures this kit exists to avoid: exploiting the opponent it
  trained against [Graepel et al. 2004] and reacting faster than a person
  [Firoiu et al. 2017].
- **MCTS for the fighting scenario.** It needs a simulator it can run
  hundreds of times a frame; `FightRules.step` is one, and that is worth a
  task of its own after T18, not a part of these.
- **A throw escape window** (T34 left it to here). Nothing found makes it
  necessary for the opponent model: the guard-strike-throw triangle already
  gives T17 a choice to learn.

## Could not be checked

Not used above, and listed so nobody adds them from memory:

- Ricciardi & Thill, "Adaptive AI for fighting games": cited second-hand
  with two different years; no primary source opened.
- The wording of Millington & Funge's n-gram section and its fighting-game
  example: no legitimate copy opened. The chapter is confirmed; its text is
  not quoted.
- What the 2021 competition winner (BlackMamba) did: its slides were not
  reachable. The 2017 results page was not opened; that its winner was the
  2016-2019 author's comes from the 2019 slides.
- Virtua Fighter 4's training mode and Mortal Kombat 11's AI fighters from
  their publishers: no official source found.
- Whether any shipped game reads the input: no developer statement found.

## References

- **[Auer et al. 2002]** P. Auer, N. Cesa-Bianchi, P. Fischer,
  "Finite-time Analysis of the Multiarmed Bandit Problem", *Machine
  Learning* 47, 2002 -- UCB1's statement, figure 1, and theorem 1.
  <https://homes.di.unimi.it/~cesabian/Pubblicazioni/ml-02.pdf>
- **[FTGAIC site]** Fighting Game AI Competition, Intelligent Computer
  Entertainment Lab, Ritsumeikan University.
  <https://www.ice.ci.ritsumei.ac.jp/~ftgaic/>
- **[FTGAIC rules]** Competition rules.
  <https://ice.ci.ritsumei.ac.jp/~ftgaic/index-3.html>
- **[FTGAIC slides]** The organisers' results slides:
  [2015](https://www.slideshare.net/slideshow/2015-fighting-game-artificial-intelligence-competition/52412132),
  [2016](https://www.slideshare.net/slideshow/2016-fighting-game-artificial-intelligence-competition/66331117),
  [2019](https://www.slideshare.net/slideshow/2019-fighting-game-ai-competition/169944631),
  [2020](https://www.slideshare.net/slideshow/2020-fighting-game-ai-competition/238325035).
- **[Lu et al. 2013]** F. Lu, K. Yamamoto, L. H. Nomura, S. Mizuno, Y. Lee,
  R. Thawonmas, "Fighting Game Artificial Intelligence Competition Platform",
  IEEE GCCE 2013, pp. 320-323, doi:10.1109/GCCE.2013.6664844.
  <https://www.ice.ci.ritsumei.ac.jp/~ruck/PAP/gcce13-lu.pdf>
- **[Khan et al. 2022]** I. Khan, T. V. Nguyen, X. Dai, R. Thawonmas,
  "DareFightingICE Competition: A Fighting Game Sound Design and AI
  Competition", IEEE CoG 2022. <https://arxiv.org/abs/2203.01556>
- **[Tang et al. 2020]** Z. Tang, Y. Zhu, D. Zhao, S. M. Lucas, "Enhanced
  Rolling Horizon Evolution Algorithm with Opponent Model Learning: Results
  for the Fighting Game AI Competition", IEEE Transactions on Games,
  doi:10.1109/TG.2020.3022698.
  <https://gaigresearch.github.io/2020/06/15/tang2020enhanced/>
- **[Yoshida et al. 2016]** S. Yoshida, M. Ishihara, T. Miyazaki, Y.
  Nakagawa, T. Harada, R. Thawonmas, "Application of Monte-Carlo Tree Search
  in a Fighting Game AI", IEEE GCCE 2016, doi:10.1109/GCCE.2016.7800536.
- **[Ishihara et al. 2016]** M. Ishihara, T. Miyazaki, C. Y. Chu, T. Harada,
  R. Thawonmas, "Applying and Improving Monte-Carlo Tree Search in a Fighting
  Game AI", ACE 2016, doi:10.1145/3001773.3001797.
- **[Ishihara et al. 2018]** M. Ishihara, S. Ito, R. Ishii, T. Harada, R.
  Thawonmas, "Monte-Carlo Tree Search for Implementation of Dynamic
  Difficulty Adjustment Fighting Game AIs Having Believable Behaviors", IEEE
  CIG 2018, doi:10.1109/CIG.2018.8490376.
  <https://www.ice.ci.ritsumei.ac.jp/~ruck/PAP/cig2018-ishihara.pdf>
- **[Demediuk et al. 2017]** S. Demediuk, M. Tamassia, W. L. Raffe, F.
  Zambetta, X. Li, F. Mueller, "Monte Carlo Tree Search Based Algorithms for
  Dynamic Difficulty Adjustment", IEEE CIG 2017, pp. 53-59,
  doi:10.1109/CIG.2017.8080415. <https://opus.lib.uts.edu.au/handle/10453/127485>
- **[Demediuk et al. 2019]** S. Demediuk, M. Tamassia, X. Li, W. L. Raffe,
  "Challenging AI: Evaluating the Effect of MCTS-Driven Dynamic Difficulty
  Adjustment on Player Enjoyment", ACSW 2019, doi:10.1145/3290688.3290748.
  <https://opus.lib.uts.edu.au/handle/10453/134533>
- **[Thunputtarakul & Kotrajaras 2007]** W. Thunputtarakul, V. Kotrajaras,
  "Data Analysis for Ghost AI Creation in Commercial Fighting Games",
  GAME-ON 2007, Bologna.
  <https://www.cp.eng.chula.ac.th/~vishnu/gameProg/papers/wpj_vishnu07.pdf>
- **[Lueangrueangroj & Kotrajaras 2009]** S. Lueangrueangroj, V.
  Kotrajaras, "Real-Time Imitation Based Learning for Commercial Fighting
  Games", CGAT 2009 (venue as the author's publication list gives it).
  <https://www.cp.eng.chula.ac.th/~vishnu/gameProg/papers/CGAT_Real%20Time%20Imitaion%20Based%20Learning.pdf>
- **[Saini, Chung & Dawson 2011]** S. Saini, P. W. H. Chung, C. W. Dawson,
  "Mimicking human strategies in fighting games using a data driven finite
  state machine", IEEE ITAIC 2011, doi:10.1109/ITAIC.2011.6030356.
  <https://repository.lboro.ac.uk/articles/conference_contribution/Mimicking_human_strategies_in_fighting_games_using_a_data_driven_finite_state_machine/9405344>
- **[Graepel, Herbrich & Gold 2004]** T. Graepel, R. Herbrich, J. Gold,
  "Learning to Fight", CGAIDE 2004.
  <https://www.microsoft.com/en-us/research/publication/learning-to-fight/>
- **[Firoiu et al. 2017]** V. Firoiu, W. F. Whitney, J. B. Tenenbaum,
  "Beating the World's Best at Super Smash Bros. with Deep Reinforcement
  Learning", arXiv:1702.06230. <https://arxiv.org/abs/1702.06230>
- **[Oh et al. 2021]** I. Oh, S. Rho, S. Moon, S. Son, H. Lee, J. Chung,
  "Creating Pro-Level AI for a Real-Time Fighting Game Using Deep
  Reinforcement Learning", IEEE Transactions on Games 14(2), 2022 (online
  2021), doi:10.1109/TG.2021.3049539. <https://arxiv.org/abs/1904.03821>
- **[Halina & Guzdial 2022]** E. Halina, M. Guzdial, "Diversity-based Deep
  Reinforcement Learning Towards Multidimensional Difficulty for Fighting
  Game AI", EXAG 2022. <https://arxiv.org/abs/2211.02759>
- **[Millington & Funge 2009]** I. Millington, J. Funge, *Artificial
  Intelligence for Games*, 2nd ed., Morgan Kaufmann, 2009.
  <https://shop.elsevier.com/books/artificial-intelligence-for-games/millington/978-0-12-374731-0>
- **[Lee-Urban 2019]** S. Lee-Urban, "Capturing and Reusing Experience",
  Georgia Tech game AI lecture slides, 18 November 2019.
  <https://faculty.cc.gatech.edu/~surban6/2019fa-gameAI/lectures/2019_11_18-Prediction_Ngram.pdf>
- **[Gajardo, Besoain & Barriga 2020]** I. Gajardo, F. Besoain, N. A.
  Barriga, "Introduction to Behavior Algorithms for Fighting Games",
  arXiv:2007.12586. <https://arxiv.org/abs/2007.12586>
- **[McGee 2015]** M. McGee, "Thought Shao Kahn was tough? Here's the future
  of fighting game AI", GamesRadar+, 29 May 2015.
  <https://www.gamesradar.com/future-fighting-game-ai/>
- **[Thompson 2017]** T. Thompson, "The Killer Groove: The Shadow AI of
  Killer Instinct", Game Developer, 13 October 2017.
  <https://www.gamedeveloper.com/programming/the-killer-groove-the-shadow-ai-of-killer-instinct>
- **[Hayles & Neal 2016]** B. Hayles, D. Neal, "Designing AI for Competitive
  Games", GDC 2016. <https://gdcvault.com/play/1023291/Designing-AI-for-Competitive>
- **[Siliconera 2011]** I. Sahdev, "Soulcalibur V Director Talks CPU
  Fighters, Says Broken Destiny Had Best AI", Siliconera, 25 May 2011.
  <https://www.siliconera.com/?p=132338>
- **[Automaton 2024]** "Street Fighter 6's CPU is designed to feel
  'pressured' just like a human and make input mistakes", Automaton West, 27
  August 2024, reporting a CEDEC 2024 talk by Naohiro Yasuhara.
  <https://automaton-media.com/en/news/street-fighter-6s-cpu-is-designed-to-feel-pressured-just-like-a-human-and-make-input-mistakes/>
