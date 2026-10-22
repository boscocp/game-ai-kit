# T81 — Guards hear a player walking behind them

Size: S · Prereqs: T70 · Files: `godot/game3d/infiltration/`, `godot/test/infiltration/`, `docs/godot/infiltration.md`, `docs/concepts/stealth-ai.md`

## Goal

The owner played `make demo-infiltration` on 2026-10-22: "parece que a
mecanica de som nao ta funcionando [...] eu andando perto do guarda de
costas pra ele, ele nao parece ouvir".

Measured before writing this: the player standing and walking 0 to 2 m
behind a guard on the warehouse, the guard's sound awareness went 0.03 at
0.1 s, 0.18 at 2.6 s, and reached 0.25 -- its first phase past unaware --
only at 5.1 s: about 0.04 a second. The player makes a footstep every
`noise_every` (0.4 s), and the step is 0.1 s; a guard counts a sound as
heard only in the one step it arrives in, and its awareness falls in the
three between. So a player walking is heard a quarter of the time, and a
guard rises at a quarter of its rate, less its decay.

A footstep stands for the walking until the next one. Make a sound that
goes on -- the player's steps -- heard for as long as it goes on, so the
guard's awareness rises at its type's rate, and hold that with a claim the
old behaviour fails.

## Steps

1. **The failing claim first.** A guard standing still, the player
   walking out of its sight behind it, alone on the level: standing at 1 m
   and 3 m the guard reaches its first phase past unaware within
   `NOTICE_WITHIN` seconds; crouched at 3 m, slower than standing or not
   at all; prone, never. The bound: The Last of Us perceives a seen player
   in "around 1 or 2 seconds for the typical NPC" [McIntosh 2015]; no
   source opened gives a time for hearing footsteps, so the kit takes the
   upper end, 2 s, and says so. Show it fails on wave 80's code, with the
   numbers.
2. **A sound held while it goes on.** Each sound is delivered with how
   long it holds: the player's steps hold for `noise_every`, the cadence
   of the noise its own rules make; a one-off event (a throw, a shot, a
   report) holds for none, as before. The guard hears a held sound in every
   step until it ends or a louder one replaces it. Not T69's event
   lifetime: that is how long an event is remembered and claimed (4 s for a
   footstep), and a guard hearing one footstep for 4 s would be alert from
   a single step.
3. **The glance turns to what was heard.** `_glance` read `guard.heard`,
   which was empty by the time a guard acts; it reads the percept.
4. **Planted**: each sound heard for the one step it arrives in (wave
   80's behaviour) must fail the claim.
5. **Re-measure** `make test-infiltration` and `make
   test-infiltration-properties`, and write what moved in
   `docs/godot/infiltration.md`; a claim that stops holding is said, not
   tuned.

## Acceptance

```bash
make test-infiltration
make test-infiltration-properties
make test-godot-some SUITES="test/infiltration"
python3 scripts/check_readability.py
python3 scripts/check_modules.py
python3 scripts/check_doc_freshness.py
```

## Manual check

Play `make demo-infiltration`, walk up behind a guard standing: does it
turn within a second or two? Crouched: does it take longer, or not hear
you at all? Prone: never?
