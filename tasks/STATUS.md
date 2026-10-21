# Status

The index. One row per task; the task file holds everything needed to do it.
The topmost `## Resuming after` section is the next session's prompt.

## Resuming after 2026-10-21 (wave 73)

**Where it stopped -- read first.** Wave 73 did T54, the 3D racer, in
parallel with waves 71 and 72; nothing of the bot match was touched, and
`ai_steering` only gained two files. Its page is `docs/godot/racing3d.md`.

**What landed.** A car on four ray-cast wheels, a driver that is an agent
on its own view, `PidController` and `HeatLine` in `ai_steering` with
Python twins, fourteen vectors, five gates (`make test-racing3d-car`,
`-vectors`, `-effects`, `-ladder`, `-does-not-cheat`, all with
`--fixed-fps 60`), and `make demo-racing3d`.

**For the owner.** The manual check. The heat line's claim did not hold
(75 changes of side against 22), and P only swings rather than settling;
both are said as measured. Kenney's Racing Kit gives the scenery, not the
road: tiles on a grid could not make a second track of any shape.

## Resuming after 2026-10-21 (wave 71, T66 written, review next)

**Where it stopped -- read first.** T66 is written on
`wave/71-the-lanes-map`, one commit a step: height, the lanes, sprint,
the reload, the body, the zones, the aim, ammunition and the power
weapon, solid bodies, `PassageChoice` (a request the teammate weighs),
the yards and its mirror, and the review's fixes. The numbers are
in `docs/godot/botmatch.md`.

**Next: the PR.** The review is in `docs/reviews/71-the-lanes-map.md`,
its findings applied on the branch; push, PR, CI green, `make wave-merge`.
Then rebase `wave/72-the-bot-as-an-agent` (T67, being written in its own
worktree from this branch) onto main. `wave/73-racing-in-3d` (T54) and
`wave/74-the-stealth-research` (T52's research, with four questions for the
owner) are in worktrees of their own. The owner's manual check (`make demo-botmatch`, T to play,
L for the yards) is in T66.

**Then T67** (`tasks/T67-the-bot-as-an-agent.md`), the owner's choice:
the bot as AIMA's agent -- the priority list a weighed selector,
perception from `ai_perception`, the errands a technique. The owner's rule
behind it is now standing for every example: autonomy, as few fixed
if/else in a demo as can be.


## Milestone 1 — the vertical slice

A playable minimum where three techniques actually decide something.

| # | Task | State | Notes |
|---|---|---|---|
| T0 | Bootstrap: pinned Godot on the large disk | done | 4.7.2-stable, SHA-512 verified |
| T1 | Gates before the code | done | 14 gates, all in `make check` |
| T2 | `ai_core` and the board | done | reviewed three times; see the wave 07 record |
| T3 | `ai_search`: A\*, BFS, DFS, Dijkstra | done | 3 vectors and a 300-board property check |
| T4 | `ai_planning`: STRIPS, and a PDDL reader in Python | done | 8 steps, 14 states; 3 vectors read from both languages |
| T5 | Dataset and training (Python) | done | 87.8% against a 69.0% baseline, and 81.8% for a lookup table |
| T6 | `ai_learning`: inference, and the attack/retreat decision | done | 4 vectors read from both languages; invariant 6 finally has a gate |
| T7 | Close the slice: docs, ADRs, `make release` | done | 6 doc pages, 4 ADRs; a release the gate opens and checks |

## Milestone 2 — three games, three families of technique

Each game is chosen for the technique it makes obvious. The order is not
arbitrary: strategy finishes what T4 starts, stealth is the cheapest to build
and teaches the most per hour, and the fighting game is last of the three
because hitboxes and frame timing are a great deal of work that is not AI.

| # | Task | State | Notes |
|---|---|---|---|
| T8 | A board you can read | done | 48 px, centred, costs written, the highlight an overlay; manual check still a person's |
| T27 | Checkers, and minimax | done | `make run` is checkers against `ai_adversarial`; depth 4 by default (~50 ms); depth 6 stalls the frame up to ~730 ms with kings; the old board is `demo-skirmish`; manual check still a person's |
| T28 | Tic-tac-toe, and a machine that learns it | done | MENACE in Python, 304 boxes, four ages; `make demo-tictactoe`; N5/N6 in `check_no_training.py`; strength criterion changed to vs-perfect by the owner: Michie's rewards lock in a move that wins three in four, and the published machine still loses 10 in 1,000 to a random player |
| T29 | A search board you can edit | done | paint, erase, drag the dots, price mud; four named boards each with a checked promise; manual check still a person's |
| T30 | The tactical game, against the computer | done | `make demo-tactical`: spent units, undo, a confirmed end of turn; blue is a `BlueController`, rules today; blue walks at the workshop, not the nearest enemy (changed, pending the owner); 40-round draw; manual check still a person's |
| T9 | Art that is not a coloured square | done | 30 CC0 pictures from four Kenney packs, each listed with its sha256; `art.gd` the one path table; `make import` before any scene; manual check still a person's |
| T31 | Generate your own art, locally | done | `make artgen`: Z-Image-Turbo (owner's pick after a bake-off against FLUX.2 klein), fp8 + offload in 8.3 GB; gitignored output the game prefers, CC0 the default; 3 committed examples; ADR 0013 |
| T33 | Units that walk | done | Puny Characters (CC0) sheets for the shield and the soldier; units walk their route at 0.12 s a cell, march at rest, machines bob; `walk` kind in the generator on klein base + the svntax LoRA, sheets never committed; ADR 0014; manual check still a person's |
| T32 | Checkers with a learned evaluation | done | after Samuel (1959 paper, checked): Python rules and search held to Godot's by two vectors; logistic fit on self-play; learned loses 0.125 at two plies, 0.53 without its advancement weight; controls cannot be told from it (alpha-beta ignores scale); E toggles it in `make run`; manual check still a person's |
| T10 | The tactical scenario | done | five types, two towers, a workshop, funds, a forge, a river with one bridge; manual check: terrain yes, type feel waits on T26 |
| T11 | The planner plays | done | `PlannedBlue`, C in `make demo-tactical`: STRIPS over `spec/pddl/tactics-domain.pddl`, A\* with h_max over bits (383 worlds against breadth-first's 11102 on 60 boards); replans every 3 turns or when the plan stops running; plan listed and numbered on the board; against the rules 7-13 as blue, 0-20 as red; manual check still a person's |
| T12 | Three difficulties, honestly | done | `LeveledBlue`: the rules' walk, staying, or an attack cell, weighed at 1 or 2 plies with exact odds (`FightOdds`, never the board's dice) and Wesnoth's aggression; easy 1 ply noise 0.5, normal 1 ply, hard 2 plies; normal beat easy 70-29, hard normal 59-40, each level the rules 25 of 25 per seat; plan horizon 0 at every level -- a plan measured weaker (23-77); three, not five; S swaps sides; manual check still a person's |
| T13 | `ai_fuzzy`, from a library that already exists | done | rewritten, not ported: the library was C# and its core was missing (ADR 0011); 3 vectors read from both languages |
| T14 | The stealth scenario | done | `ai_perception`, fuzzy suspicion, three guard states; 4 properties over 300 maps |
| T15 | `ai_behaviour`: the four ways to decide | done | state machine, tree, GOAP (backwards, cheapest), HTN (forwards), and `WaysToDecide`, the table with STRIPS; one guard four ways in `make demo-behaviour`, 1-4 swap mid-round, a panel draws the state, the path, the plan; machine and HTN commit -- look, chase, catch -- tree and GOAP reconsider and never chase, GOAP doing the tree's deed every turn; HTN faster per plan (6-8 against 6-16 us); manual check still a person's |
| T16 | The fighting scenario | done | mostly not AI, and says so: frame data in `spec/frames/`, one axis, whole numbers, the resolution order written and tested rule by rule; a recorded log replays to committed per-frame digests; `make demo-fighting` is a training mode; manual check still a person's |
| T34 | High, low and the throw | done | four attack buttons, light quick and heavy slow; mid, low and overhead against standing and crouching guard; a throw that beats guard and loses to a strike; manual check still a person's |
| T35 | Fighters you can see | done | Puffolotti's CC0 karate template, two costumes; 30 strips of whole cells committed, the sheets only referenced (ADR 0015); a move's cels by phase, so the picture follows the frame data; manual check still a person's |
| T36 | How fighting-game AI is made | done | `docs/concepts/fighting-game-ai.md`: 26 sources, each opened, six as abstracts only and said so; most games script their opponents, the ones that copy a player record situations and answers, the arena hands every AI the fight 15 frames late; T37, T17 and T18 rewritten from it |
| T37 | A fixed opponent, at three honest levels | done | five situations, weighted options; reaction 30/22/15, tactics, execution; `FightDelay` hands it a copy of the past and refuses under 15; each level beats the one below 93-99 in 100 mirror fights; not a `DecisionPolicy` (board-typed); manual check still a person's |
| T38 | The jump | done | take-off, an arc in whole frames, landing; boxes are two intervals and the pass-over rule is geometry; four air moves, all overheads, one a jump; an uppercut anti-air; jumps cross over, guarded back from the strike; manual check still a person's |
| T39 | High punches pass over a crouch | done | the owner's finding from playing T34: standing punches and the dancer's roundhouse are high and miss a crouching fighter; the light kicks recut as side kicks to the waist; manual check still a person's |
| T17 | The opponent model | done | `ai_opponent`: an n-gram with additive smoothing and decay, held to Python by 4 vectors; the learner is T37's opponent leaning towards answers; 20/20 within 40 actions and after a switch; ADR 0016, the owner's exception to invariant 6, held by N9; manual check still a person's |
| T18 | Behaviour cloning, and what a learned model buys | done | the owner's nine fights, cut 15 frames late; every recording held out once: nothing fitted beats "always step in" (28.0%), the n-gram does by four points; ghosts beat medium 78-86 in 100, the clone 64; 0.04-0.12 ms a decision; a person could not tell them apart (ADR 0017, N10-N12) |
| T40 | An evade, and levels that are hard enough | wip | merged in wave 43: a backdash on its own button (O), 20-24 frames, invulnerable for the first quarter, after Strive; old logs replay unchanged; every level evades; hard holds 150/200 against a frozen copy of the owner's ghost (T37's hard: 109-133) and 130/200 against the turtle; not done: an answer that punishes over-evading (none reaches at a 15-frame reaction), step 5 and the manual check, which wait for the owner's new fights |
| T41 | What the owner found playing the boards | done | the mud route was breadth-first's, read as Dijkstra's: the status now says what each search minimises; markers measured against their terrain; blue builds a wader when red shuts the bridge; holding a skirmish node 3 turns wins, and the policy contests a held one |
| T42 | Examples that are fun to play | done | `docs/design/fun-review.md`; the owner: the board games already feel like games, the skirmish and the tactical board do not; picked T26 first, the skirmish folded into the tactical board (T44), and a fighting ladder (T43) |
| T25 | One team per technique: a league, scored twice | wip | wave 58, the strength half: T15's four as tactical teams on shared facts and deeds (GOAP priced in turns); `make league`, 8 teams, 280 games twice, Bradley-Terry with bootstrap intervals; learned +311, lookahead +263, the planner -177, none of the four T15 teams told apart from the rules (HTN +92, -4 to +199); every mean decision under 1.3 ms; `make record-tactical` keeps games in `data/tactical/`; not done: human-likeness (steps 4-6), the clone, the on-screen meter -- they wait for the owner's 20 recordings |
| T26 | Combat on the board | done | one rules file for Python and Godot, fights held by 5 hand-checked vectors; 7 hand-checked vectors; red and blue attack, towers fire at their turn start (one exchange), an attack cannot be undone; a workshop is besieged (20 health, a blow an attack) and destroying it wins; the counter tilts an even fight to ~94/28%; retrained: 85.9% against 56.8% and 78.8%; manual check still the owner's |
| T44 | The learned policy plays the tactical board | wip | wave 47: two control points paying 2 a turn, every turn opened by `TurnStart`; `LearnedBlue` (attack or retreat by the combat model, the point by the capture model); the combat model sees the counter, fitted on a typed dataset, 86.0% against 57.7%; measured: rules mirror red 20/20, learned against rules 17-18 draws in 20 -- stopped there for a study of similar games (`docs/design/tactical-references.md`), which became T45-T48; not done: the capture rows from the tactical map, the controller key, the skirmish's removal |
| T45 | The AI spends its money and keeps its pieces moving | wip | wave 49: spend first (build what beats most even when it cannot get there; a boxed workshop says so and is asked again), never idle (a fallback at the nearest red piece), one walker per point and per fallback target; win-rate limits for stuck walkers and funds left; acceptance fails -- learned stuck 44%/42%, 99 funds left: half the stuck walkers could move (staging waits for T48's threat map), the rest are boxed in behind one bridge, and income beats one build a turn; rules mirror 12-7-1 (was 20-0), planner 13-3 as blue, 0-20 as red |
| T46 | The learned blue commits to a fight | wip | wave 50: sets out at p(win) 0.5, gives the same fight up at 0.3 or below (no measurable effect: the way to a fight is one walk), joins another's fight within 3 cells, retreats only when red's strength near it outweighs blue's by Wesnoth's caution -- that one rule is the gain: learned as red 11-0-9 (was 4-0-16), as blue 0-5-15 (was 0-1-19); flips counted by distance 26%, as the rules; C cycles rules, planner, learned |
| T47 | The side moving second, and a last round that decides | done | blue starts with one more shield; at round 40 the higher score wins (workshop health, point-turns, what is left) and only equal scores draw; rules mirror 51-49-0 over 100 on wave 52's board; manual check still the owner's |
| T48 | The board itself: a second crossing, a threat map, shorter fights | wip | wave 52: two fords at rows 1 and 7 (cost 3; at the ends the first mover won every game, mid-board the second), the planner's crossing_open, a threat map by path drawn on the board (T) that nothing decides by yet; learned stuck about 29% -> 17-20%, 35 of 40 rules games decided before round 40; one blow and one back not started |
| T43 | A fighting ladder | blocked | set aside by the owner on 2026-10-19: the fighting game has had enough; next are T24 and the RTS (T19, T20). easy, medium, the clone, "ghost: nearest", hard, best of three each, with a clock and an ending; every opponent exists; picked in T42 |
| T21 | Every example can be watched | done | `check_demos.py` and `demo_overlays.gd`; blue's decision now drawn before it is played |
| T24 | One window for every example | done | wave 59: `make menu` is the main scene, eight cards from `godot/menu/catalogue.json`, Esc frees the example and comes back; `check_demos.py` C1-C8 hold every card to its target, its page and the classes its scene runs; `menu_walk.gd` plays and leaves every card; `make export` (templates pinned in bootstrap, the pack's directory read, the binary started headless) and the executable zipped by `make release` from a clean HEAD only; manual check still the owner's |

## Milestone 3 — real time, last

Deliberately last. It needs the content of T10, the difficulty knobs of T12, a
second state core, and everything the three earlier games taught about making
an AI legible. Built first it would have been a large pile of code with no
lesson in it.

| # | Task | State | Notes |
|---|---|---|---|
| T19 | The real-time core | done | `BoardState` at 200 units: ~50 ms a step, three frames, so `ai_rts_core` exists (ADR 0019); its simulation 0.7 ms, flow fields 0.34 ms (p95 1.29 of a 1.5 share); a scripted match at ~65x real time, replayed to its digest |
| T20 | The RTS demo | done | wave 62: the minimum game on T19's core (two resources, supply, a lab, a tower that sees, T10's counter circle, half-turn map); the commander plans the build order over a level 1 PDDL domain by STRIPS or HTN, timed by Churchill and Buro's jump, over a priority-queue economy; squads by a state machine, utility over an influence map with fog and memory, and FocusFire on whom to strike; commander 19 - 1 against the queues alone, normal 17 - 3 against easy, hard cut; Bos Wars sheets by sha256 (ADR 0020); split on 2026-10-20, the human side moved to T55; manual check still the owner's |
| T55 | The RTS's human side: a clock's knobs, the league in real time | todo | split from T20: a reaction delay drawn from recordings, an actions-per-minute cap, T25's league and meter on the RTS; needs T25's recordings |
| T56 | The armed tower: an upgrade the commander must choose to pay for | todo | the owner's request of 2026-10-20, playing T20: the tower that sees, upgraded to shoot, with line of fire; a new step in the build-order domain the commander must weigh against fighters |
| T57 | The RTS seat bias: a gate on the mirror match | todo | the queues against themselves went 15 - 5 to the west seat during T20's review and 9 - 11 after its fixes; nothing holds it, and a person always plays west |

## Milestone 4 — driving, which is the first thing not on a grid

A fourth game, after the three strategy ones and after the RTS, because that is
the order the owner wants to build them in. It earns its place by teaching a
family nothing before it does: every decision in this kit so far picks a cell
or an action, and a car picks *how hard to turn, right now*.

It is also the genre where difficulty most often cheats, which makes it the
best place to show the T12 rule holding under pressure: the hard car is hard
because it is driven better, and a command proves every car runs one physics.

| # | Task | State | Notes |
|---|---|---|---|
| T22 | `ai_steering`: not on a grid | done | seek, arrive, pursue, avoid, in GDScript and Python; 6 trajectories held to 1e-3 (9.4e-6 measured; Vector2 is 32-bit); over 100 starts arrive rests every time and seek never; `make demo-steering` draws each force |
| T23 | The racing demo, three honest difficulties | done | `make demo-racing`: pure pursuit on seek, a speed limit carried back from the corners; laps 39.6 / 36.6 / 35.1 s; `racing_does_not_cheat.gd` steps an honest twin race alongside and every car, decision and lap record must match it; seventeen planted cheats refused |
| T59 | Race the AI: a car you drive | done | wave 65: you against one AI level in the same car; a 24 m track, collisions that push, AIs that follow and pass; brake lights, tyre marks, a speedometer, your own braking bar; Kenney Racing Pack (CC0); laps 32.5 / 31.3 / 29.9 s alone; in traffic 5 seeds of 6 in order; owner raced it: "melhorou bastante" |
| T53 | How racing AI is made | done | `docs/concepts/racing-ai.md`: 30 references, each opened, those read in part said so; rubber-banding for and against; T23 and T54 rewritten from it |
| T54 | Racing in 3D, with physics the driver does not own | done | wave 73: a `RigidBody3D` on four ray-cast wheels (springs, tyres that slide past a peak, weight transfer nobody wrote); a driver that sees only its own view, finds its line by an elastic band, and measures its car on a test pad (grip 9.44 against the sheet's 10.29); PID and Melder's heat line in `ai_steering`; ladder 50.6 / 48.4 / 47.2 s on the loop and 43.9 / 41.9 / 40.4 on the untuned kidney; the no-cheat race matches an honest twin bit for bit, ten planted cheats refused; the heat line's claim (fewer changes of side) did not hold, printed not gated; `make demo-racing3d`; manual check still the owner's |

## Milestone 5 — shooters, in 3D

The owner's request of 2026-10-15, asked again 2026-10-18: shooters, first
and third person, with bots that act alone and cooperate, and a stealth
version of them. 3D enters through ADR 0018, proposed in wave 53 and
**accepted by the owner on 2026-10-21** (option A): a `godot/game3d/` folder, a tier of its own, every
decision on a snapshot with a Python twin, and assets referenced by URL and
sha256 and never committed.

| # | Task | State | Notes |
|---|---|---|---|
| T49 | How shooter AI is made | done | `docs/concepts/shooter-ai.md`: 48 references, each opened, a third only in part and said so; one bot, bots that cooperate, the stealth version; T51 and T52 written from it |
| T50 | The 3D tier, measured before anything is built | done | wave 69, ADR 0018 accepted (option A): physics, rays and a navmesh from collision shapes run headless; a run replays bit-identically on one binary; a navmesh set on a region's second frame never reaches the map (set it before the tree); about 1,000 fps for the 16-bot arena on a Radeon 610M; a body moved through its node is in the physics space a frame late; Kenney Mini Characters by URL and sha256, `make assets-3d`, primitives when missing; `check_no_assets.py`, R6 in `check_renderer.py`; Jolt explicit; `docs/godot/3d-headless.md`; manual check still the owner's |
| T51 | A bot match: two teams of bots, cover, and a commander | done | wave 70: `ai_teamwork` (tactical positions with claims, team influence, a commander, squad confidence and waves), Python twins, 17 vectors; a 6-a-side match as a physics-free simulation held to Godot's rays, mirrored; first-person takeover of any bot (owner's choice), tracers, hit markers, a rifle; measured on a fair mirror (9-11; A*'s tie order had bent it 18-2): claims cut bunching 0 s against 79, the commander spreads orders over 2.34 points against 1.81, retreat always leaves someone covering, no shot at an unseen enemy; in the score, retreat costs the match (20-0 without it), the commander suggests help (1.8 errors), claims nothing -- said as measured, as the owner chose (`docs/godot/botmatch.md`), T65 split off; manual check still the owner's |
| T52 | Bots against the player, with an optional stealth | todo | T50 done; reuse T51's first-person shot, tracers and HUD; third person; a role arbiter, awareness that accumulates with three alert levels, a shared belief map for the search -- each drawn and switchable |
| T65 | A coordinated team that wins | todo | split from T51 by the owner. T66 measured it on the lanes: claims and the commander each about one standard error better (not shown), retreat costs the match (20-0 without it); the owner decides whether to change retreat or close it as measured |
| T66 | The bot match on a map made for tactics, with a body to aim at | wip | wave 71, written and reviewed (`docs/reviews/71-the-lanes-map.md`), merge next: height in the simulation (`ArenaWalk`), the three-lane map and a second unlike it (`yards.json`), sprint, a seen and heard reload, 120 rounds and a base resupply, a power weapon and the five-kill reward, a humanoid body (Kenney Survivors, CC0), head/torso/limb zones, solid bodies; `AimChoice` and `PassageChoice` in `ai_teamwork` with twins and 15 vectors; both mirrors fair, every claim with a planted case that truly rejects; in the score claims and the commander about one error each, retreat costs the match (20-0) -- said as measured (`docs/godot/botmatch.md`); manual check the owner's |
| T67 | The bot as an agent: it perceives, weighs and decides, on any map | todo | the owner, during T66: autonomy over fixed if/else in every example, the bot as AIMA's agent that copes on another map; the priority list becomes a weighed selector, perception from `ai_perception`, the errands a technique; after wave 71, the owner's choice |

## The kit as modules

The owner's request of 2026-10-20, after wave 62: every AI a module that can
be configured into any game, a wave that tests and gates only what it
touches, and later a library others can install.

| # | Task | State | Notes |
|---|---|---|---|
| T58 | Modules, and gates that run for what a wave touches | done | wave 63: 23 manifests in `modules/`, held to the code by `lint-modules` (M0-M10); tests filed in `godot/test/<module>/`; `make check-affected` runs the lints and the modules a change reaches (code uses followed on, test-only uses not): 25-64 s for a change that evolves one module, against 550 s; a wave lands by pull request, as desk-panel's do; CI ran for the first time and found four defects in bootstrap and the runner rules; mk fragments dropped (measured, no gain); ports, kernel, registry and the library are later tasks; manual check the owner's |
| T60 | `ai_learning` without the board | done | wave 67: the adapter (`BoardFeatures`, `LearnedPolicy`, `LearnedDecision`) and the weights to `game/tactical`, the clone's weights to `game/fighting`; no default paths in the technique; `gameaikit.training` generic and in `ai_learning`, the tactical fit is `gameaikit.tactical`; checkers depends on `ai_learning`, not tactical; the skirmish found inside `game_shared` and made its own module; retrained, same numbers |
| T61 | A small shared kernel: the board leaves `ai_core` | done | wave 67: `ai_core` is `GridGraph` and `Pathfinder`; the board's eight classes are module `board` in `game/board/` (ADR 0021); addon comments name no board class; `unit_view.gd` owned by tactical, so `game_shared` depends on `ai_core` alone; a board change selects 10 modules, 19 before |
| T62 | Search over a port, not over a grid | done | wave 68: `SearchGraph` (contains, neighbours, cost_at, estimate) in `ai_search`, `GridSearchGraph` the grid's adapter with Manhattan moved there; the estimate promises consistency, not only admissibility; `Search` stops being a `Pathfinder` and `GridPathfinder` holds one as such; `Pathfinder` stays in `ai_core` (it keeps `tactical` free of `ai_search`); vectors replay unchanged; a waypoint test where hops and cost disagree, a hop-counting Dijkstra planted and caught; the adapter costs ~5% on 200 A\* searches |
| T63 | The controller registry | done | wave 68: `TacticalRoster`, ten rows in C's old order, read by `next_controller`, the league and the sentence on screen (the list lived three times); the four T15 teams and `TeamFacts` moved to `game/tactical/` with their tests; `tactical` drops `league`; the tactical card lists its controllers and `check_demos.py` C9 holds them to the table both ways; RTS, racing, fighting and the behaviour demo measured: each already one table, no chain |
| T64 | The library | todo | after T60-T63; names: only ports and kernel prefixed (owner, 2026-10-20), the prefix by ADR; addon zips filtered by manifest; `pyproject.toml`, flat layout, no dependencies; an entry-point group for a user's technique; installed and run outside the repo; publishing stays the owner's act |

---

## Resuming after 2026-10-21 (wave 70 merged, wave 71 opened)

**Where it stopped -- read first.** Wave 70 (T51, the bot match) merged as
PR #8 (`d98060a`). The owner asked for it to be merged before the CI had
finished: the full `make check-affected` was green locally on the merged
commit, and the gates job had failed only on the PR title's length. Read
`docs/godot/botmatch.md` for what T51 measured.

**Now: wave 71, T66** (`tasks/T66-the-lanes-map.md`), on branch
`wave/71-the-lanes-map`. It holds the owner's six asks after playing the
match, all written in the task:
1. a three-lane map with protected spawns, flanks and high ground (option
   1 chosen, research done);
2. sprint with Shift, no firing while sprinting;
3. a reload you can see and hear;
4. a humanoid body;
5. hit zones: head 2x, torso 1x, limbs 0.5x;
6. bots that aim where the expected damage is highest.

It also carries T65's question: does the coordinated team win on this map?

**Start at T66 step 1**, height in the simulation: a floor height per walk
cell, and a height-aware `SearchGraph` for A*. Two things T51 learned
must hold throughout. Red's paths stay searched in the mirror. The built
map must be mirrored exactly; the sketch is not quite. The fair mirror is
claim 0 of `botmatch_effects.gd`.

## Resuming after 2026-10-21 (wave 70)

**Where it stopped -- read first.** Wave 70 did T51, the bot match, as the
owner asked after wave 69 merged ("a proxima onda do fps"). The review
record is `docs/reviews/70-the-bot-match.md`.

**What landed.** `ai_teamwork` holds four techniques: tactical positions
with claims, a team's additive influence, a commander over weighed
objectives, and squad confidence with the retreat in waves. Each has a
Python twin and vectors from a third copy of the rules. The match runs as
a simulation with no physics engine, held to Godot's own rays. The 3D
scene draws the decisions, and `make demo-botmatch` opens it.

**The owner decided, mid-wave, three times.**
1. Both modes: watch, and T to take over any bot of either team.
2. First person, like Counter-Strike or Unreal, after playing the
   third-person cut. So the shot is a 3D ray, every shot leaves a tracer,
   there are hit markers and a rifle in view, and the rifle's rules are ten
   shots a second.
3. "Dizer a verdade": the score does not show the techniques winning.
   On a fair mirror, retreat costs the match and the commander's help is
   1.8 standard errors. T51 closes on the claims about what each technique
   decides; the page has the rest (`docs/godot/botmatch.md`), and T65 is
   "a coordinated team that wins".
4. After playing it: a better map -- covered points, flank routes, spawns
   behind corridors, high ground you can climb, like Counter-Strike's or
   Unreal's. That is the next wave, with T65.

**Measured, worth knowing.** Four things bent the mirror or the match:

- shots resolved in id order gave blue the first shot of every step;
- spawns on cell edges cost red a metre on the walk grid;
- a point inside a box left its bots without a path;
- and A*'s fixed order of neighbours made a path east unlike a path west,
  so blue won 18 to 2. Red's paths are now searched in the mirror.

The mirror's fairness is a claim of the effects test now.

**Next.** The owner's map, with T65 (`botmatch-map-like-cs` in memory):
read CS and UT layouts first. Then T52 or T64, as the owner says.

## Resuming after 2026-10-21 (wave 69)

**Where it stopped -- read first.** The owner accepted ADR 0018 on
2026-10-21, option A: the 3D lives in `godot/game3d/` inside the one
project, and its assets are out of git, referenced by their links. That
reordered the plan: milestone 5 opened before T64. Wave 69 did T50. The
review record is `docs/reviews/69-the-3d-tier.md`.

**What landed.** Jolt is set explicitly. `godot/game3d/assets.json` names
Kenney's Mini Characters (CC0) by page, archive URL and sha256.
`make assets-3d` fetches them into `godot/game3d/downloaded/` (gitignored).
`AssetShelf` hands back a primitive when a model is missing. A test arena
of T51's size has a legend and a sight-line overlay. `make test-game3d-floor`
holds what was measured. `check_no_assets.py` refuses a pack's file
committed under any name. `check_renderer.py` gains the missing 3D types and
R6: nothing in `game/` or `demos/` loads from `game3d/`.

**Measured, worth knowing** (`docs/godot/3d-headless.md`). Headless 3D
works, and a run replays bit-identically on one binary. A navmesh set on a
region's second physics frame never reaches the map. Every node under
`root` shares one navigation map, so a test makes its own. A body moved
through its node is in the physics space only a physics frame later; told
to the server, at once. On this machine
Godot used the integrated GPU only under X11, with three environment
variables set.

**Still the owner's.** The tier's name: the README writes "2, in 3D"
provisionally. Whether the tier-1 rule for a 3D example gets a gate.
Whether the assets rule reaches back to the 2D art. T50's manual check: open
the arena with and without the models (`make measure-3d` opens it).

**Next.** T51, the bot match, or T64, the library, which was next before
the owner opened milestone 5. Ask which.

## Resuming after 2026-10-21 (wave 68)

**Where it stopped -- read first.** Wave 68 did T62 and T63 together, as
the owner asked: one branch, each task in its own commits, one review. The
review record is `docs/reviews/68-search-port-and-registry.md`.

**What landed.** The four searches run on any `SearchGraph`, and the grid
is one adapter. A waypoint test shows the port, and shows why the estimate
must be consistent and not only admissible. The tactical board's
controllers are one table, `TacticalRoster`, read by the C key, the league
and the sentence on screen, and the menu's card is held to it (C9).
`tactical` no longer depends on `league`.

**Measured, worth knowing.** The extra layer costs about 5% on 200 A\*
searches. The league reads the table in C's order and seats teams by
place, so its table moved inside its intervals: same games, different
dice, the same verdicts. The old order put back reproduces `main` exactly.

**Next.** T64, the library (it needs T60-T63, all done now). Then milestone
5, after the owner decides ADR 0018, and T55-T57 last. Open by hand, since
`make wave` picks by table order: `make wave-start BRANCH=wave/69-the-library`.

## Resuming after 2026-10-20 (wave 67)

**Where it stopped -- read first.** Wave 67 did T60 and T61 together, as
the owner asked: one branch, each task in its own commits, one review. The
review record is `docs/reviews/67-learning-and-the-small-kernel.md`.

**What landed.** `ai_learning` reads no board, and `ai_core` holds only the
grid and the pathfinder interface; the tactical board is the examples'
kernel, `game/board/` (ADR 0021). Measured with `affected.py`: a change to
the learned model selects 9 modules (15 before), and a change to the board
selects 10 (19 before). Two couplings the plan did not know about were found
by measuring: the skirmish lived inside `game_shared`, and so did the one
view that draws board units.

**Next.** T62 (search over a port; it needs T61, now done) and T63 (the
controller registry), in either order, then T64. Then milestone 5, after
the owner decides ADR 0018. Open by hand, since `make wave` picks by table
order: `make wave-start BRANCH=wave/68-search-over-a-port`.

## Resuming after 2026-10-20 (wave 66)

**Where it stopped -- read first.** `make wave` picked T56; the standing
next step was to write the modularity tasks first, so the owner chose that
and the T56 branch was dropped unused. Wave 66 writes T60-T64 from T58's
plan, each with its diagnosis measured on `5129bfc`; no code moved. The
review record is `docs/reviews/66-the-modules-tasks.md`.

**The owner decided** (2026-10-20), both as recommended: T64 prefixes only
the ports and the kernel; T61's board kernel goes to `game/board/`. And the
order, said twice the same day: first these five, **T60-T64, before the next
milestone**; then milestone 5; the RTS improvements T55-T57 at the end.

**Next.** T60, T61 (it needs T60), then T62 (it needs T61) and T63 in
either order, T64 last. Then milestone 5, shooters in 3D: every task in it waits on ADR 0018
(*proposed*, wave 53), which the owner accepts, amends or rejects first.
`make wave` picks by table order and would offer T56; open T60 by hand:
`make wave-start BRANCH=wave/67-ai-learning-without-the-board`.

## Resuming after 2026-10-20 (wave 65)

**Where it stopped -- read first.** Wave 65 was T59, opened the same day
after the owner played T23's demo and asked whether they were meant to
drive. Mid-wave they asked for a wider track, collision, contrast and open
art. The review record is `docs/reviews/65-race-the-ai.md`.

**What landed.** You drive (`RacingHumanDriver`, a plain `RacingCar` on the
race's physics) against one AI level; Tab keeps T23's three-AI view. The
track is 24 m wide; cars start on a grid, bump instead of overlapping, and
every AI follows and sidesteps to pass a slower car -- a rule in
`RacingRace`, which a test holds never names a level. Art is Kenney's
Racing Pack (CC0), in `godot/assets/racing/`; a follow camera and a
minimap. The review found that following without passing let the leader
win every race and turned the ladder upside down in watch mode -- which
the honest twin could not see, since it runs the same race rules. Fixed
and measured: watch mode finishes hard, normal, easy on five seeds of
six. The owner then raced it and asked for real collisions, brake
feedback, easier corners and then a stronger brake: done in the same
wave, the car made kinder for everyone; they called it much better, the
collision good, and still hard to drive -- the aim here is the AI.

**For the owner.** T59's manual check: `make demo-racing`, race easy, then
hard. The AI starts on the inside of the front row; alone that slot is
worth nothing, measured, but whoever is behind into the first corner has
to pass.

**Next.** The same as after wave 63: write the ports and kernel, registry
and library tasks before starting one; then T56 or T57 as the owner
prefers.

## Resuming after 2026-10-20 (wave 64)

**Where it stopped -- read first.** Wave 64 was T23, the racing demo, the
owner's pick when `make wave` offered T56 (the owner chose it over writing
the ports, registry and library tasks first, which are still unwritten).
The review record is `docs/reviews/64-the-racing-demo.md`.

**What landed.** `godot/demos/racing/` (module `demo_racing`): a track as
nodes and a racing line as an offset at each, a car crude on purpose
(`RacingCar`, one shared `RacingPhysics`), and `RacingDriver` -- a point
`lookahead` metres down the line, drifted by `wander`, steered at with
`ai_steering`'s seek and pure pursuit's formula; a speed from the track's
limit, carried back from the slowest corner, times sqrt(grip margin). Two
gates: `make test-racing-ladder` (easy 39.6 s, normal 36.6 s, hard 35.1 s
a lap; at least a second apart) and `make test-racing-does-not-cheat` (one
physics field for field, no frame past grip or top speed, the knobs used
as reported, and the whole race equal, frame by frame, to an honest twin
the script builds itself -- after two reviews found eight cheats that got
through versions that trusted something a driver can reach).
The task file's last section says where the build differs from its steps.

**For the owner.** T23's manual check: `make demo-racing`, follow easy
(1) then hard (3), and say whether you can see why hard is faster -- the
cyan bar closer to each corner, the line greener through the bend. Still
yours from before: T58's and T20's manual checks, and `data/tactical/`.

**Next.** The same as after wave 63: write the ports and kernel, registry
and library tasks before starting one; then T56 or T57 as the owner
prefers.

## Resuming after 2026-10-20 (wave 63)

**Where it stopped -- read first.** Wave 63 was T58, the owner's
modularity request: done, merged by pull request #1. The review record is
`docs/reviews/63-modules-and-selective-gates.md` (two fresh reviews and
what CI's first ever runs found).

**How a wave runs now.** `make wave-start BRANCH=wave/NN-slug`, work,
`make check-affected BASE=origin/main` (not `make check`), push, `gh pr
create`, a review by a fresh context, apply what it found on the branch,
write the record, `make wave-merge` -- which waits for CI and squash-merges.
The owner authorised merging a reviewed, green pull request without asking
(2026-10-20). A new file needs a module: `make lint-modules` says which
rule it breaks. `make affected BASE=origin/main` says what a change selects
and why.

**What it measured.** `make check` 550 s; `check-affected` 25 s for a
steering force, 26 s for wave 57's demo change, 64 s for an RTS squad.
A wave that adds a module still runs everything (its manifest is global).

**For the owner.** T58's manual check: read `scripts/affected.py` top to
bottom, and the step 7 table in T58, and say whether the saving is worth
the selector. Still yours from before: T20's manual check, and
`data/tactical/`.

**Next.** The plan's later tasks, not yet numbered or written: the ports
and the small kernel (one addon a wave, `ai_learning` first; T58's D4 --
the measuring found `gameaikit.training` imports the tactical dataset, so
checkers' fit depends on the tactical game today), the controller registry
(D5), and the library (the naming decision first). Write them as tasks
before starting one; then T56, T57 or T23 as the owner prefers.

## Resuming after 2026-10-20 (wave 62)

**Where it stopped -- read first.** Wave 62 was T20, the RTS demo, opened
by hand as the owner chose (not `make wave`, which picks T23) and split
first: the human-likeness half and the RTS league became T55, which waits
on T25's recordings. The review is `docs/reviews/62-the-rts-demo.md`.

**What landed.** `godot/game/rts/` on `ai_rts_core`, whose table became
the minimum game and whose rules grew from the owner's play: separation,
a line of fire, strike-back at what a side sees, repair (a sixth order,
which also takes up a site left half-built), and three fog leaks closed.
The commander (`RtsCommander`) plans over
`spec/pddl/rts-build-order-domain.pddl` with STRIPS or the HTN (`H`),
`BuildSchedule` times the plan, `EconomyQueue` is the economy under it and
`QueueSide` the baseline; squads (`Squad`, `SquadTactics`, `FocusFire`,
`RtsInfluence`). The screen is StarCraft's: a camera, a minimap, a command
card with prices and reasons, a placing preview, half speed, paused at the
start. `make demo-rts`, `make rts-art` (Bos Wars, ADR 0020), `make
test-rts-match` (check and CI), `make rts-measure` (slow, by hand),
`docs/concepts/rts-ai.md`, ADR 0010 and 0019 amended.

**What the measurements said** (`make rts-measure`, ten seeds from both
seats): commander 19 - 1 against the queues alone; STRIPS and the HTN not
told apart (12 - 8); normal 17 - 3 against easy, and hard cut after 11 - 9
and 10 - 10 against normal; the queues' mirror 9 - 11 after the review's
fixes, 15 - 5 to west before them (T57 makes it a gate).

**For the owner.** T20's manual check: `make demo-rts` against normal --
it should lose to a good player and beat a careless one, and when it
loses you should be able to say what it got wrong. `make rts-art` once
for the sprites. New tasks from your play: T56 (the armed tower) and T57
(the seat bias gate). `data/tactical/` (your 2 T25 recordings) is still
untracked and untouched.

**Next: the modularity review you asked for on 2026-10-20**, after this
merge and before any new example: every AI a module configurable in any
game, gates that run only for what a wave touches, the design pattern that
fits, and a plan for a Python and Godot library -- written as a plan for
wave 63, for you to approve before it starts.

## Resuming after 2026-10-19 (wave 61)

**Where it stopped -- read first.** Wave 61 was T22, `ai_steering`, which
`make wave` picked after T19: T20 waits on T25, and T25 on the owner's
recordings. The review is `docs/reviews/61-ai-steering.md`.

**What landed.** `godot/addons/ai_steering/`: `SteeringVehicle` (Reynolds'
point with two limits, explicit Euler), `Steering` (clamping, a direction
to infinity that survives -- Godot's `normalized()` answers it with zero --
and the weighted sum), and seek, arrive (Millington's time-to-target),
pursue and avoid, a file each. `gameaikit.steering`, the same in Python.
`spec/vectors/steering/`: six trajectories from an independent
`derive.py`, at 1e-3 because `Vector2` is 32-bit
(`docs/godot/vector2-is-single-precision.md`). The review found avoid
pushing straight back and stalling in front of an obstacle on the line;
it now pushes only sideways, and `seek-and-avoid-head-on` pins it. `make
test-steering-properties` (check and CI): over 100 seeded starts arrive
rests inside its radius and stays, seek never rests, no force breaks its
limit -- each first shown a case it must refuse. `make demo-steering`,
with a card in the menu, and `docs/concepts/steering.md`.

**For the owner.** T22's manual check: `make demo-steering`, watch each
vehicle with its force drawn, and say what it is about to do before it
does. `data/tactical/` (your 2 T25 recordings) is still untracked and
untouched.

**Next (done in wave 62): T20, the RTS demo -- the owner's choice, on
2026-10-19, for a later day.** Not through `make wave`, which skips T20 while T25 waits on
the recordings: open its branch by hand (`make wave-start
BRANCH=wave/62-the-rts-demo`) and split T20 first -- the game, the map,
the economy, the units, fog, the Bos Wars art and the commander now; the
human-likeness half and the league, which need T25's twenty recordings,
later. The owner asked why wave 61 was T22 and not T20: `make wave`
picked it, and that should have been asked, not announced.

## Resuming after 2026-10-19 (wave 60)

**Where it stopped -- read first.** Wave 60 was T19, the real-time core,
the first of the RTS line the owner asked for. The review is
`docs/reviews/60-the-real-time-core.md`.

**What landed.** The task tried to prove itself unnecessary and could not:
`BoardState` moving 200 units one cell costs ~50 ms a step, against a
4 ms share. So `godot/addons/ai_rts_core/`: `RtsWorld` (mutates, a fixed
tick, a seeded dice, `digest()`), `SpatialHash`, `FlowField` (Dial's
Dijkstra, settled in slices), `RtsCommand` and `RtsRules` (the one door,
refusing before doing), `RtsSnapshot` (one side's fogged, read-only view,
all a controller ever sees), `RtsController`, `RtsMatch` (decisions,
counters, recording, replay) and `FrameBudget` (shares in ms; work, not the
clock, inside them). ADR 0019 says why there are two cores.
`make test-rts-budget` (in `check`, not CI: a timing on a shared runner)
and `make test-rts-simulation` (both): determinism by digest with a
planted second seed and a nudged unit, an economy that must carry income
home and raise a building, replay with a planted meddling, three cheats
refused, ~65x real time, fog planted in and out, counters equal to their
log and a clock that varies. The review found the snapshot's board leaking
the enemy's buildings through the fog, units walled in by a building, a
straight walk cutting corners, a site healing its damage and refusals
that leaked fog; all fixed on the branch.

**For the owner.** T20's art is decided and written into its task: Bos
Wars' sheets, referenced by URL and sha256 and downloaded on demand, never
committed. `data/tactical/` (your 2 T25 recordings) is still untracked and
untouched.

**Next:** T20, the RTS demo, on this core.

## Resuming after 2026-10-19 (wave 59)

**Where it stopped -- read first.** The owner set T43, the fighting ladder,
aside ("the fighting game has had enough"), asked for T24 and then the RTS
milestone. T43 is `blocked` with that note. Wave 59 was T24. The review is
`docs/reviews/59-one-window-for-every-example.md`.

**What landed.** `make menu`, now the project's main scene: every example
on one list, a card each -- what the AI decides, the techniques with the
part each plays, what to watch, the keys, the page -- read from
`godot/menu/catalogue.json`, which `check_demos.py` also reads (C1-C8: one
card per target, the page exists, every technique backed by a class the
scene really reaches, no example calls `quit()`). An example opens as the
current scene, so it runs as it does alone; Esc frees it. `make run` names
the checkers scene now. `make bootstrap` installs the Linux export
templates (archive SHA-512 pinned; CI skips them with
`GAK_SKIP_TEMPLATES=1`); `make export` refuses a template that does not
match, reads the `.pck`'s directory for what must and must not ship, and
starts the binary headless; `make release` zips it with LICENSE and NOTICE,
only from a `BUILD` stamp of a clean HEAD. Two new concept pages, so every
card has one: `docs/concepts/stealth.md` and `ways-to-decide.md`.

**For the owner.** T24's manual check: hand the executable to someone new,
three examples, can they say what decides from the card alone. Seen while
checking the menu by movie frames: the tactical board's three header lines
run off the right edge -- the same with `make demo-tactical` alone, so it
predates the menu. The 20 tactical recordings for T25 are still 2.

**Next:** T19, the real-time core -- the owner asked for the RTS line next.
It starts by trying to prove itself unnecessary: benchmark `BoardState` at
200 units x 60 steps first.

## Resuming after 2026-10-19 (wave 58)

**Where it stopped -- read first.** Wave 58 was T25's strength half, with
T15's four techniques written as tactical teams -- the owner's choice of
scope at the start. The review is `docs/reviews/58-one-team-per-technique.md`.

**What landed.** `godot/game/league/`: the state machine, the tree, GOAP and
the HTN on shared facts and five deeds, production left to the rules; the
roster of eight; `LeagueRating` (Bradley-Terry, bootstrap intervals);
`MeteredTeam`, the counters a meter will read. `make league` (~10 min, not
in `check`) and `make record-tactical`. C in the demo reaches the four.

**What the measurements said.** The learned policy and T12's hard level beat
the rules; the planner loses to them; none of the four T15 teams is told
apart from the rules, the HTN only just (+92, -4 to +199). On this board, with the same deeds, *how*
a deed is chosen moves the result less than five seeds of noise
(`docs/concepts/the-league.md`).

**For the owner.** T25's other half needs you: `make record-tactical`, and
twenty games against the rules (the computer's default). Then steps 4-6
and the clone. Still open from before: ADR 0018 (T50-T52, T54 blocked);
T48's third change; T45's and T46's bars; T11's plan and its horizon.

**Next:** `make wave` picks by table order; T25 is `wip` and will not be
picked again until the recordings exist.

## Resuming after 2026-10-19 (wave 57)

**Where it stopped -- read first.** Wave 57 was a fix the owner asked for
by looking: in `make demo-behaviour` the status and the brain's panel were
drawn over the board, white on green, and could not be read. The demo now
lays itself out -- board left, status under it, legend and panel in a
column -- and the owner read it and said it is fine. The review is
`docs/reviews/57-a-readable-behaviour-demo.md`.

**What the owner saw** in T15's manual check: the four brains looked
"slightly different", one smarter and one less -- which is what was
measured: the state machine and the HTN commit and chase, the tree and GOAP
turn back, and GOAP chooses the tree's deed every turn on this guard. For
the owner: a guard with two ways to a goal, at two costs, is what would let
GOAP stand apart from the tree; that would be a change to T15.

**Next:** unchanged from wave 56.

## Resuming after 2026-10-19 (wave 56)

**Where it stopped -- read first.** Wave 56 was T15, taken right after wave
55 on the owner's "do the next wave too". The review is
`docs/reviews/56-ai-behaviour.md`.

**What landed.** `ai_behaviour`: a state machine, a behaviour tree, GOAP
(A\* backwards from the goal) and an HTN (forwards by methods), and
`WaysToDecide`, the table of when each -- and STRIPS -- is right. The guard
is T14's room and perception written four ways in `demos/behaviour/`, each
a `DecisionPolicy`; `make demo-behaviour`, 1-4 swap mid-round.

**What the measurements said.** Left to run, the two brains that commit --
the state machine and the HTN -- look, chase and catch; the two that
reconsider -- tree and GOAP -- turn back each time suspicion dips and never
chase, and GOAP chooses the tree's deed every turn, since this guard has one
way to each goal. The HTN plans faster than GOAP (6-8 against 6-16 us, `make
test-behaviour-benchmark`) over 2-3 worlds or tasks -- true of these two
implementations, not proven of the two directions of search; the counts
are worlds for GOAP and tasks for the HTN, the nearest each has. The manual
check -- do the four look different while you swap them -- is the owner's.

**Next:** `make wave` picks by table order. Still the owner's: ADR 0018
(T50-T52, T54 blocked); T48's third change; T45's and T46's bars; whether
T11's plan should be made worth its horizon (wave 55).

## Resuming after 2026-10-19 (wave 55)

**Where it stopped -- read first.** Wave 55 was T12, taken as written on
the owner's word, though STATUS had said to ask first: the planner then
lost to the rules 2-18 as red, so "every level beats the rules" could not
hold with the planner as the base. It holds now. The review is
`docs/reviews/55-three-difficulties-honestly.md`.

**What landed.** `Difficulty` in `ai_planning` -- three knobs, an allowlist,
the presets; a horizon on `HeuristicPlanner`; `FightOdds`, a fight's odds
worked out from the rules and the die; `LeveledBlue`, which weighs the
rules' walk, staying and every attack cell at 1 or 2 plies. The scene's
computer is any controller on either side: C cycles rules, planner, learned,
easy, normal, hard; S swaps sides. `make test-difficulty-knobs` is in
`check`; `make test-difficulty-matches` (~15 min) is not, and says so --
CI does not hold the ladder.

**What the measurements said** (T12's record has every pairing, and the
command that plays any two points on the knobs). Three things were wrong
before the levels were ordered, each found by watching a game rather than
by tuning: a route to the goal round enemy pieces, which two sides ringing
their workshops left nobody with (everything froze); standing still valued
above the rules' fallback walk, so noise *helped*; and an answer counted in
full, so 2 plies stayed home -- Wesnoth's aggression (0.4) is from the
reference, not fitted. Hard over normal is the thinnest step, 59-40 against
a margin of 15 in 100. **The plan horizon is a knob that weakens**: no plan
beat T11's plan 77-23 at every horizon tried, so every level plans 0 actions
ahead -- for the owner: T11's plan is a worse strategy than buying by the
rules on today's board.

**Next:** `make wave` picks by table order. The owner's still open:
ADR 0018 (T50-T52, T54 blocked); T48's third change; T45's and T46's bars;
and whether T11's plan should be made worth its horizon.

## Resuming after 2026-10-18 (wave 54)

**Where it stopped -- read first.** Wave 54 was T53, documents only, taken
on the owner's "one more wave" after wave 53 (`make wave` would have picked
T12; T53 was chosen because it is the racing work asked for that day, needs
nothing, and unblocks T23 and T54). Reviewed and merged.

**What landed.** `docs/concepts/racing-ai.md`: how AI drivers are made,
research and shipped games, and rubber-banding for and against with
sources. T23 now names its three knobs from it (lookahead, grip margin,
wander) and its cheat check also refuses a knob that moves during a race
-- the skill-based rubber band shipped games hide. T54 takes PID control,
the heat line for overtaking, and grip measured in a lap.

**Next:** unchanged from wave 53 -- the owner decides ADR 0018; until then
T50-T52 and T54 stay `blocked`. T23 is now ready to build (it needs T21 and
T22; T22 is todo). `make wave` still picks T12 first by table order.

## Resuming after 2026-10-18 (wave 53)

**Where it stopped -- read first.** Wave 53 was documents only, as the owner
asked, and is reviewed and merged. Nothing in it is code. **The owner's
next decision is ADR 0018** (`docs/adr/0018-3d-enters-as-its-own-tier.md`,
*proposed*): where 3D lives (proposed: `godot/game3d/` in the one project),
which tier, how invariant 5 holds, and the assets rule the owner set
(referenced by URL and sha256, never committed, primitives when absent).
Until it is accepted, T50-T52 and T54 are marked `blocked` in the tables
(`next_wave.py` reads only task prerequisites, not an ADR's status, so the
state is what keeps them from being picked); set them back to `todo` when
the owner decides.

**What wave 53 landed.**
- **T49, done**: `docs/concepts/shooter-ai.md`, the survey of shooter AI --
  one bot, bots that cooperate, and the stealth version of the same bots,
  research and shipped games, every reference opened.
- **ADR 0018**, proposed.
- **Tasks**: T50 (the 3D tier, measured first), T51 (a bot-only match),
  T52 (bots against the player, optional stealth) in a new milestone 5;
  T53 (racing survey) and T54 (racing in 3D with physics) in milestone 4.

**Next, once the owner decides ADR 0018:** T50, then T51 or T52 in the
owner's order; T53 (needs nothing) before T23 and T54. If the owner wants
the assets rule applied to the committed 2D art too, that is its own task
(ADR 0018 lists it as a question). If the owner picks another option in the
ADR, T50 is rewritten first.

**Still the owner's, from wave 52:** T48's third change (one blow and one
back); whether T45's and T46's limits are still the right bars.

## Resuming after 2026-10-18 (wave 52)

**Where it stopped -- read first.** Wave 52 is reviewed and merged. The
owner asked for the next wave to start from a cleared context, and for it to
be **wave 53, documents only**, for the owner to review before any code:

1. `make wave-start BRANCH=wave/53-shooters-and-3d` (cut by hand).
2. **An ADR on 3D**, numbered 0018, status *proposed*: ADR 0001 says "no 3D
   lessons; if the kit ever grows them, they are a separate tier with their
   own ADR", and `scripts/check_renderer.py` fails on any 3D node under
   `game/` or `demos/`. Propose how 3D enters -- a separate folder outside
   those two (so the gate still holds for the 2D kit), a hardware tier of
   its own in the README's table, the renderer it needs, and that 3D assets
   are downloaded open packs referenced by URL and sha256, never committed
   (as ADR 0015 does for sprites). The owner decides; write the options.
3. **Tasks**, in `tasks/` and as rows in this file, following T36's pattern
   (survey first, then the example, the player toggling 1-3 techniques the
   survey found worth it):
   - a survey of shooter AI, FPS and third-person, market and academic
     (every source opened before it is cited, as T36 did);
   - a bot-only "multiplayer" shooter: bots autonomous and cooperating, using
     cover, no networking;
   - a single-player shooter with optional stealth for the player, bots
     cooperating against the player;
   - racing in 3D with more complex physics, beside the 2D T22/T23.
   Each task with a command for acceptance and a `## Manual check`.
4. Reviewed and merged like any wave. The owner's memory note
   `next-examples-racing-shooters` has the original request (2026-10-15).

**What wave 52 landed.** T48 in part: two fords at rows 1 and 7; the
planner's domain says `crossing_open`; a threat map by path, drawn and
toggled with T (nothing decides by it yet). T47 holds again: rules' mirror
51-49. The learned side's stuck walkers fell from about 29% to 17-20%.

**Still the owner's:** T48's third change (one blow and one back, retraining
the combat model); and whether T45's 5% stuck limit and T46's limits are
still the right bars.

## Resuming after 2026-10-18 (wave 51)

**What landed.** T47. Blue, moving second, starts with one more shield beside
its workshop; at round 40 the higher score wins (workshop health, then turns
holding points, then what is left standing) and only an equal score is a
draw. `make tactical-win-rates` takes `--pairings` and counts games settled
at the round limit.

**What the measurements said.** The rules' mirror is 59-41 with no draws over
100 games. The learned side now beats the rules 100-0 from both seats, but 61
of those are won on score at the limit -- the reference's caveat, and why the
count is printed.

**Next:** T48, as the owner asked -- a ford and a threat map, with staging on
it. T45's stuck walkers and T46's blue-seat draws are what it is for; the
third option (one blow and one back) waits for the owner, since it retrains
the combat model.

## Resuming after 2026-10-18 (wave 50)

**What landed.** T46, two limits short. The learned blue sets out for a fight
at p(win) 0.5 and gives that same fight up only at 0.3 or below, joins a
fight another walker of its side started within three cells, and retreats
only when red's strength near it outweighs blue's (Wesnoth's caution, this
board's version). C in `make demo-tactical` now cycles blue through the
rules, the planner and the learned policy.

**What the measurements said.** The strength rule is the gain: the learned
side wins 11 of 20 as red (was 4) and 5 as blue (was 1). The commitment makes
no difference on this board, where the way to a fight is one walk. Counted
by distance -- wave 50's review showed reading reasons missed most of them
-- the learned blue reverses direction on 26% of its walks, about as often as
the rules. As blue it still draws 15 of 20, behind the bridge (T45).

**Next:** T47 (the side moving second, and a last round that decides), then
T48 (the ford and the threat map, with staging), as the owner asked.

## Resuming after 2026-10-18 (wave 49)

**What landed.** T45, in part, taken out of table order on the owner's
choice (it is what the planner's idle workshop needed). The rules and the
learned blue spend first, never idle (a fallback at the nearest red piece),
and give each point to one walker a turn; a boxed-in workshop says so and is
asked again after its walkers move. `make tactical-win-rates` takes limits
on stuck walkers and funds left.

**What the measurements said.** The rules' mirror is no longer a first-mover
sweep (12-7-1), and the planner wins 13 of 20 as blue (wave 48: 7); as red
it still loses all 20. T45's own acceptance fails: the learned side's walkers
are stuck 44% and 42% of the time and blue ends with 99 funds. The review
showed half the stuck walkers could move -- a staging rule is the
controller's answer, and the reference wants it built on T48's threat map --
and the rest are boxed in behind the one bridge, while income beats one build
a turn. The numbers and the options are in T45's record.

**Next:** the owner asked to carry on with the design study's proposals
(`docs/design/tactical-references.md` §4) in its order: T46 (the learned
blue commits), T47 (the second player and the last round), then T48 -- a
ford and a threat map, with staging on it, which is where T45's acceptance
can be met.

## Resuming after 2026-10-18 (wave 48)

**What landed.** T11: the planner plays the tactical board. `ai_planning`
gained bits (`PackedDomain`), h_max and h_add (`RelaxedCost`) and A\* with a
budget and partial plans (`HeuristicPlanner`); the tactical domain is PDDL in
`spec/pddl/`, with a JSON twin held equal by `make test-python`;
`TacticalPlanBridge` turns the board into facts and steps into decisions;
`PlannedBlue` decides the purchases -- the forge, then the ram -- and its
walkers take the rules' routes, each naming the step it carries out. C swaps to it in `make demo-tactical`. ADR 0010 amended with the
numbers.

**What the measurements said.** The guesses cut worlds 29-fold and tie each
other (h_max is exact here), so the game uses h_max. The plan decides
purchases only; walkers take the rules' routes. Against the rules, the planner wins 7 of 20 as
blue (rules: 0) and 0 of 20 as red (rules: 20). Its mistakes are legible: it
saves its first turn while the rules build, and after the ram its workshop
idles on a rules refusal (T45's).

**Next:** T44's rest and T45-T48 are still waiting, and T45 is also what the
planner's idle workshop needs. `make wave` picks the first unblocked `todo` in
table order, which is now T12 -- check with the owner before taking it.

## Resuming after 2026-10-17 (wave 47)

**What landed.** T44 in part, then stopped on purpose. The tactical board
has two control points paying their holder, every turn opens in one place
(`TurnStart`), the combat model sees the counter table and was retrained on
a typed dataset, and `LearnedBlue` exists and is tested -- but is not yet a
key in the scene. `make tactical-win-rates` measures the controllers
against each other, with `--at-most` limits a task can use as acceptance.

**What the measurements said.** The rules' mirror: the side moving first
wins 20 of 20. The learned blue: 17-18 draws in 20 against the rules, 160+
funds banked, half its walkers' decisions stuck in a queue at the bridge. The
owner asked for a study of similar games before any more tuning:
[docs/design/tactical-references.md](../docs/design/tactical-references.md)
(Advance Wars, Wargroove, Wesnoth's AI read in its source, influence maps,
Into the Breach), and its ranked adjustments are T45-T48, each with a
measured acceptance.

**Next:** the owner asked for **T11**, the planner, to move the RTS line
forward. Know before starting it: T11's baseline is the rules blue, and in
the rules' mirror the side moving first wins every game -- measure the
planner from both seats. T44's rest and T45-T48 wait behind it.

## Resuming after 2026-10-17 (wave 46)

**What landed.** T26: combat on the tactical board. A fight is dice, the
same rule in Python's dataset and on the board (`spec/combat/rules.json`,
seven hand-checked vectors). Red attacks with a click, blue's rules attack
what they beat, bolt towers fire at their turn's start, and destroying the
enemy workshop wins -- a siege, because a workshop that fell to one attack
ended every game in round 3. The combat model was retrained on the new
rows.

**Not proven.** That the game is now worth playing: T26's manual check.
Rules against rules, red wins 58 of 60, for a reason not yet known.

**Next:** the owner plays three turns of `make demo-tactical` (T26's manual
check), then T44 -- which needs a fifth feature, the counter, and a typed
dataset (T26's step 8) -- then T43.

## Resuming after 2026-10-17 (wave 45)

**What landed.** T42, the fun review (`docs/design/fun-review.md`). The
owner: MENACE, checkers, the search demo and stealth already feel like
games; the skirmish and the tactical board do not. Picked: T26 (combat)
first, then T44 -- the skirmish folded into the tactical board, the learned
policy as one of blue's controllers -- and T43, a fighting ladder.

**Not proven.** That any of the three makes an example one a person wants
to play twice: that is each task's manual check.

**Next:** T26, then T44 (which needs it), then T43. Wave 45's review
reshaped all three -- blue attacks in T26, control points in T44 (the
owner's call), the ladder's order and clock in T43; see its record.

## Resuming after 2026-10-17 (wave 44)

**What landed.** T41, the owner's four reports, each reproduced first. The
"A\* through the mud" was breadth-first's route (the owner's screenshot
said so), and the screen now names what each search's route is the least
of. The start dot is yellow, the goal red, both ringed; the stealth exit is
cyan; `marker_contrast_test.gd` holds them to their tiles. Blue on the
tactical board stopped piling shields behind a bridge red has shut: it
counts red's pieces as walls and builds a wader. The skirmish has a win:
hold a node for 3 of your turns (a draw after 30 rounds), and a blue unit
with no fight to weigh walks at a node red stands on -- a rule beside the
models, said as one. The review's eight findings were all acted on; see
T41's "After the review".

**Not proven.** That the skirmish is now worth playing: the owner's three
games under T41's manual check.

**Next:** the owner plays T41's manual check, then T42.

## Resuming after 2026-10-16 (wave 43)

**What landed.** T40: the backdash -- `FightBackdash`, the O key, bit 512,
`backdash` in the frame data. It is invulnerable for its first quarter,
then cannot guard and can be thrown. Every level of the fixed opponent
backdashes. Hard was retuned by what each option won against the owner's
ghost. `make test-opponent-levels` holds it to 150 of 200 against a frozen
copy of that ghost, and to 130 of 200 against the turtle stand-in it was
not tuned on (as the lancer). The rows, the clone and the win rates were
redone, and no recording has an evade.

**The review's worst finding.** The opponent's answer to a backdash,
"long", could not reach one: seen 15 frames late, the backdash is over
first. It was removed, and step 3's "answer to a player who evades too
often" is **not done** -- T40 says so. See
[docs/reviews/43-an-evade-and-harder-levels.md](../docs/reviews/43-an-evade-and-harder-levels.md)
and T40's "After the review".

**Not proven.** That hard is hard for a person: its bar is a ghost it was
tuned against. That the opponents are now easier to tell apart: it needs
the owner's new fights.

**Next:** the owner plays hard (`make demo-fighting`, M to "opponent:
hard"), records fights with the evade in them (`make record-fights`, `make
train-clone`), and says whether the clone, the ghosts and the learner can
now be told apart (T40's step 5 and its manual check). Then what wave 42
listed: `make check-changed`, the racing and shooter surveys, T41, T42.

## Resuming after 2026-10-15 (wave 42)

**What landed.** T18: behaviour cloning. `make record-fights` keeps each
fight as its input log in `data/fights/` (ADR 0017); Godot replays them
and cuts one row per decision, the situation as six words as of 15 frames
before (`FightSituation`, `FightRecording`); `gameaikit.cloning` splits by
recording, fits a softmax and counts a ghost, and publishes
`ai_learning/clone_weights.json`, read by `ClonedPlayer`, `SoftmaxModel`
and `CaseTable`. The fighting demo has *ghost: exact*, *ghost: nearest* and
*clone* modes. `compare.py --report` is the comparison. Trained on the
owner's nine fights; the stand-ins stay as the contrast.

**The answer.** Over every recording held out once, nothing fitted
beforehand guesses the owner better than "always step in"; T17's n-gram
does, by four points. The ghosts make the better opponents. The owner could
not tell any of them apart, and suspects the moveset -- T40.

**The review's worst finding.** The clone was asked with the option it drew
as its `last`, where the rows hold what its fighter was seen doing: 28% of
its decisions. Fixed, tested over a whole fight, and the n-gram is now
scored as late as the models; the numbers changed and the page says the
first reading was wrong. See
[docs/reviews/42-behaviour-cloning.md](../docs/reviews/42-behaviour-cloning.md).

**Not proven.** Anything about people beyond one owner and nine fights. The
clone still decides more often than the player did.

**Next:** the owner asked for, after T18: `make check-changed` (only the
gates a change can reach); T40, an evade; then survey-first tasks for
racing (2D, and 3D with richer physics) and two shooters with bots -- a
bot-only match and a single-player one with optional stealth; 3D needs an
ADR against ADR 0001's no-3D rule first, and 3D assets are
referenced, never committed.

**Also noted, 2026-10-15:** the owner played the board demos and found
four problems (T41) and asked for more playful examples (T42). Not
scheduled yet; the owner said "for later".

## Resuming after 2026-10-15 (wave 41)

**What landed.** T17: the opponent model. `ai_opponent`, a new addon,
holds `NGramPredictor` -- what the player did after the last `order - 1`
actions, smoothed and decaying -- and `gameaikit.ngram` is its Python copy,
four vectors from `derive.py` holding both. The learner is T37's opponent
with the table behind it, watching the late fight `FightDelay` hands it and
leaning its level's options towards the answer to what it expects. ADR 0016
is the owner's exception to invariant 6: the table counts during one fight,
starts empty, and is never written down (N9). The training mode has three
learner modes, the table on the panel.

**The review's worst findings.** The lean was measured against certainty,
which a decaying table never reaches, so it never passed 2 of its 8; now
against the predictor's ceiling. "Starts empty every fight" had no test;
now `new_fight`, tested. Easy and medium often have no answer to lean
towards, and say so. All fixed; see
[docs/reviews/41-the-opponent-model.md](../docs/reviews/41-the-opponent-model.md).

**Not proven.** T17's manual check -- feel it punish a habit, then adapt --
with T34's, T35's, T37's, T38's and T39's. Whether the rescaled lean makes
the learner beat the fixed opponent more often was not measured again.

**Next:** T18, behaviour cloning, and what a learned model buys -- the n-gram, a ghost and a trained model, compared.

## Resuming after 2026-10-15 (wave 40)

**What landed.** T38: the jump. Up takes off over `takeoff` frames on the
ground, flies an arc of whole units, and lands; in the air a fighter cannot
guard or be thrown, and has one air move a jump -- an attack on every
button, all overheads. A box is two intervals now, and a high passes over a
crouch because it is above it: the special rule went, and the recorded
fight did not change. An uppercut per character is the anti-air. From the
owner playing it: air attacks on every button, and jumps that cross over --
a guard is held back from the way the strike travels, so a cross-up is
guarded the other way.

**The review's worst findings.** Two passes. Up on the frame a throw
arrived escaped it, and landing could not be thrown: take-off frames now,
and landing is throwable. A fighter knocked out of the air could kick again.
Two fighters on one spot blocked whichever way they held. All fixed; see
[docs/reviews/40-the-jump.md](../docs/reviews/40-the-jump.md).

**Not proven.** T38's manual check, with T34's, T35's, T37's and T39's.

**Next:** T17, the opponent model, with ADR 0016.

## Resuming after 2026-10-15 (wave 39)

**What landed.** T37: `FightOpponent`, a fixed opponent with five situations
and three levels, written as knobs -- reaction (30, 22, 15 frames), tactics,
execution. `FightDelay` seats it and hands it a copy of the fight its
reaction time old, never sooner than 15 frames. `make test-opponent-levels`
plays 600 mirror fights: each level beats the one below it 93 to 99 times
in 100, and a level against itself stays under 60. The training mode opens
on the medium opponent; the panel shows what it saw, on which frame, and
what it drew.

**The review's worst findings.** The header said hard "sees the same fight";
it sees it sooner, and now says so, with how much of its edge is the deciding.
The manual check promised something no level could pass. The seat copied
only at hand-over, so a caller stepping one state in place could show the
opponent the present. All fixed, with four untested paths; see
[docs/reviews/39-a-fixed-opponent-three-honest-levels.md](../docs/reviews/39-a-fixed-opponent-three-honest-levels.md).

**Not proven.** T37's manual check, with T34's, T35's and T39's.

**Next:** T38, the jump.

## Resuming after 2026-10-15 (wave 38)

**What landed.** T36: `docs/concepts/fighting-game-ai.md`, a survey of
fighting-game AI from the research arena and from shipped games, with what
could not be checked listed apart. T37, T17 and T18 rewritten from it.

**The review's worst findings.** Three claims stronger than their sources:
the ghost papers do exact lookup, not nearest neighbour; Tekken's method is
unpublished; an opponent model came second in 2019, not first. All fixed,
with ten more; see
[docs/reviews/38-how-fighting-game-ai-is-made.md](../docs/reviews/38-how-fighting-game-ai-is-made.md).

**Next:** T37, a fixed opponent at three honest levels: hand-written
reactions by situation, reaction of at least 15 frames, tactics and
execution as knobs, handed only the past.

## Resuming after 2026-10-15 (wave 37)

**What landed.** T39, from the owner playing T34: standing punches and the
dancer's roundhouse are high and pass over a crouch; the light kicks were
recut as side kicks to the waist and stay mid; the axe kick stays an
overhead. Hitstun is taken standing, so a combo cannot be ducked halfway.
A pass-over is an event the panel shows.

**The review's worst finding.** A fighter in hitstun could duck the second
hit of a combo by holding down. Fixed; see
[docs/reviews/37-high-punches-pass-over-a-crouch.md](../docs/reviews/37-high-punches-pass-over-a-crouch.md).

**Not proven.** T39's manual check, with T34's and T35's.

**Next:** T36, the survey of fighting-game AI. Its draft, from the references
opened in wave 36, is ready to go in as `docs/concepts/fighting-game-ai.md`.

## Resuming after 2026-10-15 (wave 36)

**What landed.** T35: the fighters have faces.
- Puffolotti's CC0 karate template, two costumes: the lancer orange at full
  size, the dancer blue at 80%, each move its own cels.
- Only the cuts are committed -- 30 strips of whole grid cells -- and the
  sheets are referenced by URL and sha256 (ADR 0015). `make fighter-sheets`
  and `make fighter-strips` repeat the cut, byte for byte.
- `FighterSprites.pose` picks a cel from the fight alone: a move's cels by
  phase, the walk from the fighter's own input, the hit from its stun.

**The review's worst findings.** The ADR quoted the author from the wrong
page and paraphrased him; it now quotes him exactly, from the page he wrote
it on. The walk read the view's redraws, not the fight, so the frame step
showed a walking fighter standing. Both fixed, with the rest; see
[docs/reviews/36-fighters-you-can-see.md](../docs/reviews/36-fighters-you-can-see.md).

**Not proven.** T34's and T35's manual checks: play it. The walk speed and
the hit animation want a person's eye.

**Next:** T36, the survey of fighting-game AI. A draft written from 28
references opened during wave 36 is the starting point.

## Resuming after 2026-10-15 (wave 35)

**What landed.** T34: high, low and the throw.
- Four attack buttons -- U/I punch, J/K kick, light quick and heavy slow --
  a throw on L, and S to crouch.
- Every move has a stance and a height. Standing guard stops mid and
  overhead, crouching guard mid and low, and nothing stops a throw. A
  strike beats a throw on the same frame, two throws break each other, and
  a throw never catches a fighter in stun.
- The recorded log must now cause a low and an overhead through the wrong
  guard, and a throw.
- Tasks written: T35 sprites, T36 the fighting-AI survey, T37 a fixed
  opponent at three honest levels, T38 the jump. T17 now waits on T37.

**The review's worst findings.** Six of the new rules had no test that
would notice them breaking (throws into stun, the clash, a cancel into a
crouching move, validation, the dummy), and the strike-beats-throw event
ran off the panel. All fixed; the ten surviving mutations are killed. See
[docs/reviews/35-high-low-and-the-throw.md](../docs/reviews/35-high-low-and-the-throw.md).

**Not proven.** T34's manual check: each guard against the dummy, by hand.

**Next:** T35, fighters you can see. The owner's rule: commit only the
cropped frames, never the downloaded sheets; the ADR keeps the URLs and
sha256s. The candidate found is Puffolotti's CC0 karate template
(OpenGameArt node 97941), two palettes of the same 997 cels.

## Resuming after 2026-10-14 (wave 34)

**What landed.** T16: the fighting scenario, with no AI yet.
- Two characters on one axis: the lancer has reach and starts slowly; the
  dancer is quick and short.
- Every number is in `spec/frames/characters.json`. The game reads a copy,
  held byte for byte. The order a frame resolves in is written there and
  followed step by step in `FightRules`: the buffer, acting, separation,
  every box tested at once, block or hit, counter-hit, trade, pushback,
  knockout.
- The engine uses whole numbers and an immutable state per frame. A
  recorded log (`godot/test/fighting/fight_log.json`) must replay to the per-frame
  digests committed beside it, and to the same digests twice. `make
  record-replay` rewrites them after a deliberate change.
- `make demo-fighting` is a training mode: you against a dummy that stands,
  blocks or jabs, every box drawn, and space steps one frame.

**The review's worst findings.**
- The determinism check could not see player two, or anything fixed for the
  life of a process.
- Half the resolution order had no test.
- The separation favoured the right-hand side.

All are fixed, and the 17 surviving mutations re-run are now killed. See
[docs/reviews/34-the-fighting-scenario.md](../docs/reviews/34-the-fighting-scenario.md).

**Not proven.** T16's manual check: play both characters against the dummy.
Moves should come out when asked, and a trade should resolve as the table
says.

**Next:** `make wave` cuts the next ready row. T17, the opponent model,
starts by reading `spec/frames/` from Python.

## Resuming after 2026-10-14 (wave 33)

**What landed.** T32: checkers with a learned evaluation, after Samuel.
- The rules and alpha-beta are in Python too. `spec/vectors/checkers/`
  holds the two languages to the same legal moves, crowns, captures and
  draws, and to the same counts and scores. A review cross-checked them on
  20,259 positions.
- Self-play: 400 games from seeded random openings, one ply deep, 394 of
  them distinct. A logistic fit on the decisive games used T5's trainer. The
  match, four shuffled-label controls and an ablation are all published in
  `godot/game/checkers/checkers_weights.json`. N7 retrains them all, which
  takes about two minutes; N8 refuses a write.
- In `make run`, E switches white's evaluation. The panel breaks the chosen
  value down by count under both sets of weights.

**The result is negative, and the page says why as far as it is measured.**
- The learned weights score 0.52 at one ply and 0.125 at two.
- With their advancement weight set to zero they score 0.53: under the
  fit, a man three rows up is worth less than nothing.
- The controls cannot be told apart from the learned weights. Alpha-beta
  ignores the scale of the weights, so a fit to noise is a random direction.
  The review found this; the concept page now says it.
- See [docs/concepts/learned-evaluation.md](../docs/concepts/learned-evaluation.md)
  and [the review](../docs/reviews/33-checkers-with-a-learned-evaluation.md).

**Not proven.** T32's manual check: toggle E on one position and name the
count the two evaluations weigh differently.

**Next:** `make wave` cuts T16, the fighting scenario.

## Resuming after 2026-10-14 (wave 32)

**What landed.** T33: the units on the tactical and skirmish boards walk.
- The shield and the soldier are Puny Characters figures (Shade,
  OpenGameArt, CC0). They march on the spot, walk their route at 0.12 s a
  cell facing each step, and stand still, greyed, once spent.
- The machines keep their pictures and bob as they roll. The buildings stay
  still.
- Blue's unit walks the route its pink line showed. Undo and a new game
  drop the walks.
- `UnitSheet` is the frame table, `UnitWalk` one trip along a route, and
  `UnitView` one clock that only `advance` moves. ADR 0014.
- The generator gained a `walk` kind on FLUX.2 klein base with the svntax
  LoRA. Its sheets stay in the gitignored folder and are never committed:
  the LoRA's training data is CC BY 4.0. A plain `make artgen` leaves them
  out; the how-to says how to make them. Four were made and look right.

**The review's worst findings.**
- The legends still showed the old silhouettes.
- A plain `make artgen` broke for anyone without the walk model.
- A new game kept the old game's facings.
- 9 of 30 mutations survived.

All are fixed. 12 mutations were re-run and every one is now killed; one,
a swap of Puny's left and right rows, is checked only by eye. See
[docs/reviews/32-units-that-walk.md](../docs/reviews/32-units-that-walk.md).

**Not proven.** T33's manual check: the owner plays `make demo-tactical`
and says whether walking units read better than still ones.

**Next:** `make wave` cuts T32, checkers with a learned evaluation.

## Resuming after 2026-10-14 (wave 30)

**What landed.** T9: the games draw pictures, not coloured squares.
- Thirty CC0 pictures from four Kenney packs:
  - the tactical game: five silhouettes for the kinds that walk, three
    buildings, a red and a blue copy of each;
  - checkers: chips, and a crown on a king;
  - noughts and crosses: an X and an O.
- Each file is the pack's own, byte for byte. `godot/assets/LICENCES.md`
  lists it by path, with its pack, CC0 1.0 and its sha256.
- `godot/game/art.gd` is the only code that names a path. Trees are a tile
  of their own now, and the legends show the pictures.
- ADR 0012 records the reversal of "no binary art", and the tier argument.

**Measured on the way**, in
[docs/godot/importing-art.md](../docs/godot/importing-art.md):
- a run imports nothing, so `make import` precedes every target that starts
  the engine, CI included;
- a texture loaded in `_draw` and let go draws as a white square, so `Art`
  keeps what it loads;
- a picture that fails to import poisons its committed `.import`, so
  `make import` fails on it and says how to recover.

**The review's worst findings.**
- T31's plan, "same paths, gitignored", could not work, and the gate would
  have credited generated art to Kenney. Rows now carry sha256s, and T31
  writes to a gitignored folder of its own.
- Nothing tested which picture a unit was drawn with.
- The licence rule took any licence and a row with a cell missing.

All are fixed. 29 of the 42 engine mutations had survived; every one that
is not visual is now caught. See
[docs/reviews/30-art-that-is-not-a-coloured-square.md](../docs/reviews/30-art-that-is-not-a-coloured-square.md).

**Not proven.** T9's manual check: someone who does not know which is
which looks at screenshots. The tactical sides differ by colour only, as in
the pack, and the checkers board is still two flat colours.

**Next:** `make wave` cuts T31. The owner added a test to its bake-off: a
12-frame walk cycle of one unit.

## Resuming after 2026-10-14 (wave 29)

**What landed.** T30: `make demo-tactical` replaces `play-tactical`. You play
red against the computer, with turns in the style of Advance Wars:
- click a unit and its reach lights up; click a lit cell and it walks and
  greys out. The next unit that can still move is put in your hand;
- W waits, Z (or the button) takes back anything done this turn, and ending
  the turn asks first while units are unspent;
- blue is whichever `BlueController` the scene is given. Today that is
  `RuleBasedBlue`: it builds what beats the most red pieces and walks every
  unit at red's workshop;
- each decision is drawn in pink with its reason before space plays it, and
  enter plays the rest of the turn;
- a unit beside the enemy workshop at the start of its side's turn wins
  (provisional until T26). After 40 rounds the game is a draw.

**For the owner: one rule differs from the task file.** T30 says blue
"walks each unit at the nearest enemy". The review measured that it never
wins: the nearest enemy is a bolt tower, and after 60 rounds blue had thirty
shields round it. Blue now walks at red's workshop, and beats a red that
only waits in round 5. The draw is also new. Both are noted in the task
file. Change them back if the original rule was the point.

**The review's worst findings.**
- Blue could not win.
- Nothing held that red's units come fresh at red's next turn.
- After the game ended, blue's next move was still drawn.
- The first click on the unit already in hand spent it.

All are fixed, and the 15 mutations behind them re-run red but one. That
one is a guard made redundant, so it was removed. See
[docs/reviews/29-the-tactical-game-against-the-computer.md](../docs/reviews/29-the-tactical-game-against-the-computer.md).

**Not proven.** T30's manual check: play a game reading only the screen.

**Next:** `make wave` cuts the next ready row.

## Resuming after 2026-10-14 (wave 28)

**What landed.** T29: `make demo-search` is a board you can paint.
- Left-drag paints wall, mud or open ground (W, M, G), right-drag erases,
  the two dots drag, and - and = price the mud.
- Every change searches again, all four, from nothing. A goal walled off is
  "no route", with the region each search explored still on screen.
- B steps through four boards, drawn as text in `search_board.gd`: wall and
  mud, a perfect maze, an open field, and a trap for depth-first. Each
  carries its lesson as a sentence and a check. Once edited, the screen says
  whether the lesson still holds.

**The review's worst finding.** The mouse, which is what the task was for,
had no test. Four mutations to it survived. It is `pointer(event, cell)` now,
driven by constructed events, and a fast drag no longer leaves gaps. See
[docs/reviews/28-a-search-board-you-can-edit.md](../docs/reviews/28-a-search-board-you-can-edit.md).

**Not proven.** T29's manual check: somebody who has not read the code
builds a maze in under a minute and says why depth-first wandered.

**Next:** `make wave` cuts T30, the tactical game against the computer.

## Resuming after 2026-10-14 (wave 27)

**What landed.** T28: `make demo-tictactoe`, noughts and crosses against
MENACE, Donald Michie's 1961 matchbox machine.
- MENACE trains in Python with the standard library only:
  - 304 boxes, 1 + 12 + 108 + 183, with Michie's beads and rewards;
  - 5,000 games against a random player, then 5,000 against a perfect one;
  - four ages published in `godot/game/tictactoe/menace_beads.json`.
- The game only draws. Each empty square shows its beads and their chance,
  the panel numbers every bead, and M shows what perfect play makes of each
  square.
- Invariant 6 now covers beads:
  - N5 is a net for bead writes in GDScript;
  - N6 trains again and compares with the published file;
  - the store is read-only in the engine, which is the actual guarantee.
- `spec/vectors/menace/` carries the uniform draw itself, because the two
  languages' random generators differ.

**The criterion changed, by the owner's choice.** Michie's rules never stop
losing to a random player: they lock in a move that wins three in four over
one that wins every time. The tests hold the published seed against the
perfect player instead. Over ten seeds, the vs-perfect claim holds on nine;
on the tenth a box drains and MENACE resigns. `python3 -m
gameaikit.menace.report --seeds 10` prints the table, and the concept page
quotes it.

**The review's worst findings.**
- N5 missed the real bead store, which the engine's read-only store now
  closes.
- The new criterion had been measured on one seed.
- The panel's draw could not be checked against its own list.

All are fixed; see
[docs/reviews/27-tic-tac-toe-and-menace.md](../docs/reviews/27-tic-tac-toe-and-menace.md).

**Not proven.** T28's manual check: play the 10-game machine and then the
10,000-game one, and feel the difference.

**Next:** `make wave` cuts T29, a search board you can edit.

## Resuming after 2026-10-14 (wave 26)

**What landed.** T27: `make run` is checkers, red against the computer.
- `ai_adversarial` holds minimax and alpha-beta, after Russell & Norvig
  chapter 5. A root move that alpha-beta cut short is marked a bound
  ("≤ x"), and only when something below it was actually cut.
- `godot/game/checkers/` holds the English draughts rules with their source,
  the hand-written evaluation T32 will replace, and the scene.
- White draws every move it considered with its value, a pink arrow on the
  one it will play, and the line of play it expects. Space plays it; 1-6 set
  the depth.
- A multi-jump is played one hop per click, which is also how a person picks
  between two jumps to the same square.
- The old board is `make demo-skirmish`.

**The review's worst findings.** A king's capture back to its own square
locked the game, a bound read as "wins", and eleven of nineteen mutations
survived the suite. All are fixed and re-run; see
[docs/reviews/26-checkers-and-minimax.md](../docs/reviews/26-checkers-and-minimax.md).

**Left open, on purpose.**
- The search runs in the frame: depth 6 measured up to ~730 ms with kings.
- Wins are not depth-adjusted, and with a big lead white can shuffle into
  the 40-move draw. The status counts down to it, and the concept page
  calls it the horizon.

**Not proven.** T27's manual check, by somebody who knows checkers and has
not read the code.

**Next:** `make wave` cuts T28, tic-tac-toe with MENACE.

## Resuming after 2026-10-13 (tasks: games people already know)

**Why the plan changed.** The owner played `make run`, `make demo-search` and
`make play-tactical`. They could not tell what game each one was, or what
the AI was doing in it. They also found clicking pieces one step at a time,
and two people at one mouse, painful. That is the manual check doing its
job. The answer is to build every example on a game people already know,
against the computer, and to say the technique on screen.

**New tasks, in order:**
- T27: checkers with minimax and alpha-beta, as the new `make run`.
- T28: tic-tac-toe with MENACE.
- T29: a search board you can edit.
- T30: the tactical game against a rule-based computer, with Advance Wars
  style turns.
- T9: CC0 art for those games.
- T31: generate your own art with a local model, downloaded separately and
  fenced off from every lesson. Each user generates their own art, which
  git ignores; the repository keeps CC0 art as the default and a few
  generated examples.
- T32: a learned checkers evaluation, after Samuel.

**What is not lost.** The logistic-regression policy in today's `make run`
becomes `demo-skirmish` in T27. T30 makes blue on the tactical board a
controller chosen among several (rules, planner, learned), which is where
that policy can play once T26 gives it a real combat.

**Next:** `make wave` cuts T27.

## Resuming after 2026-10-13 (wave 25)

**The order changed.** T9 (art) was next, and it asks for five unit types
to be five silhouettes, but there were no unit types. The owner chose to do
T10 first. T9 now depends on T10, and `make wave` agrees.

**What landed.** T10, the tactical scenario, played with
`make play-tactical`:
- `ai_core` has `UnitType`, `Upgrade` and `ProductionOrder`, and
  `BoardState` holds funds, upgrades and a cost map per kind of mover.
- Five types in a counter cycle, a bolt tower, a watchtower, a workshop and
  a forge.
- A river with one bridge. Only the wader crosses water.
- The highlight shows everywhere a piece can walk this turn
  (`TacticalReach`).

It is not `demo-*`, because nothing in it decides yet. T11 gives one side to
the planner and renames it.

**Combat is not in it.** ADR 0008 says the dataset must be rebuilt from the
game's combat once it exists. That is T26, a new task, and T11 now depends
on it.

**The review's worst finding.** Out of funds, a build said the workshop had
no room. Three tests did not hold what they were named for: the cycle, the
"only" bridge, and what a wader pays. They do now. See
[docs/reviews/25-the-tactical-scenario.md](../docs/reviews/25-the-tactical-scenario.md).

**Not proven.** T10's manual check, by a person. The play review passed it
for terrain and said type feel waits on T26. The fixes were not re-reviewed.

## Resuming after 2026-10-13 (wave 24)

**What landed.** T8, the five measured defects on the board:
- 48 px tiles, and the board centred in the window the project asks for;
- a palette that separates by brightness as well as hue, and grid lines;
- the cost written on any dear cell;
- the reachable highlight drawn *over* the terrain;
- the status beside the board, saying what is in hand and what to do.

On top of that, column and row numbers, so every `(column, row)` in a
refusal can be found. The search demo shows cells expanded and route cost
for all four algorithms at once.

**Measured on the way.** A `TileMapLayer` paints its tiles over its own
`_draw`, and the headless root viewport is 100x100. Both are in
[docs/godot/drawing-over-tiles.md](../docs/godot/drawing-over-tiles.md),
with how to take a screenshot when a display exists.

**The review's worst finding.** On blue's turn the board ringed one unit
while the status named another. Blue now has nothing in hand. The overlay
could also be deleted with every test green; it is data now, and held. See
[docs/reviews/24-a-board-you-can-read.md](../docs/reviews/24-a-board-you-can-read.md).

**Left for later, on purpose.**
- "attacks" with no combat model belongs to T10.
- The typed positions of the search and stealth scenes, and stealth's 32 px
  guard markers, belong to T24.

**Not proven.** T8's manual check: hand `make run` and `make demo-search` to
somebody who has not read the code. The fixes were not re-reviewed.

## Resuming after 2026-10-13 (wave 23)

**What landed.** T21. Invariant 13 has a gate in two halves:
- `make lint-demos` holds the structure: a target that opens a window, a
  legend, and `step_decision()` and `decision_overlay()`.
- `make test-demo-overlays` steps every example headless. It fails on an
  engine error, on an overlay that does not change, on an empty field or a
  missing required field, and on a legend that says nothing or runs off the
  screen.

Every rule in both halves first rejects a planted case. The convention is in
[docs/godot/examples.md](../docs/godot/examples.md).

**The board itself failed the task.** Blue decided and played its whole
turn on one press, so the decision was never on screen before it happened.
It now plays one decision per press, drawn first. The gate had passed it,
because it accepted a full overlay without asking whether it ever changed.
See [docs/reviews/23-every-example-can-be-watched.md](../docs/reviews/23-every-example-can-be-watched.md).

**For the owner.** `CLAUDE.md`'s invariant table still says invariant 13 has
no gate. That file is yours, so it was left alone.

**Not proven.** Whether a person can read each example is the manual check.
The fixes were not re-reviewed.

## Resuming after 2026-10-13 (wave 22)

**What landed.** T14.
- `godot/addons/ai_perception/` sees, hears and keeps an influence map. Its
  line of sight is Bresenham's, drawn from one fixed end, which makes it
  symmetric. It does not slip between walls meeting at a corner, and trees
  block sight as well as costing movement.
- `godot/game/stealth/` puts it to work. Suspicion is a fuzzy controller on
  `ai_fuzzy` that never falls while the player is in sight. Guards have
  three states with hysteresis, and walk A* routes around each other.
- `make demo-stealth` draws each guard's cone, its suspicion bar chasing the
  controller's target, its next steps and where it thinks you are. It also
  writes out every input and term.
- The acceptance, `make test-perception-properties`, checks four properties
  over 300 maps, plus the line against geometry.

**Playing it found what mutating could not.** A guard that reached the
player turned its back. The cone on screen was not the cone that decided.
Two guards head on spun forever. All three were legal moves and wrong
behaviour, and each now has a test. **A reviewer driving the game turn by
turn is worth asking for again.** See
[docs/reviews/22-the-stealth-scenario.md](../docs/reviews/22-the-stealth-scenario.md).

**Not proven.** Whether the suspicion bar reads as a decision is the manual
check, and a person's. The default room is honest but not hard. The fixes
were not re-reviewed by a fresh context.

**Next.** `make wave` picks the next ready row. Two reviewers in one checkout
interfered with each other this wave, so give each its own worktree.

## Resuming after 2026-10-13 (wave 21)

**What landed.** T13: `godot/addons/ai_fuzzy/` holds membership (one
trapezoid, of which a triangle and a shoulder are special cases), a rule base
(AND is min, OR is max, and each term takes its strongest rule), and the
centroid, sampled at points the controller itself declares.
`python/gameaikit/fuzzy/` holds the same three steps, a reader for the old
library's text format, and `python -m gameaikit.fuzzy.plot`, which draws a
controller's curve in the terminal for the manual check.
`spec/vectors/fuzzy/` holds three vectors, computed in exact fractions by a
script that imports nothing from the repository. They include the case T13
asks for: two overlapping rules land strictly between what each gives alone.

**The task's premise was wrong, and the code was written rather than
ported.** The "Python library" is C#, and the class doing fuzzification,
inference and defuzzification is not in its repository. ADR 0011 records
what carried over (the shapes, AND/OR rules, the centroid, the `FLC.txt`
format) and what did not. Review then found that the ADR itself had three
claims about the old code wrong. **A description of someone else's code
needs checking against the code**, the same lesson wave 20 learned about
sources.

**Twenty-two review findings**, in
[docs/reviews/21-ai-fuzzy.md](../docs/reviews/21-ai-fuzzy.md). The worst:
- a malformed vector made the runner skip the strictly-between claim and
  still exit 0;
- GDScript answered a NaN input with a confident 50.0, where Python divided
  by zero.

Both are fixed. Every survivor both reviewers reported was re-run as a
mutation against its fix: 19 in GDScript, 24 in Python. **The fixes were
not reviewed by a fresh context.**

**Not proven.** The manual check is a person's: plot the guard and look at
the curve (the command is in the review record). A slope test holds the half
a command can. Nothing is profiled.

**Still open, and carried forward.** Everything wave 20 listed, including the
sequencing question. `make wave` will pick the next ready row; T14, the
stealth scenario, is the one that consumes `ai_fuzzy`, and T21 (every
example can be watched) is still listed after it.

Read the task file `make wave` names, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-13 (wave 20)

**What landed.** A mini wave of research and planning, with no code.
[How strategy games plan](../docs/concepts/planning-in-strategy-games.md)
gathers twenty-four sources, shipped games and research, with every
quotation checked against its text. ADR 0010 is **proposed**: the RTS enemy
plans at the strategic layer only, with a heuristic, a budget per call and a
cadence, over a priority-queue economy. T11 and T20 are to measure it. New
tasks: **T24**, one window that opens every example, with a card naming each
one's techniques, and an exported executable; and **T25**, a league of one team
per technique, scored separately on strength and on how human it plays,
with a live cost and efficiency meter. T20 now opens with **the minimum RTS**,
built backwards from what each AI needs to decide, and T19 with the
simulation the league depends on.

**The research corrected its own first reading.** The page first said
strategy games "plan only at the top". Killzone 3's bots and squads plan with
HTN, and F.E.A.R. planned per soldier. What the sources support is that
nobody plans the whole game in one search. Planning at the top only is this
kit's choice for an RTS, and is now said as one. **A summary of sources
needs reviewing against the sources as much as code does against its
tests.**

**The answer to "PDDL or STRIPS, which is faster" is that the question is
wrong.** PDDL is the language and STRIPS the model it describes. Speed comes
from which layer plans, over how small a problem, with what search, and how
often.

**Not proven.** Everything in ADR 0010 is a reading of other people's games
until T11's benchmark and T20's match produce numbers. The third round of
this wave's fixes was not reviewed again.

**Still open, and carried forward.** Everything wave 19 listed. Also the
sequencing question, now bigger: `make wave` picks **T13**, while T21 says it
comes before T8, and T24 (which needs T21) and T25 are where the owner's
latest requests live. If they should come sooner, move their rows up.

Read the task file `make wave` names, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-13 (wave 19)

**What landed.** T7, and with it milestone 1. Planning and learning have a
concept page at tier 1 and a Godot page at tier 2 each, search has both too,
and `check_tiers.py` sees all three lessons now and goes red when a tier-1 page
is removed. Every snippet on the Godot pages was run on 4.7.2 and shows what
it printed. ADRs 0006-0009 record four decisions that had lived only in task
files and comments. The README says which addons `make run` uses, and no
longer lists `ai_llm`, which has no code and no task, as if it shipped.
`make release` builds one zip per addon and a wheel written by hand, from
HEAD, byte-for-byte reproducible. `check_license.py` opens every one of them
and compares the attribution with what HEAD holds.

**The release took three review rounds, and each found that the last fix had
been tested in one place.** The first draft shipped the working tree: it
listed tracked paths and read the bytes off disk. The fix's self-test planted
strays in one addon and opened one zip, so reading the wheel or the
attribution off disk still passed it. The content check written next built its
expectation with the build's own helpers, so a defect one function down agreed
with itself. **A check is only as independent as the code it does not
share.** It reads HEAD through `git archive` now. Every mutation a reviewer
reported surviving was re-run against its fix, in sweeps of 26, 22 and 10
mutations that also cover each new rule. Two survive, and neither is a hole. See
[the review](../docs/reviews/19-close-the-slice.md).

**The third round's fixes were not reviewed by a fourth context.** They were
checked by planting each mutation the reviewer described and watching it go
red. Worth a fresh pair of eyes before the release is used for real.

**A header two reviews had passed was teaching the wrong cause.** `dijkstra.gd`
said it never improves a cell because its frontier is a linear scan, and that
a binary heap would bring the improvements back. The real reason is that a
cost belongs to the cell *entered*. A heap on these costs makes 0
improvements over 300 boards, and 1674 once the cost is charged per edge.
`docs/concepts/cost_models.py` prints both. The wave 08 section below still
carries the old claim, as a dated record should.

**Two numbers had no command behind them**, and one moved when it got one:
1533 became 1674 because the draw order changed. **A sentence copied from a
docstring is only as true as the docstring.** The terrain rule went from
`combat.py`'s docstring, which contradicts its own code, into a concept page
and an ADR.

**Not proven.** The manual check is a person's: hand the README to someone who
has never opened Godot, and record the game and the search demo. No command
can, because `--headless` rasterises nothing, and the README has a marked
place for both recordings.

**Still open, and carried forward.** The eleven over-long addon headers from
wave 07 still wait on the owner. The `doc-meta` blocks in
`spec/vectors/*/README.md` still declare a `half_life` the docs gate does not
know. Nothing enforces a line width, and `check_readability.py` does not
measure `scripts/` at all, where `check_license.py`'s `self_test` is over 300
lines. The search and planning vector runners still use the noisy JSON parser.
The Godot pages cite `/en/stable/` docs rather than the pinned version's, as
every page here does.

**A sequencing question for the owner.** `make wave` now picks **T13**,
because it takes the first ready row in the table and T21 is listed last in
milestone 2, although its note says it comes **before T8**. If T21 should come
next, move its row up. This session did not reorder the plan.

Read the task file `make wave` names, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-13 (wave 18)

**What landed.** T6: `godot/addons/ai_learning/` loads the weights Python
published and does nothing but infer. `LearnedModel` is `w·x + b` and a
sigmoid; `ModelFile` refuses a malformed file in one sentence with a code and
hands back *no* models rather than half of one; `BoardFeatures` reads the four
combat and four capture features off a live `BoardState`; `LearnedPolicy`
compares one probability against one threshold and takes the lower of two
predicted capture times. Blue in `make run` is played by it and says on screen
what it decided and the number it decided on. `check_no_training.py` gives
invariant 6 the gate it has never had, and `spec/vectors/learning/` holds the
two languages to the same rows and the same arithmetic.

**Two of the four combat features cannot be computed from a board.** How near
counts as near, and what a unit with no living friends reports -- and the
second is the *training* board's width, so a game helpfully reporting its own
would say "far" where the data said "nobody is coming". They are published in
`weights.json` now, with the range of terrain the data covered, and the game
reads them rather than keeping a copy. A number two languages must agree on,
living in two files, is a number that will one day differ.

**The bug worth remembering is the one no vector could have caught.**
`_nearest_friend` seeded its search with the sentinel instead of falling back
on it, so "I am alone" and "my nearest friend is seventeen away" were the same
number. The two board-carrying vectors are 5x4 and 6x4 -- longest distance 8,
sentinel 15 -- and the board `make run` ships is 12x8, where it reaches 18.
**A conformance vector only tests the range its board can reach.** There is a
fourth vector now, on a board twenty wide, and it goes red against the old
code.

**The sentinel is clean by luck, not by design.** Over the 2937 training rows
the real distances run 1 to 11 and none reaches 15 -- but the simulator's
geometry permits 16. Worth knowing before T18 leans on that feature.

**Twenty-one rules were deletable with every gate green**, found by two
reviews deleting them one at a time: the whole of `_affordable` (the only
thing making every returned move legal -- no test had ever produced a route
the unit could not pay for), four tie-breaks and boundaries, four board rules
in the vector loader, two of `ModelFile`'s refusals, three of the four ways
the gate recognises a file being written, eight of its ten forbidden words,
and its vendored-code exclusion.

Each has a case now, and **each case was then run against the mutation that
motivated it** rather than assumed to work. That caught three failures in the
fixes themselves: one case was hidden behind an earlier failure in the same
suite (the gdUnit4 trap `CLAUDE.md` warns about); two were passing through a
*different* rule, because eleven board rules all answer the code `V7` and
`contains("V7")` cannot tell them apart; and the planted case for
`open_encrypted` contained `FileAccess.WRITE`, so the alternative next door
was catching it.

**A planted case written as a loop over the rule list cannot notice the list
shrinking.** Planting one case per forbidden word by iterating the vocabulary
proves every word fires and goes green the moment a word is deleted, because
the loop shrinks with it. Both are needed: the literal list catches the
deletion, the loop catches an entry that does not work -- and the loop earned
its place immediately, catching a planted `gradient_value` that
`\bgradient\b` never matched.

**T6's headline acceptance command proves less than it reads like.** The three
decision scenarios stayed green under all five mutations of the feature
extraction. They are about nerve; the arithmetic is the vectors' job, and the
file says so now.

**The fixes needed reviewing as much as the code did.** Both reviewers were
sent back over the repairs, and found four more defects in them -- including a
rule whose three planted cases all reached the helper and none reached the
*call site*, so deleting the call left the self-test green. Seven of this
wave's fixes were themselves wrong on first writing. Budget for that.

**Thirty-four lines of real gradient descent got past the new gate**, inside
the inference addon, by calling its accumulator `_numbers`. The docstring
admits that hole and is right to refuse a longer list of verbs, which would
fire on good code -- but the one directory that is read-only by construction
can be held to a stricter rule, so any compound arithmetic assignment into an
indexed value is now a finding **there and nowhere else**.

**A measurement that belongs in anyone's Godot notes:** the static
`JSON.parse_string` prints an engine error of its own before returning null,
where `JSON.new().parse()` returns the code quietly and hands over the
message. Found because a *passing* test printed a stack trace. Written up in
[docs/godot/reading-json-in-godot.md](../docs/godot/reading-json-in-godot.md).

**Not proven.** The manual check is a person's job: whether the retreat reads
as a decision rather than a bug, and whether the overlay makes the probability
legible. Nothing is profiled. `enemy_units` has no three-faction meaning in
either language -- documented and pinned, not solved.

**Still open, and carried forward.** The eleven over-long addon headers from
wave 07 still wait on the owner -- this wave added four and then cut them, so
the count is unchanged. Planning and learning still have no pages under
`docs/`, so `check_tiers.py` sees neither lesson until T7. The `doc-meta`
blocks in `spec/vectors/*/README.md` still declare a `half_life` the docs gate
does not know. Nothing enforces a line width. And the search and planning
vector runners still use the noisy JSON parser.

**Next: T7** -- close the slice: the docs pages that make `check_tiers.py` see
planning and learning at tier 1, the ADRs, and `make release`. It is the last
task in milestone 1.

Read tasks/T7-close-the-slice.md next, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-13 (wave 15)

**What landed.** T5: `python/gameaikit/dataset/` simulates games with a fixed
policy and writes down every fight and every captured node -- 1500 games give
2937 combats and 1029 captures -- and `python/gameaikit/training/` fits a
logistic regression to *will this attack work* and a linear one to *how long
will this node take*, by gradient descent, standard library only. `make train`
writes `dist/weights.json` and a readable `weights.txt`; `make test-models`
runs the five acceptance commands and is part of `make check`.

**Combat is dice rather than a formula, on purpose.** If the chance of winning
were a logistic function of the features, a logistic regression would recover
the line somebody wrote three files away and the lesson would be circular. The
model is right about 87.8% of held-back fights against 69.0% for always saying
the attacker loses, and every weight has the sign the simulator's rules imply.

**The two models share one update rule.** Log loss through a sigmoid and
squared error through a linear prediction have the same gradient with respect
to the weights -- exactly for the first, up to a factor of two for the second,
which disappears into the learning rate. That is why there is one `fit` and not
two, and the factor is now written down because the file exists to be rederived.

**The majority baseline was flattering the model by fifteen points.** The
features are small integers, so 2937 rows cover 976 distinct vectors and 83% of
held-back rows have an **exact twin** among the rows trained on. A lookup table
of training rows scores 0.8177 where the majority class scores 0.6900 and the
model scores 0.8780. The report publishes all three now. Four weights cannot
memorise 976 answers so this score is honest -- but **T18's behaviour cloning
has capacity, and must be read against the table rather than the majority**.

**The control does not catch what T5 said it catches.** The task file claimed a
shuffled-label run catches a leak in the features. Both leaks were planted and
measured: the label appended to every row scores 1.0000 honestly and exactly
the baseline shuffled, and a contaminated split scores 0.8794 honestly and
exactly the baseline shuffled. The control **passes both**, because shuffling
destroys the leaked relationship along with the honest ones. It is still worth
running -- it tests that the score is measured against labels the fitting never
saw -- and the leaks themselves now need `--assert-no-leak`, which asks the two
questions directly.

**Thirteen findings from two reviews**, in
[docs/reviews/15-dataset-and-training.md](../docs/reviews/15-dataset-and-training.md).
The two worst were in the two places this wave is about: nothing had ever built
a board and looked at the feature row it produced, so eight mutations changed
the data in silence; and the leak check's "suspiciously perfect" rule was gated
on the model being logistic, so planting the label into the *capture* features
gave a model wrong by 0.0000 turns and nothing objected. Both are pinned now,
with twenty-two mutations run red across the two halves.

**Two numbers that were about the measuring rather than the thing.** A
published 0.8808 came from a 500-step probe where the pipeline fits 2000 and
gives 0.8794. And an earlier convergence measurement was five runs of the same
step count, because `steps: int = STEPS` in a signature captures the constant at
import. Both corrected; both worth remembering before quoting a number from a
scratch script.

**Not proven.** The manual check is still a person's job: whether the weight
dump explains, from those numbers alone, what the model learned. Nothing is
profiled. The "no friends left" sentinel on a fifth of combat rows is
documented rather than fixed -- capping it instead scores 0.885 against 0.878,
five rows in seven hundred, and every alternative is arbitrary in its own way.

**Still open, and carried forward.** The eleven over-long addon headers from
wave 07 still wait on the owner. Planning and learning have no pages under
`docs/`, so `check_tiers.py` sees neither lesson until T7. The `doc-meta`
blocks in `spec/vectors/*/README.md` still declare a `half_life` the docs gate
does not know. And a new one: **nothing enforces a line width**, the tree
breaks 88 columns in both directions, and mechanical wrapping made it worse --
either it becomes a rule with a gate or it stops being raised in review.

**A trap worth adding to CLAUDE.md, which is the owner's file:** mutating a
Python file in place can alias a `.pyc` written in the same second and **fake a
green**. Run mutation sweeps with `PYTHONDONTWRITEBYTECODE=1` or in a clone.

**Next: T6** -- `ai_learning`: the addon loads `weights.json` and does nothing
but infer, the decision gets wired into the game's AI turn, and
`check_no_training.py` finally gives invariant 6 the gate it has never had. The
conformance vector there is the one that matters: the GDScript inference and
the Python training have to agree on the same arithmetic, and the weights are
published rounded to six decimals so that they can.

Read tasks/T6-ai-learning-and-the-decision.md next, then: make check, write the
review record, make wave-merge.

## Resuming after 2026-10-12 (wave 14)

**What landed.** T4: `ai_planning` -- `WorldState`, `StripsAction`,
`StripsPlanner` and `PlanResult`, with the game's domain written out in full in
`game_domain.gd`. Forward state-space search over worlds rather than cells: a
queue, so the first plan found has the fewest actions; a visited set, because
several routes reach the same world; and a budget, so "no plan" can say whether
the **space** was exhausted or the **search** was. `python/gameaikit/pddl/`
reads a domain somebody else wrote, in propositional STRIPS only. Three vectors
in `spec/vectors/planning/`, each a JSON file beside two PDDL files: GDScript
plans over the JSON, Python asserts the PDDL says the same thing, and the
runner replays every plan rather than reading the planner's own `solved`.

**The domain is the lesson.** The barracks and the unit are paid for out of one
bank, so the node has to be mined twice: eight steps, 14 states. A reactive rule
that trains a unit whenever it can afford one never builds the barracks and
never attacks. Checked against an exhaustive enumeration written from the JSON
with no repo code in it -- 8 is the shortest, and the same sequence.

**The review found the claim the whole addon rests on was pinned by nothing.**
Turning the frontier into a stack -- `pop_front` to `pop_back`, one word -- left
118 unit tests, 400 property trials and 3 conformance vectors green. A stack
returns four actions where three exist, so it is a wrong answer and not an
equivalent mutant. The test named for the shortest-plan claim forked at the
*start*, where the goal is generated during the first expansion whichever end
of the frontier is read.

**And the property written to fix that could not see it either.** The first
generator -- eight predicates over six actions -- produced chains: 66 of 400
solvable and no two routes of different lengths to the same world. Six
predicates over twelve actions forks: 218 solvable, 156 plans measured against
an exhaustive search that shares no code with the planner, 19 of them failing
under a stack. **A property is only as good as the inputs that reach it**, and
that is the sentence this wave cost most to learn.

**Fifteen findings in all**, in
[docs/reviews/14-ai-planning.md](../docs/reviews/14-ai-planning.md). Five more
in the PDDL reader that it accepted after promising to refuse: a section written
twice silently kept the second, `:effect (and)` walked past the refusal written
for an action that does nothing, a bare word was read as a predicate, a
duplicate action name was accepted where the cross-language comparison is keyed
by name, and `:parameters` could be missing entirely. Nine rules in
`PlanningVector` and seven in the reader had **no planted case at all** --
deleting them left every gate green, under headers claiming the opposite.

**Two things T3 left behind, found by the re-read the wave 08 note asked for.**
The search conformance runner never checked that a path **ends at the goal** --
every rule it had was about the steps, so a legal stroll to the wrong cell
conformed, in work two reviews had passed. And `check_readability.py` matched
neither of its patterns against `static func`, so it had been reading
`search_vector.gd` -- a file that is nothing but static functions -- as empty.
Fixing the pattern produced no cascade: the existing tree was clean, and the
only two findings were in this wave's own new files.

**Not proven.** T4's manual check is still a person's job: whether someone who
has never seen STRIPS can read `game_domain.gd` and tell what the AI is
reasoning about. Nothing has been profiled; `WorldState.key()` sorts and joins
on every generated state, which is the obvious cost and has not been measured
against anything.

**Still open, and carried forward.** The eleven over-long addon headers from the
wave 07 review are still waiting on the owner. Planning has no page under
`docs/`, so `check_tiers.py` cannot see the lesson at either tier until T7. The
`doc-meta` blocks in `spec/vectors/*/README.md` declare a `half_life` the docs
gate does not know, and no gate looks outside `docs/` to say so.

**Next: T5** -- the dataset and the training, which is the first task whose
output is a *file* rather than code: Python trains and emits weights, GDScript
only infers, and `check_no_training.py` is the gate invariant 6 still does not
have.

Read tasks/T5-dataset-and-training.md next, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-12 (wave 8)

**What landed.** T3: `ai_search` with breadth-first, depth-first, Dijkstra and
A\* over `GridGraph`, each implementing `Pathfinder`. A `SearchResult` that
carries what was expanded and what was still waiting. Three conformance vectors
in `spec/vectors/search/` with a runner, a property check over 300 random
boards, and a demo that draws the expansion in the order it happened. `make
check` is green and now includes `make test-vectors` and
`make test-search-properties`, both wired into CI as well.

Also here, because T3 could not be trusted without it: the fixes from **two**
independent reviews of `ai_core`, which was merged in wave 7 with a review that
arrived truncated. Mixing them into this branch rather than cutting a separate
wave is a deliberate exception -- A\* is wrong on a board with a negative cost,
and that board was buildable.

**The property check found a defect instead of confirming the code.** The claim
T3 asks for is that A\* expands no more cells than Dijkstra. Over 300 random
boards the costs agreed everywhere -- the heuristic is admissible -- and A\*
expanded **more** on 14 of them, which is the reverse of the reason it exists.
Neither costed search had a closed set, so a cell improved after being queued
was taken off the frontier twice and `expanded` was counting pops rather than
cells. That is also what the demo would have drawn. With the guard: 0 of 300.

**Three things the reviews found that were defects rather than gaps.** A
negative terrain cost was legal and *refunded* movement -- a unit with three
points finished a move with eight -- and it broke the one guarantee A\* offers,
since Manhattan distance is admissible exactly because no step costs less than
one. A cost is now `BLOCKED` or at least one, so the condition `astar.gd`
carried in prose is a rule. Two units sharing an id walked through each other
and **stacked on one cell**, because the occupancy rule compared ids rather than
identity. And `end_turn(0)` was a modulo-by-zero engine error returning null, on
the one type whose `apply` argues against exactly that.

**A test whose expected value is also the broken value measures nothing.** Two
of this session's own tests were that: one asserted a copy keeps whose turn it
is while ending on faction 0, so a copy hardcoding 0 passed; one asserted a
closed set on a board where no cell is ever re-queued. Both were found by
mutation and both are rewritten -- the second against a 4x4 board that was
*searched for* rather than invented.

**One mutation is recorded rather than closed.** Deleting the lower bound in
`GridGraph.contains` does not fail the suite, it **hangs** it: `neighbours`
hands back cells below the board and the searches walk downwards forever. On CI
that reads as a slow job rather than a broken one. The sentence is in the doc
comment of the rule that prevents it.

**Not proven.** The demo's legibility is still a person's job -- five tests hold
that it loads, that stepping replays rather than re-runs, and that its board
actually makes the four disagree, which is the demo's own premise. Nothing has
been profiled: `_cheapest` and the closed set are both linear scans, documented
as such, and the benchmark that would justify a heap has not been run because
the answer to needing one is `AStarGrid2D`.

**What its own review then found, after all of that.** Twelve findings, in
[docs/reviews/08-ai-search.md](../docs/reviews/08-ai-search.md), and the first
is the one worth reading: `dijkstra.gd` carried the textbook improvement branch
and its header called that branch "the line worth reading them for". Measured
with a counter, it fires **0 times in 250 boards** -- against 165 for A\* on the
same boards -- because `_cheapest` reads `g` as it is now, so the cell taken off
is already final. The duplicate guard beside it was dead for the same reason and
its comment was a byte-for-byte copy of A\*'s, citing A\*'s measurement as its
own. Both are gone and the header says what is actually true, including that a
binary heap keyed at insertion brings both straight back.

Next to it, a retraction: `astar.gd` claimed a stale `f` "would send the search
the wrong way". Freezing `f` across 241 boards changed neither the cost nor the
expansion count, not once. The line stays, for a different and honest reason.

Three more worth knowing before touching this code: **no search validated its
start** (`from = (-1, 2)` came back `reached`, with a path walking in from
nowhere, and the vector runner accepted it because every *step* was legal); the
runner was **a gate with no planted case for any of its rules**, which
`lint-selftests` cannot help with because it only ever looks inside `scripts/`
and the runner is GDScript; and the demo **hid the thing it exists to show** --
the
expansion rectangles buried the mud band exactly when the picture completed.

**Next: T4** -- `ai_planning`: STRIPS, and a PDDL reader in Python. It is the
first task with a Python half, so `make test-python` stops being a placeholder,
and the first addon that must not reach into `ai_search` -- the gate for that
has been inspecting a real addon only since wave 7.

**Start T4 by reviewing T3.** Three reviews in this project have now each found
real defects in work the previous one had passed over or never reached. That is
the argument for the rule, not against it.

**Milestones 2 and 3 are written and queued**, thirteen task files from a
board you can read through to an RTS. Three decisions are already taken and are
in the task files rather than left to be rediscovered: the strategy game is
**turn-based first**, because `BoardState.apply` copies the units into a new
state and that is right for search and wrong for two hundred units at sixty
frames a second; art is **CC0 now and generated later**, because hours spent
fighting a diffusion model are hours not spent on the AI; and the **RTS is
last**, after all three games.

**T8 is first, and it exists because the manual check worked.** The owner ran
`make run` and could not tell what he was looking at. That is T2's
`## Manual check` doing exactly what it is for, and the task file carries the
five measured reasons rather than "make it nicer".

**One finding is open and waiting on the owner**, recorded at the end of
[the wave 07 review](../docs/reviews/07-ai-core-and-the-board.md): eleven of the
twelve addon files have headers longer than the 5-10 lines `CLAUDE.md` asks
for, several by two or three times, and the longest are long because they carry
measurements this project asked for. Either the headers get cut or the rule
gets rewritten, and a session failing a rule should not be the one to quietly
change it.

---

## Resuming after 2026-10-12 (wave 7)

**What landed.** T2: `ai_core` and a board you can play with a mouse.
`GridGraph`, `Unit`, `Move` and `BoardState` under
`godot/addons/ai_core/`, two interfaces (`Pathfinder`, `DecisionPolicy`) that
say what an implementation must guarantee, a `TileMapLayer` view under
`godot/game/`, and 21 tests. `make check` is green, engine included.

**The gates stopped inspecting nothing.** Before this wave `check_addon_deps.py`
and `check_renderer.py` printed that they had found no addons and no scenes;
both now read real files and say nothing, which is the first time either has
actually held its invariant. The licence gate fired the moment `ai_core`
appeared, exactly as designed: an addon that would ship without LICENSE and
NOTICE. Both are in the folder now, as copies rather than symlinks, because the
promise is that you copy the folder and it works.

**Three design decisions worth knowing before T3.**

- **A `Move` carries its own path.** The board rules on whether a walk is
  legal; it never works one out. That is what lets `ai_core` hold no
  algorithms: A\*, a planner and a human clicking a tile all produce the same
  type. `ai_search` fills in the route and nothing else changes.
- **`apply` returns a new state**, and `why_refused` returns a sentence rather
  than a code. A search tries illegal moves constantly, so refusing must be
  cheap and must not fill the log with engine errors.
- **The path excludes the starting cell.** Cost is paid on entering a cell. The
  first version included the start and every cost calculation grew an "except
  the first one" clause, which is where off-by-one bugs live.

**Measured, not assumed: a failing gdUnit4 suite hides the tests after it.** A
suite of ten whose third test fails reports three cases and stops; the other
seven are not run and are not counted as skipped. Found by hitting it three
times while writing the board tests. It is in `docs/godot/addon-anatomy.md`,
because a red run that lists one defect is not a red run that lists them all.

**Two of this wave's own tests were wrong in the same way**, and the board
caught them: both walked a unit straight through the square the *other* unit was
standing on, so they passed or failed for a reason that had nothing to do with
what they claimed to test. The movement-points test now turns north, and the
terrain test rounds the top of the board.

**What the review changed, and what it could not.** A fresh context found three
things, the worst of them in the interfaces: they claimed GDScript has no
`abstract` keyword and used `push_error` with a default return instead. It has
`@abstract`, enforced at load time -- measured twice -- and the defaults those
files returned were values their own contracts define as legitimate answers, so
a forgotten override looked exactly like an implementation that had decided to
do nothing. `ai_search` is the next task and the first caller. See
[the review](../docs/reviews/07-ai-core-and-the-board.md) for the other two and
for the five this session found afterwards.

**That review is incomplete and the record says so.** The reviewer's report was
truncated in transport partway through its third finding, and three requests for
the rest went unanswered. It said 13 of its 35 mutations survived; which 13 was
in the part that was lost. This wave therefore merges knowing a context that did
not write the code found things nobody has read. The 21-mutation sweep run
afterwards does not replace it: it was written by the session that wrote the
code, which is the symmetry invariant 12 exists to break.

**Not proven.** Nothing has pathfound anything: the scene moves a unit one cell
per click, which is honest -- a route is a search and the search is T3. The view
is checked by four tests for the half that is mechanical (the tile set builds,
a cost chooses a tile, a repaint forgets the old board); whether the board is
*legible* is still the manual check in T2 and still needs a person.

**Next: T3** -- `ai_search`: A\*, BFS, DFS and Dijkstra over `GridGraph`,
implementing `Pathfinder`. It is the first addon that must not depend on
another, so `check_addon_deps.py` gets its first real question, and the click
that moves one cell becomes a click that moves along a route. Three things it
needs that do not exist yet: a `make test-vectors` target (and therefore a CI
step, or `check_workflow.py` refuses it), `godot/demos/search/`, and
`godot/test/ai_search/search_properties.gd`, which T3's acceptance runs directly with
`-s` rather than through gdUnit4.

**Start T3 by reviewing T2.** Not as a formality: the review that should have
covered it is missing its tail, and `ai_core` is what every later lesson is
built on.

---

## Resuming after 2026-10-12 (wave 6)

**What landed.** The last four gates and T1's close (`check_addon_deps.py`,
`check_tiers.py`, `check_links.py`, `check_workflow.py`), two rounds of fixes,
ADR 0005, and the review of all of it in
[docs/reviews/06-the-last-gates.md](../docs/reviews/06-the-last-gates.md). Nine
confirmed findings, all fixed on the branch. `make check` is green, engine
included.

**The session that wrote this wave ended before it could finish**, and what it
left behind was enough to resume from: the branch, the task files, and a last
commit message that named the open decision instead of leaving it to be
rediscovered. That is the resuming log doing its job, and it is worth saying
once -- the cost of writing the paragraph was far below the cost of the session
that would have had to reconstruct it.

**Wave 5 has no section here**, and that is not an omission being hidden: its
record went to `docs/reviews/05-the-wave-flow.md` when the review flow landed,
and nobody wrote the STATUS entry. The reviews directory is now where a wave's
findings live; this log is for what the next session needs to pick up.

**The gate for invariant 10 was violating invariant 10.** Three of the nine
findings are that, in three places: it exempted its own file from its own scan,
so the one spot where a match gets quoted while being documented was the one
spot nothing watched; the same quote had reached two commit messages, which is
what turned `make check` red; and its line-break planted case never reached the
rule it was filed under. The two unmerged commits were rebuilt to remove the
term from the message *and* the file content, and the backup branch was deleted
-- a ref holding the old blobs is the term still being in the repository.

**A question about Godot was settled by measuring it.** `check_addon_deps.py`
only knew the `res://addons/other/` spelling of a cross-addon dependency. On the
pinned 4.7.2, `preload("../ai_b/x.gd")` from inside `addons/ai_a/` parses,
resolves and runs. The gate catches both now, and the measurement is in
`docs/godot/addon-anatomy.md` with the engine version, where the six-month
half-life rule can reach it.

**Still open, and it is the owner's call, not a defect.** Rebuilding those two
commits left the old objects unreachable but still in `.git`. `git gc
--prune=now` removes them; this session did not have permission to run it.

**Not proven.** Four of the gates have still never seen the thing they are
about: there are no addons, no scenes and no lessons above tier 1, and three of
them say so on every run rather than passing in silence. The only thing standing
behind this wave's fixes is a mutation sweep written by the same session that
wrote the fixes.

**Next: T2** -- `ai_core` and the board. The first real GDScript in the
repository, and the first time `check_readability.py` and `check_addon_deps.py`
look at something instead of printing that they found nothing.

---

## Resuming after 2026-10-12 (wave 4)

**What landed.** `check_acceptance.py` and `check_status.py`, and the eight task
files T0–T7 they check. `make check` runs ten gate self-tests plus both suites,
green. T0 and T1 were written retroactively rather than excused as bootstrap
rows: their Acceptance blocks record the commands that were actually run,
including the two negative controls.

**The acceptance gate caught two bugs in itself, and then one in me.**

1. Its first non-terminating rule used a lookahead for `--headless` after the
   word `godot`. In `--path godot` the word appears twice, and the second
   occurrence has no `--headless` after it, so a correct criterion was reported
   as broken. Replaced with a per-line check that only matches Godot in command
   position, which is also easier to read.
2. Its "the assertion sits in the comment" rule required a pipe before `grep`,
   so the same mistake written without a pipe passed. Broadened.
3. Then it rejected this repository's own T3, because the Acceptance prose used
   the word "plausible". That was the rule working: Acceptance prose is exactly
   where a human verdict hides. The sentence was rewritten, not the rule.

**Two dangling references, deliberately.** T2's acceptance calls
`check_addon_deps.py` and T7's calls `check_tiers.py` and `scripts/release.py`.
None exists yet. They are named now so that writing them is part of finishing
T1, rather than something remembered later; running those tasks' acceptance
today fails on a missing file, which is the correct state for a `todo` task.

**Next, to finish T1:** `check_addon_deps.py` (invariant 2: no addon imports
another), `check_tiers.py` (invariant 5: no lesson above tier 1), then
`check_links.py` and `check_workflow.py` ported from `desk-panel`,
`CONTRIBUTING.md`, and `.github/workflows/ci.yml` running the same strings the
Makefile does. Then T2, which is the first real GDScript.

Correction to the line that was here: it predicted the link gate would flag
`github.com/boscocp/game-ai-kit`. It does not, and the prediction was wrong --
that URL appears only in `NOTICE`, which is not markdown, and inside backticks
in this file. There is no markdown link to it, so there is nothing for the gate
to follow. No exception is needed.

---

## Resuming after 2026-10-12 (wave 3)

**What landed.** Three gates: `check_readability.py` (invariant 1, mechanical
half), `check_doc_freshness.py` (the three half-life layers), and
`check_no_employer_refs.py` (tree and history). `make check` runs eight gate
self-tests plus both test suites, and is green.

**What reading the documentation first changed.** Four Godot facts were checked
against the 4.7 docs rather than assumed, and one of them was a live bug:

- a `plugin.cfg` requires an `@tool` script extending `EditorPlugin`. The
  library addons here need none, because `class_name` registers a class
  project-wide with no plugin. `check_license.py` had been using `plugin.cfg` as
  the marker for "shippable addon", so a library addon was **skipped in
  silence** -- a gate failing open. Fixed, and the self-test case inverted.
- the Asset Library does not require `plugin.cfg`, does require `LICENSE` at the
  repository root, and **does** offer Apache-2.0. The tutorial page lists a few
  licences as examples and briefly looked like it ruled Apache out; the live
  filter has it.
- `TileMapLayer`, not `TileMap` -- the latter is deprecated in 4.x.
- `AStarGrid2D` is engine core in C++ with four heuristics, which is what the
  README's "when not to use this" should point at.

All four are in `docs/godot/addon-anatomy.md` with source URLs and a
`verified_on` date. `CLAUDE.md` gained the rule: read the documentation for the
pinned version first, then measure to confirm.

**How the employer gate avoids the obvious contradiction.** A gate searching for
a company name must contain that name, and a file saying "never mention X" is a
mention of X. The repository stores **salted SHA-256 hashes** instead, with a
prefix rule so one stored term also catches its compounds. `--add-term` reads
from a hidden prompt, so adding one never puts it in a file or a shell history.
The list is seeded with a single term derived from the work email domain;
**internal repository, client and project names are not on it yet** and should
be added with `--add-term`.

**Not proven.** The readability gate has only ever seen `smoke_test.gd`, which
is exempt from its doc-comment rule. It was confirmed to find real files by
planting an untyped function there (five findings, exit 1), but it has never
run against an addon, because none exists. The employer gate's history scan
walks every blob ever committed, which is fast on four commits and has not been
timed on a real history.

**Next:** `check_acceptance.py` and `check_status.py` (port from `desk-panel`,
and note that the former has **no** `--self-test` there -- the port must gain
one, and its non-terminating-command rules are about `adb` and a Python server,
which here means a Godot invocation without `--headless`). Then
`check_addon_deps.py`, `check_tiers.py`, `check_links.py`, `check_workflow.py`,
CONTRIBUTING.md and the CI workflow. After that, T2.

---

## Resuming after 2026-10-12 (wave 2)

**What landed.** gdUnit4 v6.2.2 installed by `make bootstrap`, pinned by tag and
verified by SHA-256. Two tests in `godot/test/smoke_test.gd`, and
`make test-godot` is now part of `make check`. The licence gate learned to tell
a third-party addon from one of ours.

**A decision reversed before it became history.** gdUnit4 was first vendored
into the repository. Staging it showed **509 files** of someone else's code
about to enter a repository whose premise is that you can read it. Switched to
install-at-bootstrap and gitignored; `docs/adr/0004` records why, including the
alternatives (submodule, writing a small runner) and what it costs: a fresh
clone must bootstrap before it can test.

**Three things the previous section got wrong, found by running them.**

1. `make test-godot` did not work. It ran `--path godot --quit` on a project
   with no main scene, which exits 1 -- and, despite `--headless`, popped a
   **zenity dialog** on the desktop. Replaced with a script entry point.
2. A rule was about to be written claiming Godot's exit code carries no
   information. Measured instead, and it is false: a parse error exits 1 and
   `quit(3)` exits 3. Godot propagates. The rule was not written.
3. gdUnit4 **refuses headless mode** unless given `--ignoreHeadlessMode`,
   because Godot does not deliver `InputEvent` there. That is now a standing
   constraint: a test in this repo must never depend on simulated input.

**What the licence gate found.** Vendoring gdUnit4 made `check_license.py` fire:
it would have required this project's NOTICE inside someone else's addon. The
gate now has a declared `VENDORED` table -- a vendored addon must carry its own
licence and must **not** carry ours, since our NOTICE in their folder claims
authorship we do not have. Declared one by one, never inferred.

**Still not proven.** The test suite has two tests and neither touches a line of
this project's own code, because none exists yet. What proves the runner can
fail is the planted failure: changing `2 + 2 == 4` to `== 5` gives exit 100, and
restoring it gives 0. Re-run that before trusting any future green.

**Known dangling reference.** `NOTICE` and `README.md` point at
`https://github.com/boscocp/game-ai-kit`, which returns 404 -- the repository is
local only, with no remote and nothing published. When `check_links.py` lands it
will flag this; the URL is the intended home, so it belongs in the link
exceptions file with that reason, not removed.

**Next:** the gates still missing -- `check_acceptance.py`, `check_status.py`,
`check_readability.py`, `check_no_employer_refs.py`, `check_tiers.py`,
`check_doc_freshness.py`, `check_addon_deps.py`, `check_links.py`,
`check_workflow.py` -- then CONTRIBUTING.md and the CI workflow. Note that
`desk-panel`'s `check_acceptance.py` has no `--self-test`; the port must gain
one, and its non-terminating-command rules need replacing (they are about `adb`
and a Python server; here the equivalent is a Godot invocation without
`--headless`).

---

## Resuming after 2026-10-12 (wave 1)

**What landed.** The repository exists at `/mnt/games/gamedev/game-ai-kit`, on
the large disk. Godot 4.7.2-stable is installed under
`/mnt/games/gamedev/toolchain/`, downloaded and verified by SHA-512. `make check`
is green with four gates: `check_disk_layout.py`, `check_renderer.py`,
`check_license.py` and the `bootstrap.sh` usage self-test. Three ADRs are
written (engine, toolchain layout, licence). LICENSE, NOTICE, README and
CLAUDE.md are in place.

**What the bootstrap found.** Enabling Godot's self-contained mode was assumed
to be enough to keep the toolchain off the small disk. It is not: with `._sc_`
in place, a bare `--headless --import` still recreated
`~/.local/share/godot/app_userdata/`. `XDG_DATA_HOME` covers the gap. Both
mechanisms now live in `scripts/godot`, and `check_disk_layout.py` asserts both.
Recorded in `docs/adr/0002`.

**What is not proven.** No Godot test has ever run — `make test-godot` only
opens and quits the project, because gdUnit4 is not installed yet. No GDScript
exists at all, so `check_renderer.py` has found nothing because there is nothing
to find; its self-test is what proves it can fail. `make` collapses every recipe
failure to exit 2, so a gate's own exit codes must be read by calling the script
directly.

**Next:** finish T1. `check_commit_msg.py` is done and the hook is live
(`make hooks`); it blocks assistant attribution in both forms, so overriding the
machine's global hook costs nothing. The gates still missing are
`check_acceptance.py`, `check_status.py`, `check_readability.py`,
`check_no_employer_refs.py`, `check_tiers.py`, `check_doc_freshness.py`,
`check_addon_deps.py`, `check_links.py`, `check_workflow.py`. Port the first
few from `desk-panel`, which is the only repository code is ported from here.

### What is still only true on this desk

- The toolchain path `/mnt/games/gamedev/toolchain` is this machine's layout.
  `GAK_TOOLCHAIN` overrides it, but nobody has run the gate with that override.
- `gdtoolkit` (gdformat/gdlint) has not been tried. Python here is 3.14.7 and
  `pip` is absent; if gdtoolkit cannot be installed, the GDScript formatting
  gate is deliberately left out of M1 and recorded in an ADR, rather than
  becoming a `continue-on-error`.
