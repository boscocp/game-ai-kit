## How a bot gets past a body in its way: wait, go round, ask a teammate to
## step aside, or give up the spot for another.
##
## Bodies that cannot pass through each other jam in doors and against
## walls, and no one rule unjams them: waiting is right behind someone who
## is walking off, and wrong behind someone holding a spot all match; going
## round is right in a room and impossible in a corridor; asking is right of
## an idle teammate and wrong of one in a fight, or of an enemy; and a spot
## that is hard to reach may not be worth reaching. So each is priced in the
## one unit they share -- seconds lost -- from facts the game measures, and
## the bot takes the cheapest. The first listed wins a tie, and when nothing
## is possible it waits.
##
## Asking is a request, not an order (the owner's design, 2026-10-21): the
## bot that is blocked does not know whether its teammate can move, so it
## weighs only whether asking is worth it, and sends with the request what
## being let by saves it. The teammate weighs that against what moving costs
## itself now -- more with each enemy it sees, more again shooting or
## covering a retreat -- and steps aside when the saving is larger. A
## refusal is remembered for a while, and the blocked bot then takes its
## next cheapest way. It is the shape of The Last
## of Us's arbiter, requests granted and refused [McIntosh 2015], at the
## scale of two bots in a door.
##
## Constant time; the expensive fact is the detour, an A* the game runs over
## the walk with the bodies near it blocked. When not to use it: a crowd.
## Pricing one blocker at a time is right for a few bodies in a door, and
## wrong for twenty in a square, where steering through the flow is.
class_name PassageChoice
extends RefCounted

const WAIT: String = "wait"
const DETOUR: String = "go round"
const ASK: String = "ask to pass"
const OTHER_SPOT: String = "another spot"
## The ways on, in the order a tie is broken.
const WAYS: Array[String] = [WAIT, DETOUR, ASK, OTHER_SPOT]


## What the game measured about one blocked bot and the body in its way.
class Facts extends RefCounted:
	## How far the blocker must still move for the way to clear, in metres,
	## and how fast it is moving off -- zero when it holds or comes closer.
	var gap: float = 0.0
	var leaving_speed: float = 0.0
	## The extra metres of the way round, or INF when there is none.
	var detour_metres: float = INF
	## The bot's own walking speed.
	var speed: float = 1.0
	## Whether the blocker is a teammate -- only one may be asked -- and
	## whether it refused lately, which closes asking until it is forgotten.
	var teammate: bool = false
	var refused: bool = false
	## What asking costs, in seconds: the teammate's time off its spot.
	var ask_seconds: float = 1.0
	## How much less the next best spot is worth, and what a second of
	## travel is worth in the same points; INF when there is no other spot.
	var spot_loss: float = INF
	var points_a_second: float = 1.0


## Each way's cost, and the one taken.
class Choice extends RefCounted:
	## In WAYS' order: seconds lost each way, INF where it cannot be taken.
	var costs: PackedFloat64Array = PackedFloat64Array()
	var chosen: String = WAIT


## A request to step aside, as the teammate asked weighs it: what moving
## would cost it, in seconds lost, and what it saves the bot that asks.
class Request extends RefCounted:
	## What the bot that asks saves if it is granted: its next cheapest way
	## less the cost of asking.
	var saves: float = 0.0
	## Enemies the teammate sees now, and whether it is shooting, reloading
	## or covering a retreat -- each a reason moving costs it more.
	var enemies_in_sight: int = 0
	var shooting: bool = false
	var reloading: bool = false
	var covering_a_retreat: bool = false
	## The limits that are not choices: a person at its controls, whom no
	## bot moves; and no place a step aside where it can stand.
	var driven_by_a_person: bool = false
	var room_to_step: bool = true


## What moving costs the teammate asked, by what it is doing: seconds per
## enemy it sees, and for shooting, reloading and covering a retreat.
class Prices extends RefCounted:
	var step_seconds: float = 0.5
	var per_enemy_seen: float = 2.0
	var shooting: float = 1.5
	var reloading: float = 0.5
	var covering_a_retreat: float = 3.0


## The teammate's answer: what stepping aside costs it, and whether it does.
class Answer extends RefCounted:
	var cost: float = 0.0
	var granted: bool = false


## What stepping aside costs the teammate, in seconds: the step, and its
## price for each thing it would leave off; INF when it cannot move at all.
static func cost_to_step_aside(request: Request, prices: Prices) -> float:
	if request.driven_by_a_person or not request.room_to_step:
		return INF
	return prices.step_seconds + prices.per_enemy_seen * request.enemies_in_sight \
			+ prices.shooting * float(request.shooting) + prices.reloading * float(request.reloading) \
			+ prices.covering_a_retreat * float(request.covering_a_retreat)


## The teammate's answer: it steps aside when that saves the asker more than
## it costs itself. No rule says "never in a fight": a fight is a high price.
static func answer(request: Request, prices: Prices) -> Answer:
	var reply := Answer.new()
	reply.cost = cost_to_step_aside(request, prices)
	reply.granted = request.saves > reply.cost
	return reply


## The seconds each way costs, in WAYS' order.
static func costs_of(facts: Facts) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	found.append(facts.gap / facts.leaving_speed if facts.leaving_speed > 0.0 else INF)
	found.append(facts.detour_metres / maxf(facts.speed, 1e-6))
	found.append(facts.ask_seconds if facts.teammate and not facts.refused else INF)
	found.append(facts.spot_loss / maxf(facts.points_a_second, 1e-6))
	return found


## The cheapest way on, the first of equal cost; WAIT when none is possible.
static func choose(facts: Facts) -> Choice:
	var choice := Choice.new()
	choice.costs = costs_of(facts)
	var best: float = INF
	for index: int in range(WAYS.size()):
		if choice.costs[index] < best:
			best = choice.costs[index]
			choice.chosen = WAYS[index]
	return choice
