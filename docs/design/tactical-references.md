# Tactical board: what similar games do (T44)

The owner, 2026-10-17, after the first measurements of the learned blue (20
draws in 20 against the rules, T44): stop tuning by trial and error, and
look at how similar games solve the same problems first. This is that look:
the games closest to the tactical board -- Advance Wars, Wargroove, Battle
for Wesnoth, Polytopia, Into the Breach -- and how their AIs are built, with
a source for every claim. The adjustments it led to are T45-T48.

**Where it came from.** One research pass on 2026-10-17, reading the pages
and source files cited; nothing here was re-checked afterwards, and each
line says how far it was checked. What the board itself does is measured by
`make tactical-win-rates`, and T44 holds those numbers.

Markers:
- **[V]** Checked in the cited source during the research pass. Quotes are the source's words.
- **[I]** An inference or an application to this board. Not stated by the source.
- **[W]** A weak source: a fan forum, a wiki fork, or a search snippet whose page would not open.

Fetch failures, so you know where the holes are: the Advance Wars Fandom wiki
(HTTP 402), StrategyWiki (403), the Wesnoth manual (bot wall), the GDC Vault talk
pages (login), and gamedev.net "Project AI" (403). Some Advance Wars numbers
below therefore rest on search snippets and are marked [W].

---

## 1. Mechanics in similar games

### 1.1 Income and capture

| Mechanic | Game / source | Status | Application here |
|---|---|---|---|
| Each property pays 1000 funds per turn. Standard starting funds are **0**, so all income comes from properties. | AWBW game guide, https://awbw.amarriner.com/guide.php | [V] | [I] Here the base 3 is larger than one point's 2, so holding points is worth less than just existing. In AW, income *is* territory. |
| A property has 20 capture points. Each capture turn removes the capturer's current HP, so a full-HP infantry needs 2 turns and a wounded one needs longer. | Wikipedia, Advance Wars 1+2: Re-Boot Camp, https://en.wikipedia.org/wiki/Advance_Wars_1%2B2:_Re-Boot_Camp ; StrategyWiki DS gameplay (403 in the research pass) | [W] (search snippets agree) | [I] Capture is an act that takes several turns and can be interrupted, so it creates a fight on a known tile. A control point "held = no enemy adjacent" has the same effect if each point has 2+ approaches. |
| Capturing the enemy HQ wins, and the enemy's buildings change hands. | StrategyWiki DS gameplay (via search) | [W] | Same role as our workshop. |
| Friendly properties repair +2 HP per turn at 10% of the unit's cost per HP. | Giant Bomb / StrategyWiki snippets | [W] | [I] A reason to fall back, and a sink for money. See 1.6. |
| Villages and Strongholds give 100 gold per turn. A captured structure starts at half the capturer's health and regenerates 10% per turn. An occupied structure must be beaten down to neutral before it can be captured. | Wargroove Wiki, Rules (in-game Codex copy), https://wargroovewiki.com/Rules | [V] | [I] Structures that fight back and must be ground down make a stalemate on a point cost something every turn. |
| A player loses when their Stronghold is destroyed **or** their Commander is defeated. | Wargroove Rules, same URL | [V] | [I] Two ways to lose means two fronts. Our only win is the workshop, and the only way to it is the bridge. |
| Villages pay gold, and each village supports one level of unit upkeep. A village therefore adds one more gold than its nominal value while your unit levels exceed your village count. | Wesnoth forum, https://forums.wesnoth.org/viewtopic.php?p=525695 | [W] (forum; wiki Upkeep page 404) | [I] Upkeep makes a jammed, idle army cost money every turn. It would not stop banking on its own. |
| Cities pay 1 star per city level per turn, and city level also caps how many units the city can field. | Polytopia Fandom (search summary), https://polytopia.fandom.com/wiki/File:Star.png ; https://mechanicsofmagic.com/?p=10286 | [W] | [I] A unit cap leaves surplus money with nowhere to go unless there is a sink: upgrades, repair, or a tech. |

### 1.2 Counters and damage

| Mechanic | Source | Status | Application |
|---|---|---|---|
| Base damage comes from a fixed matchup **chart**. It is scaled by attacker HP/10 (9 HP does 90%), reduced by terrain stars (0-5), plus flat luck of about +0-9%, rounded down. | AWBW Luck page and Advance Wars wiki Damage Formula (search snippets; the page returned 402), https://awbw.fandom.com/wiki/Luck , https://advancewars.fandom.com/wiki/Damage_Formula | [W] | [I] **A key difference from us.** AW resolves one attack plus one counter, and a wounded unit hits weaker. Our fights run to the death, so every engagement is all-or-nothing. That pushes a p(win) model toward "retreat unless sure", and it removes the value of chip damage and focus fire. |
| Terrain: "Each shield indicates a damage reduction of 10%, up to a maximum of 40%." Critical hits do "1.35x to 2.5x damage" when a unit-specific condition is met. | Wargroove Rules | [V] | [I] A crit with a stated condition is a counter you can read off the board, more legible than a +1 on a d4. |
| ZOC: "Every unit of level 1 or higher maintains a zone of control (ZOC) covering all 6 neighboring hexes." Enemies entering it must stop. | Wesnoth BasicStrategy, https://wiki.wesnoth.org/BasicStrategy | [V] | [I] ZOC turns a chokepoint into a *held line* instead of a traffic jam, and it gives a reason to bring the runner (fast flanker). |
| Guidance: attack "only when you can likely finish the target" or withstand the counter. Retreat a unit once it has lost more than half its HP. | Wesnoth BasicStrategy | [V] | Matches our p(win) gate. The difference is that Wesnoth fights are not to the death, so "retreat at half HP" exists as an option at all. |

### 1.3 Chokepoints and map design
- **[W]** An Ashes of Creation dev journal argues for a mix of open terrain and chokepoints "so that players have decision making about where and when to attack": https://forums.sorcererking.com/488081 . A gamedev.net blog post on TF-style maps describes bases joined by "a very deadly choke point": https://gamedev.net/blogs/entry/1825626-mechanics-2-choke-and-capture-points . Both are weak, general sources.
- **[I]** One 2-cell bridge is the only crossing for 4 of 5 unit types, so the map has no *where* decision, only *when*. A second crossing (a ford costing extra movement, or a second bridge at the far edge) gives the attacker a choice and lets the defender guess wrong.

### 1.4 Stalemate and game-length control

| Mechanic | Source | Status | Application |
|---|---|---|---|
| **Day limit:** "the player with the most owned properties (including labs and towers) is declared the winner". A tie is a draw. | AWBW guide, https://awbw.amarriner.com/guide.php | [V] | [I] Our round-40 draw becomes a decision by territory. The learned AI, which holds both points, would win those 20 games. That *ends* the draws without making the game more fun (see ranking #2). |
| **Capture limit:** "This sets the number of cities to be captured as a win condition." | AWBW guide | [V] | [I] An alternative win, such as holding both points for N consecutive rounds, forces the side that is behind to contest the points. |
| Wesnoth `turns`: when it runs out, a "time over" event fires and the scenario ends in defeat unless WML adds turns. The default is -1 (no limit) since 1.13 and was 100 in 1.12. | Wesnoth ScenarioWML, https://wiki.wesnoth.org/ScenarioWML | [V] | [I] In campaigns the limit is a pressure on the attacker, not a draw. |
| Into the Breach: every map has a fixed turn count, and you survive the waves until the counter reaches 0. | Fan reviews/wiki (search), https://intothebreach.fandom.com/wiki/Into_the_Breach | [W] | [I] Short, fixed-length battles. 40 rounds is long for a 14x9 board. |
| Polytopia "Perfection": 30 turns, then the highest score wins. | Wikipedia (search snippet), https://en.wikipedia.org/wiki/The_Battle_of_Polytopia | [W] | [I] A score at the limit is the standard answer. |
| Snowballing: it shortens games once one player clearly leads, but used carelessly it can make interesting choices "too simple". Downwell ends a losing run quickly instead of dragging it out. | Nikhil Murthy, "Second Looks At Snowballing", https://www.gamedeveloper.com/design/second-looks-at-snowballing | [V] | [I] Some snowball (income from points) is good *because* it ends games. The problem here is that the leader's surplus never becomes force on the board. |

### 1.5 First-player advantage

| Mechanic | Source | Status | Application |
|---|---|---|---|
| FTA counters: (a) the "Half Turn Advantage", where P2 gets "½ the value of the FTA", is the approach recommended by Chucklefish; (b) a P2 pre-recruited unit, or one side of P2's army "a full turn ahead"; (c) P2 starting gold equal to "the exact amount of income they'd be disadvantaged by"; (d) "an additional 10% health to the building owned by Player 2". | Wargroove Wiki, First Turn Advantage, https://wargroovewiki.com/First_Turn_Advantage | [V] | Red wins 58/60 (T26), 20/20 with the points (T44). Every counter on this list is a parameter we could sweep. |
| "a predeployed infantry for the second player is the tried-and-true way to counter FTA" | AWBW guide | [V] | (b) applied here: a pre-placed runner or shield for blue. |
| FTA Counter defined as "typically an extra pre-owned city or infantry". | AWBW wiki glossary (search snippet; page 402) | [W] | |

[I] At 58/60, red is not merely first; it is probably reaching the bridge first. Mirrored-seed testing will show whether the cause is tempo (fixed by a counter) or position (fixed by the map).

### 1.6 Fog of war
- **[V]** Wargroove: "Any enemy unit inside a fog tile is invisible". Sight is blocked by mountains, walls and forests, and structures stay visible (Rules page). AWBW has fog as an optional setting (guide).
- **[I]** We already have a watchtower, so fog would give it a job. It also makes the learned model's features partially observed, which is a large change. Not recommended until the stalemate is fixed.

---

## 2. How these games' AIs are built

### 2.1 Wesnoth RCA AI (the best-documented reference) -- [V]
Source: https://wiki.wesnoth.org/RCA_AI (rev. 2022-11), https://wiki.wesnoth.org/AiWML ,
source code https://github.com/wesnoth/wesnoth/blob/master/src/ai/default/attack.cpp and `ca.cpp` (read in the research pass).

- **Loop:** "The CA with the highest evaluation score is executed and the process is repeated." Everything is re-scored after each action, and the turn ends when nothing is valid.
  Fixed scores: goto 200,000, retreat-injured 192,000/95,000, recruitment 180,000, combat 100,000,
  healing 80,000, villages 60,000, move-to-targets 20,000, **move-to-any-enemy 1,000** (a fallback so units do not "sit idle", per https://wiki.wesnoth.org/Experimental_AI).
  - [I] *Recruitment outranks movement, so money is spent first, every turn.* Our 170 banked funds suggest the learned side never reaches its build step, or reaches it with a gate that keeps saying no.
  - [I] The 1,000 fallback answers our "no move gets closer" directly: when the goal is unreachable, have a lower-priority goal instead of a no-op.
- **Attack rating** (verbatim from `attack_analysis::rating`):
  `value = chance_to_kill*target_value - avg_losses*(1.0-aggression)`, plus
  `((target_starting_damage/3 + avg_damage_inflicted) - (1-aggression)*avg_damage_taken)/10`
  ("Prefer to attack already damaged targets"), then multiplied by `support/(vulnerability*terrain_quality)`.
  It is divided by resources used, and multiplied by 5 if the target threatens the leader.
  The sanity check returns -1 if `vulnerability > 50 && vulnerability > support*2 && chance_to_kill < 0.02 && aggression < 0.75 && !attack_close(target)`,
  where `attack_close` is true when the target is closer than 4 hexes (`< 4`, so within 3) to an attack already made this turn.
  *Corrected after wave 47's review:* it lifts only this check, which refuses near-hopeless attacks; it has nothing to do with retreat.
  - Attack options are **multi-attacker combinations** (`movements`), and `chance_to_kill` is the result after the whole sequence. **Focus fire is evaluated as one option**, not as N independent unit decisions.
  - `attack_close` lets a unit join a fight already started nearby with an attack the sanity check would otherwise refuse. [I] A "do not retreat from a fight a friend started" rule is an extension of that idea to retreat, and is this board's own, not Wesnoth's.
  - `target_value` = unit cost, raised by experience.
- **Aggression/caution:** aggression default 0.4, and values above 1 are discouraged. Caution default 0.25. Old retreat rule: "A retreat takes place, if caution × their_power > our_power", and "never retreats if caution is set to 0". 1.15.11+ uses `retreat_factor` (default 0.25) for injured units only.
  - [I] Retreat compares *side power* in an area, not one fight's odds. A per-fight p(win) < 0.5 → retreat makes every unit retreat whenever its own fight is marginal, even when the side is ahead.
- **Village grabbing:** `get_villages_phase::dispatch` builds a reach map (unit → villages it can reach) and assigns units to villages so that no two units take the same village (`dispatch_unit_simple`, `dispatch_village_simple`, `dispatch_complex`).
  [I] **Unique target assignment** is the fix for several walkers queuing for the same point or bridge cell.
- **Recruitment:** "For each unit type the AI leaders can recruit, the CA simulates fights against all enemy units on the map." The score is weighted by enemy HP, and an "important hexes" defense average is computed. `recruitment_save_gold` is an explicit state machine (NORMAL / SAVE_GOLD / SPEND_ALL_GOLD), off by default (https://wiki.wesnoth.org/AI_Recruitment).
  [I] The default is to spend. Saving is opt-in and has thresholds.
- Experimental AI: its village focus is "probably too focused on villages", and it "needs to be either improved or removed". It wins gold but loses fights (https://wiki.wesnoth.org/Experimental_AI). [I] This is the same failure as our learned side, which holds points and banks money without converting either.

### 2.2 Influence and threat maps -- [V]
Dave Mark, "Modular Tactical Influence Maps", Game AI Pro 2 ch. 30,
https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter30_Modular_Tactical_Influence_Maps.pdf
- A per-faction **proximity map** (where agents can get to soon) and **threat map** (what they can hit). A ranged unit's threat is "a ring of influence surrounding the agent's location". Use **path distance**, not straight-line distance, when obstacles matter: the tiger behind a fence is close but "not a threat". Combine maps by add/multiply/invert to find safe cells, contested fronts and targets.
- [I] The river makes straight-line distance wrong: a unit across the water is close but not a threat. A threat map built from our existing pathfinder gives "where is safe to stand" and "where to wait for numbers". The learned AI's p(win) can read it as a feature, and the threat map is itself a visualization (invariant 13).

### 2.3 Avoiding dithering and oscillation
- **[V]** IAUS wiki (utility AI): the current behaviour gets a constant score boost to discourage flip-flopping, https://github.com/ProjectBorealis/IAUS/wiki .
- **[V]** Utility Intelligence docs: a "Momentum Bonus" multiplies the last chosen decision on the next round, with a suggested value of 1.1-1.25, and a "keep running until finished" option for attacks, https://uintel-go.utilityworlds.com/Documentation/UtilityIntelligence/Decisions/ .
- **[V]** Shawn Hargreaves on hysteresis: a thermostat switches on and off at different thresholds, https://www.shawnhargreaves.com/blog/hysteresis.html .
- [I] One threshold (attack if p ≥ 0.5, else retreat) is exactly the setup that flickers. Two thresholds (commit at ≥ 0.55, abandon below ~0.35) plus a remembered per-unit "committed" flag are the standard fix. Logging the flips makes the problem measurable.

### 2.4 Advance Wars AI
- **[W]** No primary source found. Players report it "does the same things over and over" and that difficulty comes from the starting setup. They report it prioritises some targets, such as going out of its way to hit APCs, and can be lured (https://gamedev.net/forums/topic/335563 ; https://www.nintendolife.com/users/MrRedfield/comments). Treat these as anecdote.
- [I] Lesson: a predictable AI is acceptable, and arguably part of the fun, when the scenario supplies the challenge.

### 2.5 Fun AI vs good AI
- **[V]** Soren Johnson, "Playing to Lose: AI and Civilization" (GDC 2008). The blog post confirms the thesis of "good" versus "fun" AI, with Civ "somewhere between those two extremes", https://www.designer-notes.com/playing-to-lose-ai-and-civilization-gdc-2008/ . The talk content itself is only on video and was not verified here.
- **[V]** Into the Breach: "This lead us to use of telegraphed enemy attacks as a core mechanic"; "We wanted to make something where every death felt like your own fault"; "it's very clear how or why you failed so that you can feel like you can improve" (Justin Ma, Road to the IGF, https://gamedeveloper.com/game-platforms/road-to-the-igf-subset-games-i-into-the-breach-i- ). The GDC 2019 postmortem by Matthew Davis is at https://gdcvault.com/play/1025772/ ; its contents were not verified.
- **[V]** Research frameworks: Tribes (a Polytopia-like framework from QMUL) benchmarks rule-based, OSLA, MC, MCTS and RHEA agents, which "can play at a decent level" but are "far from human playing strength", https://gaigresearch.github.io//2020/06/15/perez2020tribes/ . Stratega (general TBS framework with forward model), arXiv 2408.06202.

---

## 3. Fun in tactics games
- **[V]** Sid Meier, "Interesting Decisions" (GDC 2012). Secondary summaries give four properties: **tradeoffs** (no right answer), **situational**, **personal**, **persistent** (lasting effect, signalled as such). https://gamedeveloper.com/design/video-sid-meier-explores-interesting-decisions-in-gameplay ; the summary is at https://computerscience.chemeketa.edu/cis125greader/Choice/BossBattle.html [W for the four-way breakdown].
  [I] On our board, the money decision (build now / save for a ram / which counter) is the one most likely to be "interesting". Right now it is not being made at all, because funds bank.
- **[V]** Into the Breach (above): readable failure, telegraphed intent, every loss the player's fault.
  [I] Show next-turn threat (bolt tower ring, enemy reach) and the AI's committed targets as arrows. That serves invariant 13 and the "feel".
- [I] Short games: ITB maps run a few turns, and Polytopia Perfection 30. With income starting at 3, a cost-4 ram, and one bridge, 40 rounds are mostly approach and queueing.

---

## 4. Ranked candidate adjustments

Each item names its sources and an acceptance that can be measured. "Match" means the
headless `godot/test/tactical_match.gd` harness over fixed seeds, as
`make tactical-win-rates` plays it. Every win rate is reported
together with its seed count.

1. **Spend-first build step and a fallback goal for idle units** (Wesnoth: recruitment 180k > combat > move; move-to-any-enemy 1k; spend is the default, saving opt-in).
   Both AIs run "build" before "move" every turn. A unit with no reachable goal falls back to "advance toward the nearest enemy building / threat-map front" instead of a no-op.
   *Acceptance:* over 20 learned-vs-rule matches, (a) unspent funds after the build step are below the cheapest unit's price (1) in ≥ 90% of turns, or below the ram's price (4) when the plan is explicitly "save for ram"; (b) "no move gets closer" decisions per match ≤ 5% of unit-turns (at T44: 52.5% of the learned blue's walker decisions, 43.9% as red).
2. **Make the round limit decide the game** (AWBW day limit: most properties wins; Polytopia Perfection score).
   At round 40, the winner is the side with the higher score: workshop health, then control-point rounds held, then unit value. A true draw happens only on equal scores.
   *Acceptance:* the draw rate in 60 rule-vs-rule and 20 learned-vs-rule matches is ≤ 5%. It also needs a planted test: a scripted equal position must still report a draw (invariant 4). *Caveat [I]:* this alone turns the learned AI's stalemate into wins, so ship it together with #1 and #3, and also report "decided before round 40" separately.
3. **Hysteresis and commitment in the learned policy's attack/retreat** (momentum 1.1-1.25; thermostat thresholds; Wesnoth's `attack_close`, which lets an attack near one already made pass a check that would refuse it -- extended here, as this board's own rule, to retreat).
   Commit at p ≥ 0.55. Once committed, keep attacking until p < 0.35. Waive the retreat for a unit within 4 cells of a friendly attack made this turn.
   *Acceptance:* an "oscillation" counter (a unit alternating advance/retreat on consecutive turns) drops by ≥ 75% against today over the same 20 seeds, and the learned AI's decisive-win count vs rule rises above 0/20.
4. **First-turn-advantage counter for blue** (Wargroove: half-turn advantage, P2 starting gold, pre-recruited unit, +10% building health; AWBW predeployed infantry).
   Sweep the variants as data in `combat_rules.json`: blue starting gold of +1.5 (half a turn of base income) or +3, or a predeployed blue shield.
   *Acceptance:* rule-vs-rule with mirrored seeds, red win rate in [40%, 60%] over ≥ 100 matches (T26: 58 of 60; with the points, T44: 20 of 20). Pick the smallest counter that lands in the band.
5. **Unique goal assignment** (Wesnoth `get_villages_phase::dispatch`: no two units take the same village).
   Assign each walker a distinct target cell (a point, a bridge cell, a staging cell) as a small assignment problem before moving. Extra units go to a staging cell behind the bridge, chosen from the threat map (#7).
   *Acceptance:* the number of own units adjacent to a bridge cell without moving for ≥ 2 consecutive turns is ≤ 1 per side per match on average (instrument and measure today's value first).
6. **A second crossing, or ZOC to make the bridge a line rather than a queue** (chokepoint and open-terrain mix; Wesnoth ZOC).
   Either add a 1-cell ford (enter cost 3, like trees) on the far bank edge, or give walkers a ZOC so a held bridge stops the enemy instead of jamming your own side.
   *Acceptance:* in rule-vs-rule, the share of matches decided before round 40 rises to ≥ 80%, and both crossings are used in ≥ 30% of matches (count unit crossings per tile).
7. **Threat map as a shared feature and an overlay** (Mark, Modular Tactical Influence Maps; ITB telegraphing).
   Build a per-side threat map from the existing pathfinder (path distance, so the river blocks it, and a ring for the bolt tower and mortar). Feed it into staging (#5) and retreat choices, and draw it.
   *Acceptance:* a unit test asserts that a cell across the river with no bridge in reach has 0 threat from a non-wader (and a planted case where it is wrongly non-zero fails). The overlay is populated in the scene (the `check_demos.py` half); seeing it is under `## Manual check`.
8. **(Larger, later) Bounded exchanges instead of fights to the death** (AW/Wargroove: one attack plus one counter, damage scaled by attacker HP; Wesnoth "prefer damaged targets").
   [I] This would make focus fire, chip damage and retreat-to-repair meaningful, but it rewrites spec vectors and the learned model's labels.
   *Acceptance:* the mean number of distinct units engaged per kill is ≥ 1.5 (focus fire happens), and the decisive-before-limit rate in rule-vs-rule is ≥ 80%. It also needs a retrained model whose held-out log loss is no worse than today's.

Suggested order: 1, 3 and 5 are AI changes that touch no rules and can be measured on the current board. 4 and 2 are rules data with clear bands. 6 and 8 change the board or the combat spec, so do them only if 1-5 still leave the game feeling like a queue.
