## One producer's order for one new unit, placed on one cell beside it.
##
## Its own type and not a flag on `Move`, as `move.gd` asks: a walk and a
## purchase are judged by different rules -- a walk by the ground, a purchase
## by the funds -- and one type holding both is where a board state turns into
## a switch statement.
##
## When not to use it: queues, or production that takes turns. An order here
## is placed and filled in the same instant.
class_name ProductionOrder
extends RefCounted

## The building that makes it.
var producer_id: int

## What it makes.
var unit_type: UnitType

## Where the new unit appears: a free cell one step from the producer.
var cell: Vector2i


func _init(producer: int, kind: UnitType, at: Vector2i) -> void:
	producer_id = producer
	unit_type = kind
	cell = at
