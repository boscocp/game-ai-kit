## What one team did in a match, counted for `botmatch_effects.gd`. Each
## count is one the task's claims are about, and nothing else.
class_name MatchStats
extends RefCounted

## Seconds of points owned, summed over the points.
var point_seconds: float = 0.0
var kills: int = 0
var deaths: int = 0
## Times a point this team owned was taken back to nobody's.
var points_lost: int = 0
## Points with a living bot of this team within the rules' area radius,
## times the seconds -- over the match's length, how many points it covers
## at once on average.
var point_coverage: float = 0.0
## Distinct points this team's living bots are ordered to, times the
## seconds: what the commander decides, before the fighting has a say.
var order_spread: float = 0.0
## Decisions at which a retreating squad of two or more had every living
## member on the move: zero when it retreats in waves, one half covering.
var retreats_uncovered: int = 0
## Decisions at which a squad of two or more living was retreating.
var retreat_decisions: int = 0
## Seconds two of its bots held cover spots within a metre, summed over pairs.
var bunched_seconds: float = 0.0
var shots: int = 0
var hits: int = 0
## Health taken off enemies, and hits by zone (head, torso, limb).
var damage: int = 0
var zone_hits: Dictionary = {}
## Shots at a target that was not in the shooter's own sight row. The
## honest bots never make one; a planted cheat must.
var shots_unseen: int = 0
## Shots fired while sprinting, which the rules forbid. Never one, from a
## bot or a person: the rule is held where a shot is fired, and counted.
var shots_sprinting: int = 0
## Seconds its living bots spent sprinting, summed: what makes "no shot
## while sprinting" more than a count of nothing.
var sprint_seconds: float = 0.0
## Seconds its living bots spent with no round at all, summed; times the
## power weapon was taken from its place, and won by a streak at the base.
var dry_seconds: float = 0.0
var power_taken: int = 0
## Health its bots got back by regenerating, and at their base, in points
## (T68).
var regenerated: int = 0
var healed_at_base: int = 0
