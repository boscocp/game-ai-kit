## Who may attack a target now: a pool of tokens per attack kind, lent to
## one requester at a time and given back when the attack is over.
##
## Action games surround the player with a group and let only one or two
## strike at once. An enemy must hold a token to attack; the target owns
## the pool, one count per kind (`melee: 2`, `ranged: 1`), and an attack
## costs one token or more, as Kingdoms of Amalur's attack weights do
## against the player's attack capacity [Dawe 2013]. DOOM (2016) keeps a
## count per attack type and sets the counts by difficulty [Thompson 2018].
## Waiting requesters are served by a rule written down: the passed over
## first, then the highest priority, the one waiting longest, the nearest,
## and a seeded tie-break -- never the order they were stored in. A token
## comes back when the attack ends, the holder is interrupted or dies, the
## game revokes it, or it times out. A timer, stretched or shrunk by how
## busy the player is, spaces the grants of each kind.
##
## O(waiting log waiting) per grant, for the sort.
##
## When not to use it: a fight with one enemy, which needs no turns; or a
## stealth game, where the enemies should not be attacking at all.
class_name AttackTokens
extends RefCounted

const WAITING: String = "waiting"
const HOLDING: String = "holding"
const REFUSED_COST: String = "refused_cost"
const REFUSED_KIND: String = "refused_kind"
const GRANTED: String = "granted"
const ENDED: String = "ended"
const INTERRUPTED: String = "interrupted"
const DIED: String = "died"
const REVOKED: String = "revoked"
const TIMED_OUT: String = "timed_out"
const RETURN_REASONS: Array[String] = [ENDED, INTERRUPTED, DIED, REVOKED]


## The pool's numbers, all data: a difficulty table (T158) fills one.
class Config:
	extends RefCounted
	## Tokens per kind: how many cost units may be held at once.
	var pools: Dictionary[String, int] = {}
	## Seconds between two grants of a kind, before the multiplier.
	var delays: Dictionary[String, float] = {}
	## The longest a token may be held: the net for a holder that forgot.
	var timeouts: Dictionary[String, float] = {}
	## For each player state ("busy", "idle"), a factor per kind on the delay.
	var multipliers: Dictionary[String, Dictionary] = {}
	## A requester passed over this many grants is served before priority.
	var patience: int = 3
	## Breaks the ties the facts leave, the same way every run.
	var tie_seed: int = 0


class Waiter:
	extends RefCounted
	var id: String
	var kind: String
	var cost: int
	var priority: int
	var distance: float
	var asked_at: float
	var passed: int = 0


class Holder:
	extends RefCounted
	var kind: String
	var cost: int
	var since: float


## Every grant and every return, in order: {at, id, kind, what}, where
## `what` is GRANTED or a return reason. A view draws it; a test reads it.
var events: Array[Dictionary] = []

var _config: Config
var _free: Dictionary[String, int] = {}
var _next_grant: Dictionary[String, float] = {}
var _waiting: Dictionary[String, Waiter] = {}
var _holding: Dictionary[String, Holder] = {}
var _now: float = 0.0


func _init(config: Config) -> void:
	_config = config
	for kind: String in config.pools:
		_free[kind] = config.pools[kind]
		_next_grant[kind] = -INF


## Ask for a token: WAITING, HOLDING, or a refusal by name. A cost above
## its kind's whole pool could never be granted, so it is refused now
## rather than queued for ever. Asking again while waiting updates the
## priority and distance and keeps the place earned by waiting.
func request(id: String, kind: String, cost: int, priority: int, distance: float, now: float) -> String:
	_now = now
	if not _config.pools.has(kind):
		return REFUSED_KIND
	if cost < 1 or cost > _config.pools[kind]:
		return REFUSED_COST
	if _holding.has(id):
		return HOLDING
	if _waiting.has(id):
		_waiting[id].priority = priority
		_waiting[id].distance = distance
		return WAITING
	var waiter := Waiter.new()
	waiter.id = id
	waiter.kind = kind
	waiter.cost = cost
	waiter.priority = priority
	waiter.distance = distance
	waiter.asked_at = now
	_waiting[id] = waiter
	return WAITING


## Give a token back at once, for `reason` (ENDED, INTERRUPTED, DIED,
## REVOKED); true when `id` held one. A requester that dies also leaves
## the queue, so the dead are never granted.
func release(id: String, reason: String, now: float) -> bool:
	_now = now
	if reason == DIED:
		_waiting.erase(id)
	if not _holding.has(id) or not (reason in RETURN_REASONS):
		return false
	_return(id, reason)
	return true


## Take back every token of `kind`, the holders by name -- the one call
## that stops the ranged attackers when melee pressure starts.
func revoke_kind(kind: String, now: float) -> PackedStringArray:
	var revoked: PackedStringArray = holders(kind)
	for id: String in revoked:
		release(id, REVOKED, now)
	return revoked


## Time out the forgotten tokens, then grant what each kind's timer and
## pool allow, kinds in name order; the ids granted, in order. `state` is
## the player's ("busy", "idle"), and picks the delay's multiplier.
func step(now: float, state: String) -> PackedStringArray:
	_now = now
	_time_out(now)
	var granted := PackedStringArray()
	var kinds: Array[String] = _config.pools.keys()
	kinds.sort()
	for kind: String in kinds:
		granted.append_array(_grant_kind(kind, now, state))
	return granted


## The seconds between two grants of `kind` while the player is `state`:
## the base delay times the state's factor. Shown, not hidden.
func delay_for(kind: String, state: String) -> float:
	var factors: Dictionary = _config.multipliers.get(state, {})
	return float(_config.delays.get(kind, 0.0)) * float(factors.get(kind, 1.0))


## Tokens of `kind` free now.
func free_tokens(kind: String) -> int:
	return _free.get(kind, 0)


## Tokens of `kind` held now, counted from the holders themselves -- so
## held + free must equal the pool, and a test can see a leak.
func held(kind: String) -> int:
	var total: int = 0
	for id: String in _holding:
		if _holding[id].kind == kind:
			total += _holding[id].cost
	return total


## Who holds a token of `kind`, by id in name order.
func holders(kind: String) -> PackedStringArray:
	var found := PackedStringArray()
	for id: String in _holding:
		if _holding[id].kind == kind:
			found.append(id)
	found.sort()
	return found


## Who waits for `kind`, in the order they would be served.
func waiting(kind: String) -> PackedStringArray:
	var queue: Array[Waiter] = []
	for id: String in _waiting:
		if _waiting[id].kind == kind:
			queue.append(_waiting[id])
	queue.sort_custom(_serves_before)
	var order := PackedStringArray()
	for waiter: Waiter in queue:
		order.append(waiter.id)
	return order


## How many grants of its kind `id` has been passed over for, or -1.
func passed_over(id: String) -> int:
	return _waiting[id].passed if _waiting.has(id) else -1


## A 32-bit FNV-1a hash of `text`. The tie-break, the same in Python, so
## two languages and two runs order equal requests alike.
static func fnv1a(text: String) -> int:
	var hash_value: int = 2166136261
	for byte: int in text.to_utf8_buffer():
		hash_value = ((hash_value ^ byte) * 16777619) & 0xFFFFFFFF
	return hash_value


# While the kind's timer allows, the first in the queue gets a token -- or
# no one does: a heavy attack that does not fit yet is not overtaken by
# light ones, which would starve it.
func _grant_kind(kind: String, now: float, state: String) -> PackedStringArray:
	var granted := PackedStringArray()
	while now >= _next_grant[kind]:
		var queue: PackedStringArray = waiting(kind)
		if queue.is_empty() or _waiting[queue[0]].cost > _free[kind]:
			break
		_grant(_waiting[queue[0]], now)
		for index: int in range(1, queue.size()):
			_waiting[queue[index]].passed += 1
		granted.append(queue[0])
		_next_grant[kind] = now + delay_for(kind, state)
	return granted


func _grant(waiter: Waiter, now: float) -> void:
	_waiting.erase(waiter.id)
	var holder := Holder.new()
	holder.kind = waiter.kind
	holder.cost = waiter.cost
	holder.since = now
	_holding[waiter.id] = holder
	_take(waiter.kind, waiter.cost)
	events.append({"at": now, "id": waiter.id, "kind": waiter.kind, "what": GRANTED})


# The pool's count goes down by what a grant took. Its own function so a
# test can plant a leak here and watch the audit catch it.
func _take(kind: String, cost: int) -> void:
	_free[kind] -= cost


func _give_back(kind: String, cost: int) -> void:
	_free[kind] += cost


# Every holder past its kind's timeout gives its token back, by id order.
func _time_out(now: float) -> void:
	var expired: Array[String] = []
	for id: String in _holding:
		var limit: float = _config.timeouts.get(_holding[id].kind, INF)
		if now - _holding[id].since >= limit:
			expired.append(id)
	expired.sort()
	for id: String in expired:
		_return(id, TIMED_OUT)


# `id`'s token goes back to its pool now, and the log says why.
func _return(id: String, reason: String) -> void:
	var holder: Holder = _holding[id]
	_holding.erase(id)
	_give_back(holder.kind, holder.cost)
	events.append({"at": _now, "id": id, "kind": holder.kind, "what": reason})


# The serving order: the patient (passed over `patience` times) first, by
# how long they waited; then the rest by priority, waiting, distance, and
# the seeded hash; the id last, so the order is total.
func _serves_before(one: Waiter, other: Waiter) -> bool:
	var first: Array[float] = _order_of(one)
	var second: Array[float] = _order_of(other)
	for index: int in range(first.size()):
		if first[index] != second[index]:
			return first[index] < second[index]
	return one.id < other.id


func _order_of(waiter: Waiter) -> Array[float]:
	var patient: bool = waiter.passed >= _config.patience
	return [0.0 if patient else 1.0, 0.0 if patient else float(-waiter.priority),
			waiter.asked_at, waiter.distance, float(_tie(waiter.id))]


# The seeded tie-break. Its own function so a test can plant a broken one.
func _tie(id: String) -> int:
	return fnv1a("%d:%s" % [_config.tie_seed, id])
