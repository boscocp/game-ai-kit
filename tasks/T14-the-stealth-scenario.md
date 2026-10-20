# T14 — The stealth scenario

Size: L · Prereqs: T13 · Files: `godot/game/stealth/`, `godot/addons/ai_perception/`

## Goal

One room, a few guards, no combat at all — and the three techniques shipped
games lean on hardest: perception, state machines, and influence maps.

It is in the kit because it is cheap to build and rich to reason about. There
is nothing to balance, nothing to produce, and no economy; every line of it is
about what the AI *knows* and what it does about it.

## Steps

1. Perception as its own addon: a vision cone with range and angle, line of
   sight through `GridGraph` (trees block sight and cost movement — one map,
   two meanings), and hearing as a radius the player's actions fill.
2. Suspicion as a fuzzy variable, which is what T13 exists for: distance, light,
   noise and time-since-seen in, one number out. A boolean "has seen the player"
   is the thing this replaces, and the demo should let you watch the number
   move.
3. An influence map over the grid: where the guards can see, where they will be
   soon, where it is safe. Drawn, because an influence map you cannot see is a
   number nobody trusts.
4. Patrol routes that use `ai_search` — the guards walk with A\*, which makes
   the search addon earn its place twice.
5. The player is a unit on the same board. No new core.

## Acceptance

```bash
make test-godot
make test-vectors
python3 scripts/check_addon_deps.py
```

```bash
./scripts/godot --headless --path godot -s res://test/stealth/perception_properties.gd
```

Properties worth asserting over generated maps rather than one example: sight
is symmetric when nothing blocks it; a wall between two cells blocks sight from
both sides; suspicion never decreases while the player is visible; and the
influence map's danger at a guard's own cell is its maximum.

## Manual check

Walk past a guard at the edge of its cone and watch the suspicion number. It
should rise and fall in a way you can anticipate — that is the difference
between a fuzzy controller and a random one, and only a person can see it.
