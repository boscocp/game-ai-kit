# T42 — Examples that are fun to play

Size: L · Prereqs: T41 · Files: `tasks/`, `docs/`

## Goal

The owner, 2026-10-15: the examples need to be more playful and more
interesting. The board demos teach the technique, and playing them is not
yet something a person wants to do twice: the tactical game is easy to win
or stalls, the skirmish has no pressure on the player.

This is a design task before it is code. It ends in a short list of
changes or new examples, each agreed with the owner, each its own task.

## Steps

1. Play every example and write one line each: what a player does, what
   makes them want another round, what is missing.
2. Keep to games people already know, against the AI, with low-friction
   input and scenarios a person can edit (the owner's standing ask).
3. Propose, per example, the smallest change that adds a goal, pressure or
   a surprise -- a clock, a score, an objective the AI also wants -- without
   hiding the decision overlay (invariant 13).
4. Bring the list to the owner; write the chosen ones as tasks.

## Acceptance

```bash
test -f docs/design/fun-review.md
```

## Manual check

The owner reads the list and picks.
