## Something a faction buys once and keeps: a name and a price.
##
## The smallest thing that makes a build order a decision rather than a
## shopping list. Funds spent on an upgrade are funds not spent on units this
## turn, and what the upgrade unlocks (a `UnitType` whose `requires` names it)
## is only worth it if the game lasts long enough to use it. A planner has to
## weigh that; a reflex cannot.
##
## When not to use it: anything with levels, or that can be lost. This is
## owned or not owned, and owned for good.
class_name Upgrade
extends RefCounted

## The name a person reads, and what `UnitType.requires` refers to.
var upgrade_name: String

## What it costs, once.
var cost: int


func _init(name: String, price: int) -> void:
	upgrade_name = name
	cost = price
