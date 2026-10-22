## How aware a guard is of one stimulus: a number that rises while it is
## perceived and falls, through every value in between, while it is not.
##
## The Last of Us runs a timer up each frame the player is seen and down
## each frame he is not [McIntosh 2015]; Thief's awareness "decreases across
## some amount of time, passing through all the intermediate states" [Leonard
## 2003]. So this is one number, from 0 to the row's `peak`. It rises by the
## rate it is given -- computed elsewhere, by whatever reads the percept; the
## example uses a fuzzy controller -- and falls at the row's own `decay`.
##
## The **phases** are a reading of the number, not states: thresholds as
## fractions of the peak, in data, as Crysis does [Welsh 2013], and `phase`
## is a pure function of the number and the row. There is no transition
## code. Two rules keep the reading honest:
##
## - falling, one step never leaves more than one phase behind -- it stops at
##   the floor of the phase below -- so every phase in between is passed
##   through, however long the step [Leonard 2003];
## - after an alert, the number stays at or above the row's caution floor
##   for the row's seconds -- Metal Gear's evasion, Shadows' lasting
##   suspicion [Alexander 2009; Ubisoft 2024].
##
## A row: `{"peak": p, "decay": per second as a share of the peak,
## "phases": [{"name": n, "at": share}, ...] lowest first, the first at 0,
## "caution": {"floor": share, "seconds": s}}`. Constant time per step, and
## linear in the phases to read one.
##
## When not to use it: a stimulus that is either there or not with nothing
## to doubt -- a guard shot at. Set the number to the peak and read the phase.
class_name Awareness
extends RefCounted

var value: float = 0.0
## Until when the caution floor holds, in seconds; -INF, never yet alerted.
var caution_until: float = -INF


## One step of `seconds`, ending at `now`. While `perceived`, rise by `rate`
## shares of the peak a second; otherwise fall at the row's decay, no lower
## than the floor of the phase below the current one, nor than the caution
## floor while it holds. Nothing rises on a step with no percept.
func step(row: Dictionary, perceived: bool, rate: float, seconds: float, now: float) -> void:
	var peak: float = float(row["peak"])
	if perceived:
		value = minf(peak, value + maxf(rate, 0.0) * peak * seconds)
	else:
		value = maxf(value - float(row["decay"]) * peak * seconds, lowest_after_falling(row, now))
	if phase(value, row) == (row["phases"] as Array).size() - 1:
		caution_until = now + float(row["caution"]["seconds"])


## How low one falling step may take the number at `now`: the floor of the
## phase below the current one, raised to the caution floor while it holds.
func lowest_after_falling(row: Dictionary, now: float) -> float:
	var below: int = maxi(phase(value, row) - 1, 0)
	var lowest: float = float(row["phases"][below]["at"]) * float(row["peak"])
	if now < caution_until:
		lowest = maxf(lowest, float(row["caution"]["floor"]) * float(row["peak"]))
	return minf(lowest, value)


## The phase `number` is in: the index of the last phase whose threshold,
## as a share of the peak, it has reached.
static func phase(number: float, row: Dictionary) -> int:
	var phases: Array = row["phases"]
	var found: int = 0
	for index: int in range(phases.size()):
		if number >= float(phases[index]["at"]) * float(row["peak"]):
			found = index
	return found


## The name of the phase `number` is in.
static func phase_name(number: float, row: Dictionary) -> String:
	return str(row["phases"][phase(number, row)]["name"])
