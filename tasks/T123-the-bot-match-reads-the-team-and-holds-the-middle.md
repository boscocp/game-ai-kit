# T123 — The bot match reads the team's share, holds the middle, and starts over on a new team

Size: S · Prereqs: T100 · Files: `godot/game3d/botmatch/`, `godot/test/botmatch/`, `python/gameaikit/botmatch/`, `spec/vectors/player_model/`, `python/tests/`, `docs/godot/botmatch.md`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendations of two items of STATUS's 2026-11-04 list, taken here as
one task because both change `PlayerModel` and `MatchDifficulty`:

- **B12:** the difficulty overshoots. One bot's share sets six bots'
  aim, and the match flips both ways (`make measure-player-model`).
  *Recommended:* a follow-up reading the team's share, with a band of no
  change around the middle, measured the same way.
- **B13:** when the person takes a bot of the other team, the counts
  carry on. *Recommended:* start them empty on a change of team.

T100's review (`docs/reviews/121-the-bot-match-reads-the-player.md`)
measured the flip: -121 to +259, and +224 to -218. The middle row is
where every match starts, and an even player chatters around it.

## Decisions written down first

_The owner ratified only the items quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **The team's share.** The damage the person's team dealt over dealt
  and taken, with the same Beta prior (`prior_points` in `rules.json`).
  It is still counts and sums, starting empty, never saved, rebuildable
  from the match's log (ADR 0016's conditions, rule N14).
- **The band** is a range of the share around the middle row, declared
  in `rules.json`'s `difficulty` table, in which the knob does not move.
  Its width comes from `make measure-player-model`, written down with
  the run that chose it.
- **A change of team empties the counts.** Taking a bot on the same
  team keeps them. Giving the bot back keeps them too, since nobody is
  then playing.
- **The log replays it.** The log already records the takeover; the
  replay empties the counts at the same step, so condition 3 holds.
- **Vectors in both languages** gain cases for the band and for a change
  of team.

## Steps

1. The team's share, the band and the reset, in GDScript and the Python
   twin.
2. Vectors: a share inside the band moves nothing; a change of team
   starts from empty.
3. Measure with `make measure-player-model` and write the table on the
   page beside T100's, whichever way it comes out.

## Acceptance

```bash
make test-player-model-vectors
make test-godot-some SUITES="test/botmatch"
python3 -m unittest discover -s python/tests -t python -p "test_player_model*.py"
python3 scripts/check_no_training.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play `make demo-botmatch` with V open, poorly and then well, then take a
bot on the other team: does the other team's aim settle without flipping,
and does the panel show the counts starting over?

## Notes

- **One of the follow-ups the owner deferred.** On 2026-11-05 the owner
  said "deixa os followup pra depois" when choosing waves 125-127; the
  bot match's items were among them. It waits for the owner's word on
  when, not only for its prereq.
- Shares no folder with T88 or T96.
