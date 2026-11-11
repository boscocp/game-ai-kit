## What the player wants this step: where to walk, and the one-shot wishes
## -- a light attack, a dodge, the lock-on toggled -- plus where the camera
## stands and looks, on the ground, which the rings need for "never behind
## the camera". The keyboard fills one; a test's scripted player fills one.
class_name BossFightIntent
extends RefCounted

## Where to walk, on the ground, length at most 1.
var direction: Vector2 = Vector2.ZERO
var attack: bool = false
var dodge: bool = false
var toggle_lock: bool = false
## The camera's place and its forward direction on the ground.
var view_from: Vector2 = Vector2.ZERO
var view_forward: Vector2 = Vector2.UP
