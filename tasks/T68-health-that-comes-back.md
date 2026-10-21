# T68 — Health that comes back, and a bot that weighs falling back to heal

Size: M · Prereqs: T66, T67 · Files: `godot/game3d/botmatch/`, `godot/addons/ai_teamwork/`, `python/gameaikit/teamwork/`, `spec/vectors/teamwork/`, `godot/test/botmatch/`, `docs/godot/botmatch.md`, `docs/concepts/shooter-ai.md`

## Goal

The owner, 2026-10-21, in their words: "uma coisa que queria por no jogo
de fps alinhado com que temos no mercado, depois de 10 segundos sem tomar
dano a vida volta aos poucos. E incluir isso no pensamento da IA de ver se
vale fugir pra recuperar a vida. Ou recupera toda vida instantâneo se for
na base onde recupera munição."

So, three things:

1. **Health regenerates**: after 10 s without taking damage, health comes
   back a little at a time, as in the shooters people know.
2. **The base heals at once**: at its resupply, where it gets its rounds,
   a bot -- or the person -- is healed whole, instantly.
3. **The AI weighs it**: whether to break off and hide to regenerate, or go
   back to the base to heal whole, is a decision priced like the others
   (T67's selector), not a rule like "below 30 health, run".

## Before writing the rule

Read how shipped shooters do it, and cite what is opened (the house rule):
Halo's recharging shield (its delay and rate, and why a delay), Call of
Duty's regenerating health, and any developer source on how regeneration
changes how bots and players fight -- the "pull back to cover and come
again" rhythm. Write it into `docs/concepts/shooter-ai.md`. The owner's
10 s is the starting delay; the rate is chosen from the sources and
written in `rules.json` with where it came from.

## Steps

1. **Regeneration in the rules.** `rules.json` gains the delay (10 s), the
   rate (health a second) and whether it is gradual to the full 100. A bot's
   clock since its last hit already exists (`hurt_at`); regeneration reads
   it. The person's bot regenerates by the same rule.
2. **The base heals whole.** `MatchSupply`'s touch at the resupply heals
   too; the errand's gain counts health as well as rounds.
3. **Healing is weighed.** Two ways to heal become actions the bot weighs
   in T67's selector, each a cost and a gain in one unit:
   - **hide and wait**: break line of sight with every enemy it knows of,
     at the nearest spot that does (a `TacticalPositions` query asked for
     cover from all, not from the main threat), and wait out the delay;
     worth the health it gets back, costing the time off its post and the
     point it leaves;
   - **go home**: walk to the base for full health and rounds; worth both,
     costing the walk.
   - Staying to fight stays an option, priced by the fight it is in --
     `SquadConfidence` already counts health in a squad's strength.
4. **The view.** The HUD shows the person's health coming back, and the
   seconds left to the delay; the overlay shows each healing option's
   score for the watched bot.
5. **Re-measure** with `botmatch_effects.gd`, every claim with its planted
   case. Add:
   - regeneration starts only after the delay and never overheals -- a
     planted regeneration that starts at once must be caught;
   - weighing when to heal holds points at least as long as never breaking
     off to heal, and as long as always breaking off below a fixed health
     -- each a planted pairing, by the two-margin method. If the numbers
     do not hold it, say so, as T51 and T66 did.
6. `docs/godot/botmatch.md`: the rule, its sources, the numbers.

## Acceptance

```bash
make test-botmatch-effects
make test-teamwork-vectors
make test-godot-some SUITES="test/botmatch test/ai_teamwork"
python3 scripts/check_readability.py
python3 scripts/check_modules.py
python3 scripts/check_doc_freshness.py
```

## Manual check

Play `make demo-botmatch` and take a bot over (T).

- Does health come back after ten seconds out of the fight, and does it
  feel like the shooters you know?
- Does the base heal you whole?
- Watching a hurt bot (V): does it break off when the scores say so, and
  come back into the fight?
