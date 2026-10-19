## Five ways to decide what an agent does, and when each is the right answer.
##
## This table is what `ai_behaviour` is for; the four classes beside it, and
## STRIPS in `ai_planning`, are the evidence. One guard was written in each
## of the four here (`demos/behaviour/`), on T14's room, knowing the same
## facts and choosing among the same deeds -- the planners among five, since
## no goal of theirs is served by stopping to turn towards a noise -- so
## where they differ, the way of deciding is what differs.
##
## | way | the right answer when | what it costs | the guard showed |
## |---|---|---|---|
## | state machine | a few states, each with a clear way out | every state names its own exits; shared behaviour is written twice (searching, and alerted having lost sight) | it snaps: nothing changes until an arrow fires; its gap between going up and coming down kept it searching as suspicion faded, so it reached the intruder in the light, chased and caught |
## | behaviour tree | behaviour built of reusable parts, re-judged every tick | it cannot commit: every tick starts at the root | "go and look" hangs in two branches as one value; it turned back the moment suspicion dipped, and in 300 turns never got far enough to chase |
## | GOAP | many ways to a goal, and the agent should find the cheap one | a search every time it replans; backwards, so no partial plan | this guard has one way to each goal, so its search found what the tree was told: the same deed on every one of 300 turns |
## | HTN | the designer knows how tasks break down, and wants that order kept | every order is one somebody wrote -- it walked to where it stood until "look here" was written | it carried on down "go and look" as suspicion faded, looked, chased and caught |
## | STRIPS (`ai_planning`) | a goal reached through a chain nobody wrote down, searched forwards for the fewest actions -- where GOAP searches backwards for the cheapest | a search over the whole world, bounded by a budget | not written as a guard: it plans the tactical board's purchases (T11) |
##
## **Measured on the guard** (`test/behaviour_test.gd`, wave 56): in four
## moments -- on the round, setting out to look, looking, the chase -- GOAP
## took 2, 3, 2 and 3 worlds off its frontier, and the HTN took up 2, 3, 2
## and 3 tasks: the nearest counts the two have, not one unit, since the HTN
## counts its compound task too. In time (`test/behaviour_benchmark.gd`,
## 2000 plans each, one machine) the HTN took about 6 to 8 microseconds a
## plan and GOAP about 6 to 15 -- nearly twice as long in the chase. That is
## these two implementations, and much of GOAP's extra is how this one keeps
## its frontier (a guess recomputed at every comparison, a text key for every
## world), not which way it searches. So Humphreys' "considerably faster"
## (Game AI Pro, ch. 12) holds for these two in time, and a guard this small
## cannot say whether it holds for the two ways of searching.
##
## When not to use it: as a rule. The table is about this guard and the
## sources in `docs/concepts/planning-in-strategy-games.md`; a game whose
## agents look nothing like a guard should measure its own.
class_name WaysToDecide
extends RefCounted


## The table's rows as [way, the right answer when] -- what the demo shows
## beside the brain that is playing.
static func when_each_is_right() -> Array[Array]:
	return [
		["state machine", "a few states, each with a clear way out"],
		["behaviour tree", "reusable parts, re-judged every tick"],
		["GOAP", "many ways to a goal; find the cheap one"],
		["HTN", "the designer knows the order, and wants it kept"],
		["STRIPS", "a chain nobody wrote down, searched forwards"],
	]
