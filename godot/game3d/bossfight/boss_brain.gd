## A boss that fights in phases and telegraphs every blow: a behaviour tree
## picks the phase, a utility choice picks the attack, and the target's
## attack tokens say when it may strike.
##
## The top of the tree is a selector, asked in this order every decision:
##
## - **defeated**: no health left, so it falls;
## - **mid-attack**: an attack underway, or a token just granted, is carried
##   through its windows -- the tree keeps no memory, so the commitment to
##   finish a swing is the brain's, held here;
## - **one branch per phase, the last first**: a phase opens when health is
##   at or below its threshold *and* the phase before it has been entered,
##   so a big hit that skips a threshold still enters every phase, in order,
##   once, on consecutive decisions: a phase whose next threshold is already
##   met is passed through without choosing an attack. Below the phase's
##   condition sits its attack choice.
##
## The attack choice is `ActionChoice` over the phase's own moveset. Each
## attack's considerations are data -- the distance, which way the player
## faces, how long since it was last used (a penalty that only spaces attacks
## out) -- plus one the brain adds to every attack itself, so no table can
## forget it: a step that scores zero on a third use in a row. The chosen
## attack asks the target's `AttackTokens` for a token of its kind; a heavy
## attack costs the kind's whole pool, so no minion strikes during it, and
## the boss's priority puts it before the minions already waiting. With the
## token, it runs telegraph, active, recovery, and gives the token back.
##
## A phase change is an event in `events`; the minions' director reads it.
## The boss spawns nothing, and counts nothing about the player.
##
## Complexity: a decision visits each tree node once and scores the phase's
## attacks, O(phases + attacks x considerations).
##
## When not to use it: an enemy that never changes its moveset needs no
## phase tree -- the utility choice alone is the decision.
class_name BossBrain
extends RefCounted

## The id the boss queues under in the token pool.
const ID: String = "boss"
## What it is doing, as the overlay names it.
const CLOSING: String = "closing"
const WAITING: String = "waiting"
const TELEGRAPH: String = "telegraph"
const ACTIVE: String = "active"
const RECOVERY: String = "recovery"
const DEFEATED: String = "defeated"
const WINDOW_STATES: Array[String] = [TELEGRAPH, ACTIVE, RECOVERY]
## An attack used this many times in a row scores zero: never three.
const MOST_IN_A_ROW: int = 2
## "Since last used" for an attack never used: long enough for any curve.
const NEVER_USED: float = 1000.0

## Health, 1 full and 0 defeated.
var health: float = 1.0
## The phase entered, by index into the table's phases; -1 before the first.
var phase: int = -1
## One of CLOSING, WAITING, TELEGRAPH, ACTIVE, RECOVERY, DEFEATED.
var state: String = CLOSING
## The attack chosen or underway, or "".
var attack: String = ""
## Every phase entered, attack started, attack called off and the fall, in
## order: {at, what, ...}. The director reads the phases; a test reads all.
var events: Array[Dictionary] = []
## The tree, whose `trail` shows the last decision's path.
var tree: BehaviourTree
## The last attack choice, and the actions it scored, for the overlay.
var last_choice: ActionChoice.Choice = ActionChoice.Choice.new()
var last_actions: Array[ActionChoice.Action] = []
## Why the boss cannot fight, or "": a refused table, or a kind with no pool.
var refusal: String = ""

var _table: BossTable
var _tokens: AttackTokens
var _movesets: Array = []
var _window_started: float = 0.0
var _window_ends: float = 0.0
var _last_used: Dictionary[String, float] = {}
var _streak_attack: String = ""
var _streak: int = 0


## A boss reading `table`, striking `tokens`' target. A heavy attack costs
## its kind's whole pool, read from `tokens` itself so the two cannot drift.
func _init(table: BossTable, tokens: AttackTokens) -> void:
	_table = table
	_tokens = tokens
	refusal = _why_not_fight()
	if refusal != "":
		return
	for phase_data: BossTable.Phase in table.phases:
		_movesets.append(_moveset_of(phase_data.attacks))
	tree = _build_tree()


## Decide at time `now`, the player `distance` metres away and `facing` it
## (1 looking straight at the boss, -1 its back turned). The game calls the
## token pool's `step` between decisions; that is where a token is granted.
func decide(now: float, distance: float, facing: float) -> BehaviourTree.Status:
	if refusal != "":
		return BehaviourTree.Status.FAILURE
	return tree.tick({"now": now, "distance": distance, "facing": facing})


## Lose `amount` of health, never below zero.
func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)


## True while a heavy attack is underway: the one no minion may strike in.
func heavy_underway() -> bool:
	return state in WINDOW_STATES and _table.attacks[attack].heavy


## True in the active window: the only one that hurts.
func hurts() -> bool:
	return state == ACTIVE


## How far through the telegraph the boss is at `now`, 0 to 1; 0 outside it.
func telegraph_progress(now: float) -> float:
	if state != TELEGRAPH or _window_ends <= _window_started:
		return 0.0
	return clampf((now - _window_started) / (_window_ends - _window_started), 0.0, 1.0)


## What the overlay shows at `now`: the phase, what the boss does, the
## telegraph bar, every attack's score and the answers behind it, and the
## tree's trail. A boss that cannot fight shows only why, in `refusal`.
func shown(now: float) -> Dictionary:
	var seen: Dictionary = {"phase": "", "state": "", "attack": "", "telegraph": 0.0, "reasons": [], "trail": []}
	seen["refusal"] = refusal
	if refusal != "":
		return seen
	seen["phase"] = _table.phases[phase].name if phase >= 0 else ""
	seen.merge({"state": state, "attack": attack, "telegraph": telegraph_progress(now)}, true)
	seen.merge({"reasons": _reasons(), "trail": tree.trail.duplicate()}, true)
	return seen


# Every attack the last choice scored: its score, and each consideration's
# answer by percept.
func _reasons() -> Array[Dictionary]:
	var reasons: Array[Dictionary] = []
	for index: int in range(last_actions.size()):
		var answers: Dictionary = {}
		for which: int in range(last_actions[index].considerations.size()):
			answers[last_actions[index].considerations[which].percept] = last_choice.answers[index][which]
		reasons.append({"attack": last_actions[index].name, "score": last_choice.scores[index], "answers": answers})
	return reasons


## The whole pool of `kind` at the target, held plus free: T154 keeps the
## two summing to the pool, so this is the pool the tokens were built with.
func pool_size(kind: String) -> int:
	return _tokens.free_tokens(kind) + _tokens.held(kind)


func _why_not_fight() -> String:
	if _table.refusal != "":
		return _table.refusal
	for attack_data: BossTable.Blow in _table.attacks.values():
		if pool_size(attack_data.kind) < 1:
			return "attack %s's kind, %s, has no token pool" % [attack_data.name, attack_data.kind]
	return ""


# The phase's attacks as `ActionChoice` actions: the table's considerations,
# and the brain's own "not a third time" after them.
func _moveset_of(attack_names: PackedStringArray) -> Array[ActionChoice.Action]:
	var data: Array = []
	for attack_name: String in attack_names:
		var attack_data: BossTable.Blow = _table.attacks[attack_name]
		var considerations: Array = attack_data.considerations.duplicate(true)
		considerations.append(_not_a_third_time(attack_name))
		data.append({"name": attack_name, "weight": attack_data.weight, "considerations": considerations})
	return ActionChoice.actions_from(data)


# A step on how many times in a row the attack has just run: 1 below
# MOST_IN_A_ROW, 0 from it on, which vetoes the attack whatever else says.
func _not_a_third_time(attack_name: String) -> Dictionary:
	var step: Dictionary = {"percept": "repeats:" + attack_name, "curve": ActionChoice.STEP}
	step.merge({"at": float(MOST_IN_A_ROW), "below": 1.0, "above": 0.0})
	return step


func _build_tree() -> BehaviourTree:
	var branches: Array[BehaviourTree.TreeNode] = [
		_branch("defeated", "no health left", _is_defeated, "fall", _fall),
		_branch("mid-attack", "attack underway", _is_attacking, "carry on", _carry_on),
	]
	for index: int in range(_table.phases.size() - 1, -1, -1):
		var phase_name: String = _table.phases[index].name
		var opens: String = "%s opens" % phase_name
		var choose: String = "choose in %s" % phase_name
		branches.append(_branch(phase_name, opens, _phase_opens.bind(index), choose, _choose_in.bind(index)))
	return BehaviourTree.new(BehaviourTree.Selector.new("boss", branches))


# A sequence of two: a condition, then what to do when it holds.
func _branch(label: String, asked: String, question: Callable, done: String, deed: Callable) -> BehaviourTree.Sequence:
	var children: Array[BehaviourTree.TreeNode] = [
		BehaviourTree.Condition.new(asked, question), BehaviourTree.Action.new(done, deed)]
	return BehaviourTree.Sequence.new(label, children)


func _is_defeated(_facts: Dictionary) -> bool:
	return health <= 0.0


func _fall(facts: Dictionary) -> BehaviourTree.Status:
	if state != DEFEATED:
		_tokens.release(ID, AttackTokens.DIED, facts["now"])
		state = DEFEATED
		attack = ""
		events.append({"at": facts["now"], "what": DEFEATED})
	return BehaviourTree.Status.SUCCESS


# Underway: in a window, or waiting when the token has just come.
func _is_attacking(_facts: Dictionary) -> bool:
	return state in WINDOW_STATES or (state == WAITING and _holds_token())


# Through the windows as time passes; the token goes back when recovery
# ends. A token lost on the way -- timed out, revoked -- calls the attack
# off: the boss never strikes without one.
func _carry_on(facts: Dictionary) -> BehaviourTree.Status:
	var now: float = facts["now"]
	if state == WAITING:
		_start(now)
	if not _holds_token():
		events.append({"at": now, "what": "called_off", "attack": attack})
		_stop()
		return BehaviourTree.Status.FAILURE
	while now >= _window_ends and state != CLOSING:
		_next_window()
	if state == CLOSING:
		_tokens.release(ID, AttackTokens.ENDED, now)
		_stop()
		return BehaviourTree.Status.SUCCESS
	return BehaviourTree.Status.RUNNING


func _next_window() -> void:
	var attack_data: BossTable.Blow = _table.attacks[attack]
	_window_started = _window_ends
	if state == TELEGRAPH:
		state = ACTIVE
		_window_ends += attack_data.active
	elif state == ACTIVE:
		state = RECOVERY
		_window_ends += attack_data.recovery
	else:
		state = CLOSING


# A phase opens at its threshold, and only after the one before it.
func _phase_opens(_facts: Dictionary, index: int) -> bool:
	return health <= _table.phases[index].health_at_most and phase >= index - 1


# Enter the phase if new, score its moveset, and ask for the winner's token.
# Nothing scoring above zero means no attack fits here: the boss closes in.
func _choose_in(facts: Dictionary, index: int) -> BehaviourTree.Status:
	if phase != index:
		_enter(index, facts["now"])
	if _next_phase_open(index):
		return BehaviourTree.Status.RUNNING
	last_actions.assign(_movesets[index])
	last_choice = ActionChoice.choose(last_actions, _percepts(facts))
	if last_choice.chosen < 0:
		_tokens.withdraw(ID, facts["now"])
		_stop()
		return BehaviourTree.Status.RUNNING
	attack = last_actions[last_choice.chosen].name
	var attack_data: BossTable.Blow = _table.attacks[attack]
	var cost: int = pool_size(attack_data.kind) if attack_data.heavy else 1
	var answer: String = _tokens.request(ID, attack_data.kind, cost, _table.priority, facts["distance"], facts["now"])
	state = WAITING
	if answer == AttackTokens.HOLDING:
		_start(facts["now"])
	return BehaviourTree.Status.RUNNING


# A big hit that already met the next phase's threshold: this phase is
# passed through, with no attack chosen, and the next decision enters it.
func _next_phase_open(index: int) -> bool:
	return index + 1 < _table.phases.size() and health <= _table.phases[index + 1].health_at_most


# A new phase: a request still queued from the old phase is dropped, or
# the token could arrive and start an old-phase attack here. (A held token
# never reaches this: the mid-attack branch is asked first.) The event says
# whether minions come with it.
func _enter(index: int, now: float) -> void:
	_tokens.withdraw(ID, now)
	_stop()
	phase = index
	events.append({"at": now, "what": "phase", "phase": _table.phases[index].name,
			"summon": _table.phases[index].summon})


func _percepts(facts: Dictionary) -> Dictionary:
	var percepts: Dictionary = {"distance": facts["distance"], "facing": facts["facing"]}
	for attack_name: String in _table.attacks:
		percepts["since:" + attack_name] = facts["now"] - _last_used.get(attack_name, facts["now"] - NEVER_USED)
		percepts["repeats:" + attack_name] = _streak if attack_name == _streak_attack else 0
	return percepts


# The token is held: the telegraph starts, and the attack counts as used.
func _start(now: float) -> void:
	state = TELEGRAPH
	_window_started = now
	_window_ends = now + _table.telegraph_of(attack, phase)
	_last_used[attack] = now
	_streak = _streak + 1 if attack == _streak_attack else 1
	_streak_attack = attack
	events.append({"at": now, "what": "attack", "attack": attack, "phase": _table.phases[phase].name,
			"telegraph": _window_ends - now})


func _stop() -> void:
	state = CLOSING
	attack = ""


func _holds_token() -> bool:
	for attack_data: BossTable.Blow in _table.attacks.values():
		if ID in _tokens.holders(attack_data.kind):
			return true
	return false
