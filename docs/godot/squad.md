# The squad mode: XCOM's shot, cover and fog on the tactical board

<!-- doc-meta
half_life: practice
verified_on: 2026-10-30
tier: 1
source: https://ufopaedia.org/Gameplay_Mechanics_(EU2012) ; https://ufopaedia.org/index.php/Cover_(EU2012) ; book:Steve Rabin (ed.), "Game AI Pro 3", CRC Press, 2017 -- ch. 28 (Roelofs, MCTS for strategy and tactical games)
invalidated_if: spec/squad/rules.json changes, the tactical map changes, or a rule below stops being the code's
teaches: none
-->

> T84's rules. Not a new game: a second ruleset of the tactical game,
> played on its state, map, pieces and pictures. T85 makes it something a
> person plays from the tactical scene; T87 and T88 put search behind it.
> This page is the rules, where each comes from, and everything left out.

## The seam

The tactical scene asks a `TacticalRuleset` (in `godot/game/tactical/`)
everything a mode decides: the starting state, what a walk and an attack
do and why one is refused, what happens as a turn opens, who has won, the
board's tint, the points it marks, and the roster C cycles.

- `AdvanceWarsRuleset` wraps the classes that answered those questions
  before -- `TacticalScenario`, `BoardState`, `TacticalCombat`, `TurnStart`,
  `TacticalVictory`, `ThreatMap`, `TacticalRoster` -- **unchanged**. It is
  the scene's default, and every tactical gate passes through it with the
  same seeds and the same results.
- `SquadRuleset` (module `squad`, `godot/game/squad/`) is this mode.

The scene is handed its ruleset by whoever opens it, as it is handed its
computer player, so `tactical` never names `squad`: the module edge runs
`squad -> tactical`. `BlueTurn` and `TacticalDecision.played_on` take the
ruleset too, so the computer's decisions are played by the same rules as
the person's. `board` did not change.

## The rules, and where each comes from

UFOpaedia, the series' community wiki, on XCOM: Enemy Unknown (2012),
opened on 2026-10-26:

| rule | UFOpaedia | here |
|---|---|---|
| two actions a turn | "Time Units have been removed and replaced with a two-part action system" | a piece's type has two actions of movement; `movement_points` carries both |
| a shot ends the turn | "a unit's turn automatically ends after the unit performs any action other than Move on its 1st Action" | a shot leaves the shooter no movement |
| the dash | (the same rule: Move, then Move) | a walk past one action spends the piece; it may not shoot |
| half cover | "conveys a -20% hit chance penalty" | trees beside the target: 20 |
| full cover | -40% | rock beside the target: 40 |
| only adjacent cover | "cover only grants a defence bonus if a unit is standing directly next to it" | only the four cells beside the target are read |
| flanking | from a flanking position "there will be no cover defence bonus applied" | a shooter on no side that cover protects gets the target's cover at 0 |

The numbers are in `spec/squad/rules.json` (ADR 0007), copied byte for byte
to `godot/game/squad/` and `python/gameaikit/squad/`; a Python test holds
the copies to the spec.

- **Hit chance** = the shooter's aim - the target's defence - cover,
  clamped to [0, 100]. One die from 0 to 99; the shot hits when the die is
  below the chance. A hit takes the shooter's damage off the target.
- **Which side cover faces.** A cell of cover one step `d` from the target
  protects it against a shooter whose offset from the target has a positive
  part along `d`. The best cover that faces the shooter counts. A target
  with cover beside it and none facing the shooter is **flanked**.
- **Sight.** Trees and rock block a line of sight, as `TacticalRules`
  promised for fog, except a cell beside either end of the line: a piece
  leans out past its own cover, and shoots at a target behind its cover at
  the cover's price. The line is Bresenham's, drawn from the end that sorts
  first, so the line is mutual; the reach is each piece's own (a runner
  sees 6 steps, a shield 5). Pieces never block it.
- **A shot** needs the shooter itself to see the target -- within its own
  sight, with the line clear -- and the target within its range, in steps;
  and the shooter must still hold a whole action. A mortar reaches 7 and
  sees 6, so it shoots at 7 only at what it sees; a shot never names an
  enemy its side's view does not hold, and a refused shot at an unseen
  enemy says nothing of where it is.
- **Fog, by side.** A side sees an enemy when one of its pieces is within
  its sight, in steps, with the line clear. `SideView` is a side's board --
  its own pieces and the enemies it sees, with the dice seed taken out --
  and the cells where it last saw the others. A controller in this mode
  decides on that view, never on the state.
- **The squads.** Four a side, one each of the runner, the shield, the
  mortar and the wader, on their own bank by their own map edge, mirrored
  through the board's centre. No workshop, towers, funds, points or
  building. The wader still wades.
- **The end.** A side with no piece left has lost. At the round limit (20)
  the side with more health left, summed, wins; equal health is a draw.
- **A decision is one unit's action.** `SquadRuleset.actions` lists every
  walk and every shot of the side to move, each one unit's: Roelofs'
  hierarchical expansion, which keeps a search's branching near one unit's
  options rather than their product [GAP3 ch. 28].

The squad roster (`SquadRoster`) is its own table, not rows added to
`TacticalRoster`: `League.schedule` seats the league's teams by their place
in that table, and a row added there would re-roll the league's dice. It
has one row, `random`, a seeded random mover on its side's view -- the
floor T85's first enemy has to beat.

## What is left out, and why

Every simplification, so nobody reads the mode as more of XCOM than it is:

- **Overwatch and hunker down.** Overwatch shoots in the other side's
  turn, and every search in T87 and T88 would have to model an interrupt;
  hunker down doubles cover and is only worth having beside overwatch. A
  later task can add both once the searches stand.
- **Aim, defence, damage, health, range and sight** are this kit's numbers,
  chosen to make the four pieces different. Only the cover values and the
  two-action turn are borrowed.
- **No range modifier, no critical hit, no graze, no damage spread.** XCOM
  has all four; flanking there also raises the critical chance. Here a
  shot hits or misses, and a hit does a fixed damage.
- **No high ground, no destructible cover, no wall cover.** The tactical
  map has neither height nor walls, and its trees and rock never break.
- **Cover from the map's own letters.** Nothing new is drawn on the map.
  Standing *on* trees gives no cover; only standing beside them does.
- **Sight is a line per pair**, not a field of view: fine for eight pieces.
- **A seen enemy is seen whole.** XCOM hides an enemy's kind and health
  until it is seen; here an unseen enemy is an id and a remembered cell.
- **No squad sight, no abilities, no items, no grenades, no psionics.**

## How it is held

- `make test-squad-vectors`: twelve hand-checked shots in
  `spec/vectors/squad/` -- cover facing and not, a shooter level with the
  cover, the shooter's own cell, flanking, the clamp, a die equal to the
  chance -- against the GDScript and the Python twin.
- `make test-godot-some SUITES=test/squad`: the rules one at a time, the
  tactical scene handed this ruleset, and the property check over 300
  seeded positions on the tactical map: every legal action leaves a legal
  state, a shot or a dash spends the piece, no side's view holds an enemy
  it cannot see (nor misses one it can), no listed shot names an enemy
  outside its side's view, and a seeded game replays to its
  digest. Each of the first three was shown to fail on a planted mutation
  (no dash rule, a view that sees everything, a shot that does not spend,
  a shot that needs only the line and not the shooter's sight).
- Every tactical gate, unchanged, through `AdvanceWarsRuleset`.

## Manual check

Read `spec/squad/rules.json` beside the two UFOpaedia pages: are the
numbers the ones the mode claims to borrow, and is every simplification
said above? Then play `make demo-tactical` as before: is the Advance Wars
mode exactly the game it was?
