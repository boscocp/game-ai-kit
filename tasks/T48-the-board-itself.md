# T48 — The board itself: a second crossing, a threat map, shorter fights

Size: L · Prereqs: T45, T46, T47 · Files: `godot/game/tactical/`, `spec/`, `python/gameaikit/dataset/`, `godot/test/`, `docs/`

## Goal

Only if T45-T47 leave the tactical board feeling like a queue. Three changes
to the game rather than to its controllers, each named in
[docs/design/tactical-references.md](../docs/design/tactical-references.md)
and each larger than the tasks before it:

- **A second crossing, or zones of control** (§1.3, §1.2). One two-cell
  bridge for four of five types gives a player no *where* to decide, only a
  *when*. A ford at the far edge, or Wesnoth's zone of control -- an enemy
  entering a cell beside a walker stops -- turns the bridge into a line
  held rather than a queue.
- **A threat map** (§2.2, Dave Mark's modular influence maps, by path
  distance so the river blocks it): where each side can strike next turn,
  for retreats and staging, and drawn -- Into the Breach's telegraphed
  intent (§2.5), and invariant 13.
- **One blow and one back instead of a fight to the death** (§1.2, Advance
  Wars and Wargroove): chip damage and focus fire start to mean something.
  It rewrites the combat vectors and retrains the combat model.

## Steps

1. Before anything, the owner chooses which, from T45-T47's measurements
   and a game played after them.
2. Each chosen change ships with its own measurement in
   `tactical_win_rates.gd`, stated before the change is made.

## Acceptance

```bash
make test-godot
make test-vectors
make tactical-win-rates GAMES=40 LIMITS="--at-most rr:draw:8"
```

A threat-map test must hold: a cell across the river with no crossing in
reach carries no threat from a walker that cannot wade, and a planted map
that counts one fails.

## Manual check

The owner plays three games and says whether the board offers a choice of
where to attack.
