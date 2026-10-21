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
## Seconds two of its bots held cover spots within a metre, summed over pairs.
var bunched_seconds: float = 0.0
var shots: int = 0
var hits: int = 0
## Shots at a target that was not in the shooter's own sight row. The
## honest bots never make one; a planted cheat must.
var shots_unseen: int = 0
