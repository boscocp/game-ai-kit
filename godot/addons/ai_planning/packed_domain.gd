## A domain with its predicates numbered, so a world is one integer and an
## action is three masks.
##
## `WorldState` is a set of strings, and that is the readable version: it
## prints as what it means. A planner asks the same three questions of it
## millions of times -- does this hold, what is true after this action, have
## I seen this world -- and each answer is a dictionary walk, and the third
## builds a sorted, joined string. Here each predicate is one bit of an `int`,
## so the three answers are `&`, `& ~ |` and the integer itself as the key.
## What that is worth is measured in `test/planner_benchmark.gd`, not claimed.
##
## The translation runs one way, once per plan: strings in, bits for the
## search, strings back out for the plan the game reads.
##
## Complexity: packing is O(actions x predicates in their lists). Every
## question after that is O(1).
##
## When not to use it: more than `MOST_PREDICATES` predicates, which an `int`
## cannot hold; `why_unpackable` says so rather than wrapping round. And not as
## the version to read first -- that is `WorldState`.
class_name PackedDomain
extends RefCounted

## GDScript's `int` is 64 bits. The top one is the sign, which `&` and `|`
## handle perfectly well; keeping clear of it costs one predicate and saves a
## reader wondering why a world printed as a negative number.
const MOST_PREDICATES: int = 63

## Every predicate, in bit order: `predicates[3]` is bit `1 << 3`.
var predicates: PackedStringArray

## The actions, as given, for their names and for the plan handed back.
var actions: Array[StripsAction]

## Each action's preconditions, deletes and adds as masks, in `actions` order.
## Three parallel arrays rather than an object per action, because the search
## reads them in its innermost loop and an array of ints is what reads fastest.
var needs: PackedInt64Array
var removes: PackedInt64Array
var gives: PackedInt64Array

## The same preconditions and adds as lists of bit numbers, for the relaxed
## estimate in `RelaxedCost`, which walks them one predicate at a time.
var needed_bits: Array[PackedInt32Array] = []
var given_bits: Array[PackedInt32Array] = []

var _bit_of: Dictionary[String, int] = {}


## Number every predicate named by `domain_actions`, `start` or `goal`.
##
## The start and the goal are included because a predicate no action mentions
## can still be true at the start, or wanted at the end -- and a goal naming
## something no action can add is how a domain says "this is impossible",
## which the search must be able to hear.
func _init(domain_actions: Array[StripsAction], start: WorldState = WorldState.new(),
		goal: PackedStringArray = PackedStringArray()) -> void:
	actions = domain_actions
	predicates = PackedStringArray()
	for action: StripsAction in actions:
		_number_all(action.preconditions + action.deletes + action.adds)
	_number_all(start.predicates() + goal)
	if why_unpackable() != "":
		return
	for action: StripsAction in actions:
		needs.append(mask_of(action.preconditions))
		removes.append(mask_of(action.deletes))
		gives.append(mask_of(action.adds))
		needed_bits.append(bits_of(action.preconditions))
		given_bits.append(bits_of(action.adds))


## Why this domain cannot be held as bits, or "" when it can.
func why_unpackable() -> String:
	if predicates.size() > MOST_PREDICATES:
		return "%d predicates, and an int holds %d" % [predicates.size(), MOST_PREDICATES]
	return ""


## The mask with a bit set for each of `names`. A name this domain never
## numbered sets nothing -- which, for a goal, is never the case, because the
## constructor numbered the goal too.
func mask_of(names: PackedStringArray) -> int:
	var mask: int = 0
	for name: String in names:
		if _bit_of.has(name):
			mask |= 1 << _bit_of[name]
	return mask


## The bit numbers of `names`, in their order, skipping any never numbered.
func bits_of(names: PackedStringArray) -> PackedInt32Array:
	var found := PackedInt32Array()
	for name: String in names:
		if _bit_of.has(name):
			found.append(_bit_of[name])
	return found


## `world` as bits.
func state_of(world: WorldState) -> int:
	return mask_of(world.predicates())


## `bits` as a `WorldState` again, for anything that has to be read.
func world_of(bits: int) -> WorldState:
	var holding := PackedStringArray()
	for index: int in range(predicates.size()):
		if bits & (1 << index):
			holding.append(predicates[index])
	return WorldState.new(holding)


## True when action `index` may run in `bits`: every precondition bit is set.
func applicable(index: int, bits: int) -> bool:
	return bits & needs[index] == needs[index]


## The world after action `index` runs in `bits`: deletes first, then adds,
## the same STRIPS order `WorldState.after` keeps, for the same reason.
func after(index: int, bits: int) -> int:
	return (bits & ~removes[index]) | gives[index]


func _number_all(names: PackedStringArray) -> void:
	for name: String in names:
		if not _bit_of.has(name):
			_bit_of[name] = predicates.size()
			predicates.append(name)
