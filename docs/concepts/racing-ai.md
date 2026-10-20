# How racing AI is made: the line, the speed, and difficulty without a rubber band

<!-- doc-meta
half_life: concept
verified_on: 2026-10-18
tier: 1
source: https://www.gameaipro.com/
invalidated_if: T23 or T54 stop doing what the last section says they take from here
teaches: racing-ai
-->

> Before a car in this kit gets a driver -- the 2D one of T23, or the 3D one
> with real physics of T54 -- read how others have built one. This page
> surveys it from two sides, research and shipped games, and gives
> rubber-banding its own section, because T23 refuses it and should be able
> to say why with sources. Every reference was opened before it was cited.
> Where only an abstract, a record or an article *about* the work could be
> read, the reference says so; web pages read through a summarising fetch
> are paraphrased, not quoted -- except Reynolds, OpenStax and the Nature
> abstract, whose quotes the review checked against the raw pages. What could not be opened is listed at the end
> and not used.

## The short version

- **Almost every AI driver splits the job the same way**: choose a line, or
  a point on it ahead of the car; work out a target speed from what is
  coming; close the gap with throttle and brake; and put overtaking and
  crash handling on top. The 2009 research championship's winner was built
  like that [Loiacono et al. 2010], and so are the shipped architectures in
  Game AI Pro [Tomlinson & Melder 2013a, 2013b].
- **The two decisions a person can watch are a point and a speed.** Steer at
  a point a lookahead distance down the line -- pure pursuit, one parameter
  [Coulter 1992], the "rabbit" of shipped games [Tomlinson & Melder 2013b] --
  and brake when the speed the car would still have at the next corner,
  braking fully, is more than that corner allows [Tomlinson & Melder 2013b].
  The corner's limit comes from its curvature and the grip: friction is
  what turns the car [OpenStax 2016; Xue et al. 2023].
- **Learned drivers drive well and cost a lot.** A deep-RL driver beat the
  best humans in Gran Turismo Sport time trials after 56 to 73 hours on four
  consoles and a PC [Fuchs et al. 2021]; Gran Turismo Sophy beat champions
  head to head [Wurman et al. 2022 -- abstract only]. Evolved controllers
  were cheap and generalised badly to new tracks [Togelius 2006]; cloned
  ones had low training error and could not finish half a lap [Togelius et
  al. 2006].
- **The AI drives through the player's controls, but not always the
  player's car.** Game AI Pro's architecture recommends the same interface
  as the player's controller -- and balancing the field against the player
  in the physics, through grip, power and torque [Tomlinson & Melder 2013a].
  Driver: San Francisco's developers, by contrast, "were not allowed to
  cheat by giving the AI vehicles more power or tighter grip" -- a rule that
  came from the camera following AI cars for the visuals [Jenner & Ocio
  Barriales 2017].
- **Rubber-banding is real, argued for, and usually hidden.** Its strongest
  advocate writes that done correctly it "can be unnoticeable to the player"
  and that "when done poorly, it can leave the player feeling cheated", and
  recommends changing the driver's skill rather than the car's power
  [Melder, Rubber-banding 2013]. Pure's developers rejected it as unfair and easy to
  spot, then shipped a skill-based balancing system under another name
  [Jimenez 2009]. The kit's rule -- a car is faster because it is driven
  better -- matches a fixed skill level, not a skill that moves with the
  player's position, and this page says so.

## The academic side

### Steering at a point ahead

Reynolds's steering behaviours are the kit's T22, and their structure is
the racing driver's: "a hierarchy of three layers: action selection,
steering, and locomotion" [Reynolds 1999]. Seek steers towards a point;
arrival slows inside a distance that "is a parameter of the behavior" --
the ancestor of a braking point; path following predicts where the
character will be and projects that onto the path.

Pure pursuit, from mobile robotics, is the same idea reduced to one formula
[Coulter 1992]: "We tend to think of the vehicle as chasing a point on the
path some distance ahead of it". The curvature to steer is twice the
point's sideways offset over the square of the lookahead distance, and
"there is one parameter in the pure pursuit algorithm, the lookahead
distance". Its trade-off is the lesson: longer lookahead converges "more
gradually and with less oscillation", but "the longer the lookahead
distance, the less 'curvy' of a path that can be followed" -- it cuts
corners. (The report is a scan; its equations were not legible, and the
formula is given here as its prose states it.)

### The research competitions

The Simulated Car Racing Championship ran drivers on TORCS through a
server that hands each one sensors, not the race [Loiacono et al. 2013]:
19 range finders across the front out to 200 m, the position across the
track, the angle to its axis, 36 sensors for opponents. If a driver does
not answer in time, "the simulation continues and the last performed
action is used". The organisers kept TORCS's own bots out because those
can see the whole state of the race.

Its 2009 results [Loiacono et al. 2010] are the most useful single source
on this page:

- **The winner was modular and mostly hand-made**: gear, target speed,
  speed control, steering, learning and opponents. Target speed came from
  "a simple handmade fuzzy controller with seven rules"; tuning it with a
  genetic algorithm brought "no clear benefits".
- **The second steered at the longest forward ray**, with its parameters
  tuned offline, and handled opponents by folding them into the track
  sensors as moving walls -- "an emergent opponent avoidance behavior".
- **The third was an evolved network with hand-written overtaking**:
  overtake on straights, brake in bends when too close.
- **The organisers' lessons**: offline tuning works; remembering where you
  crashed and slowing there on the next lap works; "imitation-based
  learning generally fails to produce competitive controllers"; and the
  best drivers were those that most improved how they handled opponents
  and crashes.

### Evolving and cloning a driver

Togelius & Lucas evolved controllers for a small 2D car [2005]: only a
network fed egocentric inputs -- speed, three wall rays, the angle to the
next waypoint -- learned to race, and the best narrowly beat the best human
who tried it, after 100 generations of 100. The catch came next: "no
controller performed very well on any track it had not been evolved on"
[Togelius 2006]; adding tracks one at a time helped, though the result was
still weak on some tracks. Cloning a player
failed in a way that should be remembered: networks trained to "low error
rates (typically 0.05)" did not complete "even half a lap", and a
nearest-neighbour clone looked human and almost always turned "a bit too
early or too late" [Togelius et al. 2006].

### Learned drivers, at the top

Fuchs et al. [2021] trained a deep-RL driver for Gran Turismo Sport in "less
than 73 hours" on four PlayStation 4s and a PC, about 946,000 km driven; it
decides in about 0.35 ms on a desktop CPU. It is told the curvature of the
road ahead as an input -- the same thing the hand-made drivers compute --
and its reward shows what a learned driver does if nothing stops it:
without a penalty for touching walls, policies "did not brake and simply
grinded along the track's walls". Each agent raced alone, one car on one
track, across three settings of two cars and two tracks.
Gran Turismo Sophy then beat four of the world's best players head to head,
with a reward written so the agent stays within racing's "important, but
under-specified, sportsmanship rules" [Wurman et al. 2022 -- abstract
only]. How much hardware it trained on could not be settled: Polyphony's
page and a Reuters report give different counts, and the paper's own figure
was behind a paywall.

### The line, and the speed along it

Racing-line optimisation is its own field. A minimum-curvature line is a
quadratic program, followed by a speed profile solved forwards and
backwards under acceleration limits; it drove a real autonomous car within
a tenth of a second of a human [Heilmeier et al. 2020 -- abstract and code
README only]. An open paper gives the speed limit at a point of the line as
the square root of the lateral acceleration available over the curvature,
and the method: start at the tightest points, the "bottlenecks", and grow
the speed profile outwards from each until they meet [Xue et al. 2023]. The
physics underneath is a first-year one: on a flat curve "the friction is
the centripetal force", so the grip coefficient fixes the fastest speed
through a given radius [OpenStax 2016]. Braking and turning share that one
grip budget -- the friction circle [Wikipedia, an encyclopedia entry].

## The shipped side

### The architecture

Game AI Pro's racing chapters are by developers who shipped racing games,
and they describe one architecture [Tomlinson & Melder 2013a, 2013b; Melder
& Tomlinson 2013]:

- **The track is data**: a list of nodes along the centre, each with widths
  to the track's edge, the run-off and the wall; the racing line "stored as
  a width offset at each track node". Lines start as designer splines or a
  recorded human lap (which "can be prone to kinks"), then are improved
  offline -- in their case by a genetic algorithm scored on lap time. Of
  balancing, they warn that the final arbiter of whether it worked "must be
  a human".
- **Layers**: a persona, a strategy, tactics, and control, which computes
  "the controller inputs (steering, brake, and throttle)". Behaviours --
  drive, overtake, defend, recover -- are states that compete on a utility
  score, with hysteresis so they do not flicker.
- **The car steers at a rabbit**: steering at the line just ahead makes it
  weave, so it aims at a point further on, the distance tied to speed and
  curvature.
- **Braking is a prediction**: the speed limit at each node comes from its
  curvature, and "if the predicted speed with full braking is greater than
  the maximum speed at a node, then the driver must brake".
- **Control is PID**: the steering error is the distance from the line; a
  proportional term alone leaves the car "never" reaching it, the integral
  removes that offset, the derivative damps the overshoot; and "Kd and Ki
  are approximately half of Kp" in practice. Throttle and brake are two
  channels with a dead band between [Melder & Tomlinson 2013].

Driver: San Francisco plans in three tiers -- a route over the road
network, the cheapest few paths through a grid of lanes 100 m ahead, a
potential field over simplified physics -- and propagates each node's speed
limit backwards with the braking it allows -- the worked example's nodes
at 50, 30 and then 70 mph after the turn; a personality is a set of path costs [Jenner & Ocio
Barriales 2017 -- the first part of the chapter read].

### Overtaking: a heat line across the track

Reacting to one car at a time makes a driver pull out, rejoin, pull out
again; "an intelligent driver would overtake both vehicles in a single
maneuver" [Melder, Heat Vision 2013]. The heat-vision system keeps one
array across the track's width: cars add heat where they are, the racing
line adds its own, and a ball with momentum rolls to the coolest place,
which becomes the steering offset. Overtaking, running alongside and
blocking "occur naturally", and an aggressive driver is one that writes
narrower heat.

### Learning from a player

Forza's Drivatar learns how a player drives, not a recording of their laps
-- since Forza Motorsport 5 in the cloud [Xbox Wire 2014]. A commentator's
account says it learns per segment of track, so it carries to tracks the
player has not driven [Thompson 2021 -- not a developer source]. In 2025
Turn 10 wrote that its racing lines are made offline by simulating many
laps for each layout and car type, and that in traffic the cars leave the
stored line for a dynamic one -- which caused collisions, and for which it
announced a change to reduce them [Turn 10 2025, paraphrased]. Gran Turismo 7 now ships Sophy as a selectable
rival, adjustable for all levels; neither first-party page says how [Sony
AI 2023; Polyphony 2023, paraphrased].

### Difficulty

In Tomlinson & Melder's architecture skill is a multiplier on how much grip
the AI dares to use: the 0-100 setting mapped "onto a smaller range of say
98-99%" by default, 80-82% for an easier race, with a slow "biorhythm" --
a sine wave -- so a car is sometimes "temporarily vulnerable to being
overtaken" [2013a]. The same chapter warns that a narrow range makes the
drivers' differences hard to see -- which matters to a kit whose levels
must be visibly different. Forza 5 offers presets and charges the player
experience for the easiest [Engadget 2013, paraphrased]. GRIP: Combat Racing
puts catch-up on a switch the player can see, and its developer says that
without it the AI is not helped at all [Steam forum post by the developer,
2018, paraphrased]; a player in the same thread says the campaign forces it
on.

## Rubber-banding, for and against

**What it is.** Cars ahead of the player are slowed and cars behind get
"a boost to their speed", by a multiplier that grows with distance from the
player, with a dead zone around them [Melder, Rubber-banding 2013].

**For.** It keeps races close; the shipped goal is often to be beating the
player at the start and losing at the finish [Tomlinson & Melder 2013a].
"When done correctly, this effect can be unnoticeable to the player while
keeping the racing feeling close and exciting" [Melder, Rubber-banding
2013]. And balancing in the car is argued for openly: Game AI Pro's
architecture chapter says overall balance "is better achieved using
adjustments within the vehicle physics such as tire grip, engine power, and
torque" [Tomlinson & Melder 2013a] -- which is what a commentator reports
Forza doing [Thompson 2021].
Melder's chapter is a full system for it, including when to turn it off:
the start, low speed, and an AI lapping the player. Some games need it by
design -- Split/Second's power plays work only from behind, so a leader has
nothing to do [Mark 2010, a blog]. Mario Kart's catch-up is items, not AI
speed, so that a less experienced player who is lucky can sometimes win
[Nintendojo 2012, reporting an interview -- paraphrased].

**Against.** Melder, its advocate: "when done poorly, it can leave the player
feeling cheated, especially if the AI, racing in the same car as they,
obviously has more speed" -- so change the driver's skill, "as the drivers
are still in the same cars and so no 'cheating' is happening", and touch
power only when skill is spent [Melder, Rubber-banding 2013]. Pure's developers rejected it
as unfair and easy to spot, wanting players to feel they earned their place
[Jimenez 2009, paraphrased]. Dynamic difficulty works best unseen, and
rubber-banding is the kind players see [Compton 2019, a blog].

**What is shipped, in the sources read.** Two kinds. Skill that moves with
the player, limited and hidden near them: Melder recommends it, and Pure
shipped it -- its "Dynamic Competition Balancing" offsets each AI's skill by
its distance to a point near the player, follows a designer's script for
where the pack should be, and tapers the largest offset to zero over the
last fifth of the race -- and its author says they chose another name for it
because of rubber-banding's reputation [Jimenez 2009, paraphrased]. A
commentator reports that Turn 10 adjusts the cars -- weight, torque, tyre
friction, within a range -- rather than the AI [Thompson 2021; the talk it
cites was not found], as Game AI Pro's architecture chapter advises. How
common each is, these sources cannot say.

**Where the kit stands.** T23's rule -- the three levels differ in how well
the car is driven, every car runs one physics, and a command proves it --
is the fixed-skill lever and Driver: San Francisco's rule. It refuses
power and grip changes to the car, and it **also** refuses any change to a
driver's knobs during a race: skill that moves with the player's position,
which is what Pure shipped, and Game AI Pro's biorhythm, which is not tied
to the player but still changes the driver mid-race. The cost is said
plainly: the kit gives up the close finish those systems are for. A later task could add
catch-up as GRIP does: a switch the player sees, off by default, and drawn
on the car it helps.

## What this kit takes, and what it leaves

**T23, the 2D racer**, keeps its three knobs and gives each a source:

1. **Lookahead distance** -- pure pursuit's one parameter [Coulter 1992;
   Tomlinson & Melder 2013b]. Drawn: the point, and a line from the car to it. Short
   weaves, long cuts corners, and a person can see both.
2. **Grip margin** -- the fraction of the grip limit the driver dares to use
   [Tomlinson & Melder 2013a's 98-99%]. The speed profile is computed once
   per track from curvature and grip, backwards from the tightest corners
   [Xue et al. 2023; Jenner & Ocio Barriales 2017]; the braking point is
   where full braking would no longer make the next corner [Tomlinson &
   Melder 2013b]. Drawn: the limit as colour along the line, and the
   braking marker. A harder driver brakes visibly later.
3. **Steering wander** -- a deliberate offset from the line, as Melder &
   Tomlinson's error offset gives variety [2013].

**T54, the 3D racer with physics**, takes T23's driver and adds what a car
it does not fully know demands:

1. **PID control** of speed and of the distance from the line [Melder &
   Tomlinson 2013]. Toggle: proportional only, and the car settles off the
   line -- the steady-state offset the chapter names, drawn as a trace.
2. **The heat line for overtaking** [Melder, Heat Vision 2013]. Drawn under
   each car: the array across the track and the rolling ball. Toggle: off,
   and cars react to one rival at a time.
3. **A speed profile from the grip the car actually has**, measured rather
   than given, so the driver's margin means the same on a car whose tyres
   the driver cannot read off a constant. This is the kit's own choice, not
   a source's: Game AI Pro reads the available grip from the physics. T54
   says when it is measured and how that sits with invariant 6.

**Left:**

- **Learned drivers.** Tier 1 cannot train them; even the cheapest learned
  driver here needed tens of hours on consoles [Fuchs et al. 2021].
  Evolution of a few parameters offline -- what the 2009 entrants did -- is
  a possible later task, with the warning about generalising.
- **Cloning a player's driving.** Direct cloning failed in research
  [Togelius et al. 2006; Loiacono et al. 2010]. The same 2006 paper then
  took an indirect route -- evolving a controller to match measured traits
  of the player, such as progress, variance and how often the controls
  change -- which is closer to what Drivatar does on top of a fixed
  controller. Either is a later task if wanted.
- **Racing-line optimisation.** The line is stored as a designer's would
  be, an offset at each track node that a person can edit. T23's offsets
  came from a one-off search on lap time made while it was written, which
  is not in the kit and cannot be rerun from it; an optimiser worth
  reading is a lesson of its own.
- **Rubber-banding**, for the reasons above.

## Could not be checked

Not used above:

- Cardamone, Loiacono & Lanzi, "Learning drivers for TORCS through imitation
  using supervised methods", CIG 2009: only its record.
- Braghin et al., "Race driving model", 2008: no record or copy found.
- Wurman et al. 2022, the full text; and GTPlanet's pages on Sophy (blocked).
- Heilmeier et al., the full text (blocked); only its abstract and code are
  cited.
- Pacejka's and Milliken's vehicle-dynamics books: not opened.
- Forza's Drivatar papers at Microsoft Research, and the Turn 10 talk behind
  the claim that Forza adjusts the cars: not found.
- Jeff Hannan on Colin McRae Rally 2.0's network; Biasillo's chapters in AI
  Game Programming Wisdom; Iwata Asks on Mario Kart; Codemasters' F1
  difficulty; Burnout, Need for Speed, Blur and GRID: no developer source
  could be opened.

## References

Shipped games -- chapters and articles by their developers:

- Jenner, M., Ocio Barriales, S. "Fast Cars, Big City: The AI of Driver San
  Francisco." Game AI Pro 3, 2017, ch. 17; the first part read.
  <https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter17_The_AI_of_Driver_San_Francisco.pdf>
- Jimenez, E. "The Pure Advantage: Advanced Racing Game AI." Game
  Developer, 2009; read through a summarising fetch, paraphrased.
  <https://www.gamedeveloper.com/design/the-pure-advantage-advanced-racing-game-ai>
- Melder, N. "The Heat Vision System for Racing AI." Game AI Pro, 2013,
  ch. 41.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter41_The_Heat_Vision_System_for_Racing_AI.pdf>
- Melder, N. "A Rubber-Banding System for Gameplay and Race Management."
  Game AI Pro, 2013, ch. 42.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter42_A_Rubber-Banding_System_for_Gameplay_and_Race_Management.pdf>
- Melder, N., Tomlinson, S. "Racing Vehicle Control Systems using PID
  Controllers." Game AI Pro, 2013, ch. 40.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter40_Racing_Vehicle_Control_Systems_using_PID_Controllers.pdf>
- Sony AI. Press release on GT Sophy 2.0 in Gran Turismo 7, 2023;
  paraphrased. <https://ai.sony/articles/sonyai022/>
- Polyphony Digital. Gran Turismo 7 news on GT Sophy 2.0, 2023;
  paraphrased. <https://www.gran-turismo.com/gb/news/00_4176595.html>
- Tomlinson, S., Melder, N. "An Architecture Overview for AI in Racing
  Games." Game AI Pro, 2013, ch. 38 (2013a).
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter38_An_Architecture_Overview_for_AI_in_Racing_Games.pdf>
- Tomlinson, S., Melder, N. "Representing and Driving a Race Track for AI
  Controlled Vehicles." Game AI Pro, 2013, ch. 39 (2013b).
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter39_Representing_and_Driving_a_Race_Track_for_AI_Controlled_Vehicles.pdf>
- Turn 10 Studios. "Changes to Drivatar AI Coming in Forza Motorsport
  Update 20." 2025; paraphrased.
  <https://forza.net/news/forza-motorsport-drivatar-changes>
- Xbox Wire. "Forza Horizon 2: What's a Drivatar, and Why Should I Care?"
  2014; paraphrased.
  <https://news.xbox.com/en-us/2014/09/30/games-forza-horizon-2-drivatars/>
- A developer of GRIP: Combat Racing, Steam forum thread "Rubber banding",
  2018; paraphrased.
  <https://steamcommunity.com/app/396900/discussions/0/1752358461526206190>

About games, not by their developers:

- Compton, C. "More Than Meets the Eye: The Secrets of Dynamic Difficulty
  Adjustment." Game Developer blog, 2019; paraphrased.
  <https://www.gamedeveloper.com/design/more-than-meets-the-eye-the-secrets-of-dynamic-difficulty-adjustment>
- Hinkle, D. "Forza Motorsport 5's 'Drivatar' system fine-tunes the
  competition." Engadget, 2013; paraphrased.
  <https://www.engadget.com/2013-11-06-forza-motorsport-5s-drivatar-system-tunes-the-competition.html>
- Hsieh, Nintendojo, 2012, reporting an interview with Mario Kart 7's
  producer; paraphrased. <https://www.nintendojo.com/?p=67182>
- Mark, D. "Rubber-Banding as a Design Requirement." Game Developer blog,
  2010; paraphrased.
  <https://www.gamedeveloper.com/design/rubber-banding-as-a-design-requirement>
- Thompson, T. "How Forza's Drivatar Actually Works." Game Developer, 2021;
  a commentator, paraphrased.
  <https://www.gamedeveloper.com/design/how-forza-s-drivatar-actually-works>
- "Circle of forces." Wikipedia. <https://en.wikipedia.org/wiki/Circle_of_forces>

Research and textbooks:

- Coulter, R.C. "Implementation of the Pure Pursuit Path Tracking
  Algorithm." CMU-RI-TR-92-01, Carnegie Mellon University, 1992.
  <https://www.ri.cmu.edu/pub_files/pub3/coulter_r_craig_1992_1/coulter_r_craig_1992_1.pdf>
- Fuchs, F., Song, Y., Kaufmann, E., Scaramuzza, D., Dürr, P. "Super-Human
  Performance in Gran Turismo Sport Using Deep Reinforcement Learning."
  IEEE Robotics and Automation Letters, 2021.
  <https://arxiv.org/abs/2008.07971>
- Heilmeier, A., et al. "Minimum curvature trajectory planning and control
  for an autonomous race car." Vehicle System Dynamics 58(10), 2020;
  abstract and the authors' code only.
  <https://portal.fis.tum.de/en/publications/minimum-curvature-trajectory-planning-and-control-for-an-autonomo/>
- Loiacono, D., Cardamone, L., Lanzi, P.L. "Simulated Car Racing
  Championship: Competition Software Manual." arXiv:1304.1672, 2013.
  <https://arxiv.org/abs/1304.1672>
- Loiacono, D., et al. "The 2009 Simulated Car Racing Championship." IEEE
  Transactions on Computational Intelligence and AI in Games 2(2), 2010.
  <http://julian.togelius.com/Loiacono2010The.pdf>
- Moebs, W., Ling, S.J., Sanny, J. University Physics Volume 1, §6.3,
  "Centripetal Force." OpenStax, 2016.
  <https://openstax.org/books/university-physics-volume-1/pages/6-3-centripetal-force>
- Reynolds, C.W. "Steering Behaviors For Autonomous Characters." GDC 1999.
  <https://www.red3d.com/cwr/steer/gdc99/>
- Togelius, J., Lucas, S.M. "Evolving Controllers for Simulated Car
  Racing." IEEE CEC 2005, as later cited by the authors.
  <http://julian.togelius.com/Togelius2005Evolving.pdf>
- Togelius, J. "Evolving robust and specialized car racing skills." IEEE
  CEC 2006, as later cited.
  <http://julian.togelius.com/Togelius2006Evolving.pdf>
- Togelius, J., De Nardi, R., Lucas, S.M. "Making Racing Fun Through Player
  Modeling and Track Evolution." SAB'06 workshop, as later cited.
  <http://julian.togelius.com/Togelius2006Making.pdf>
- Wurman, P.R., et al. "Outracing champion Gran Turismo drivers with deep
  reinforcement learning." Nature 602, 2022; abstract only.
  <https://www.nature.com/articles/s41586-021-04357-7>
- Xue, H., Yue, T., Dolan, J.M. "Spline-Based Minimum-Curvature Trajectory
  Optimization for Autonomous Racing." arXiv:2309.09186, 2023.
  <https://arxiv.org/abs/2309.09186>
