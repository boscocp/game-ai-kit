## What the player asks for in one step: where to go, how to hold the body,
## and whether to throw, take a guard down or shoot.
##
## The demo fills it from the keyboard and mouse, the properties from a
## script; the world reads nothing else of the player's wishes, so a
## scripted run is the same game a person plays.
##
## When not to use it: for a guard. A guard's wishes are its chosen action.
class_name PlayerIntent
extends RefCounted

## Floor direction, x east and y south, length at most 1.
var direction: Vector2 = Vector2.ZERO
var stance: String = "standing"  # not shown: an identifier
var sprint: bool = false
## Where a distraction is thrown to, or INF: nothing thrown.
var throw_at: Vector2 = Vector2.INF
var takedown: bool = false
## The direction a shot goes, from the eyes, or ZERO: no shot.
var shoot: Vector3 = Vector3.ZERO
## Open the nearest door within reach, or shut it if it is open (T115).
var use_door: bool = false
