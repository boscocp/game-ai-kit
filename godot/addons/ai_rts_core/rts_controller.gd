## Whoever plays a side: shown a snapshot, answers with commands.
##
## The whole contract between an AI and the match. A controller never sees
## the world, only `RtsSnapshot`; it never changes anything, only returns
## `RtsCommand`s, which the world may refuse. A scripted opponent, a planner
## and a recording all fit it, which is how T25's league puts any of them in
## any seat.
##
## `work` is the controller's own count of what a decision cost it -- nodes
## expanded, units weighed -- in whatever unit it thinks in. The match reads
## it after every decision, beside the time the decision took.
##
## When not to use it: a person. A person's clicks become commands too, but
## through `RtsMatch.give`, between ticks, not in answer to a snapshot.
class_name GakRtsController
extends RefCounted

## Work done in the decision just made; the match resets it before each.
var work: int = 0


## This controller's commands for `view`. The base class gives none: a side
## left alone, which is a fair opponent for a test.
func decide(_view: RtsSnapshot) -> Array[RtsCommand]:
	return []
