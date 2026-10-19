## One thing a GOAP agent can do: what must hold, what it makes hold, and what
## it costs.
##
## STRIPS's action with Orkin's changes for F.E.A.R. (`docs/concepts/
## planning-in-strategy-games.md`): facts are named values rather than present
## or absent, so one effect both adds and deletes, and every action has a
## cost, so the planner prefers the cheap way to the short one.
##
## When not to use it: an effect that depends on the world it runs in. That
## is a procedural effect, which F.E.A.R. had and this teaching version does
## not.
class_name GoapAction
extends RefCounted

## What it is called, in a plan and on screen.
var name: String
## What it costs to do; never below 1, so the planner's guess stays honest.
var cost: int
## Fact -> the value it must have first.
var preconditions: Dictionary
## Fact -> the value it has afterwards.
var effects: Dictionary


func _init(action_name: String, price: int, needs: Dictionary, makes: Dictionary) -> void:
	name = action_name
	cost = maxi(price, 1)
	preconditions = needs
	effects = makes
