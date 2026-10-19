## Five ways to decide what an agent does, and when each is the right answer.
##
## This table is what `ai_behaviour` is for; the four classes beside it, and
## STRIPS in `ai_planning`, are the evidence. One guard was written in each
## of the four here (`demos/behaviour/`), on T14's room, knowing the same
## facts and able to do the same six things -- so where they differ, the way
## of deciding is the only thing that differs.
##
## | way | the right answer when | what it costs | the guard showed |
## |---|---|---|---|
## | state machine | a few states, each with a clear way out | every state names its own exits; shared behaviour is written twice | it snaps: nothing changes until an arrow fires, and its gap between going up and coming down kept it searching as suspicion faded |
## | behaviour tree | behaviour built of reusable parts, re-judged every tick | it cannot commit: every tick starts at the root | "go and look" hangs in two branches as one value; as suspicion faded it turned back on the next tick |
## | GOAP | many ways to a goal, and the agent should find the cheap one | a search every time it replans; backwards, so no partial plan | the same worlds as the HTN, but slower per plan (below); it replans each turn, so it turned back too |
## | HTN | the designer knows how tasks break down, and wants that order kept | every order is one somebody wrote -- it walked to where it stood until "look here" was written | it carried on down "go and look" as suspicion faded, until it had looked |
## | STRIPS (`ai_planning`) | a goal reached through a chain nobody wrote down, searched forwards | a search over the whole world, bounded by a budget | not written as a guard: it plans the tactical board's purchases (T11) |
##
## **Measured on the guard** (`test/behaviour_test.gd`, wave 56): in four
## moments -- on the round, setting out to look, looking, the chase -- GOAP
## searching backwards and the HTN decomposing forwards looked at the same
## number of worlds: 2, 3, 2 and 3. So Humphreys' "considerably faster"
## (Game AI Pro, ch. 12) does not show in worlds on a guard this small. It
## shows in time (`test/behaviour_benchmark.gd`, 2000 plans each, one
## machine): the HTN took about 6 to 8 microseconds a plan and GOAP about 6
## to 15 -- nearly twice as long in the chase. GOAP pays at every world for trying every action and
## remembering every world; the HTN tries only one task's methods. The claim
## holds here in time, and a guard this small cannot tell whether it holds in
## search.
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
