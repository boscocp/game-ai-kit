## The boss's decision on screen: its phase, what it does now, a bar that
## fills through the telegraph, and every attack's score with the answers
## behind it -- so a person sees not only the blow but why it was this one.
##
## It draws what `BossBrain.shown()` returns and decides nothing. The fight
## (T157) places it and feeds it once a frame.
##
## When not to use it: a game that shows the telegraph only on the boss's
## body, as a shipped game should; this panel is the teaching overlay.
class_name BossPanel
extends VBoxContainer

## The phase and what the boss is doing.
var heading: Label
## Fills from 0 to 1 through the telegraph window.
var telegraph_bar: ProgressBar
## One line per attack: its score, then each consideration's answer.
var reasons: Label


func _init() -> void:
	heading = Label.new()
	telegraph_bar = ProgressBar.new()
	telegraph_bar.min_value = 0.0
	telegraph_bar.max_value = 1.0
	telegraph_bar.step = 0.01
	telegraph_bar.show_percentage = false
	reasons = Label.new()
	for child: Control in [heading, telegraph_bar, reasons]:
		add_child(child)


## Show `seen`, one `BossBrain.shown()`.
func show_boss(seen: Dictionary) -> void:
	if seen.get("refusal", "") != "":
		heading.text = tr("The boss cannot fight: {why}").format({"why": seen["refusal"]})
		telegraph_bar.value = 0.0
		reasons.text = ""
		return
	heading.text = tr("Phase: {phase} - {state} {attack}").format(
			{"phase": seen["phase"], "state": tr(seen["state"]), "attack": seen["attack"]})
	telegraph_bar.value = seen["telegraph"]
	var lines: PackedStringArray = []
	for reason: Dictionary in seen["reasons"]:
		lines.append(_reason_line(reason))
	reasons.text = "\n".join(lines)


func _reason_line(reason: Dictionary) -> String:
	var parts: PackedStringArray = []
	for percept: String in reason["answers"]:
		parts.append("%s %.2f" % [percept, reason["answers"][percept]])
	return "%s %.2f  (%s)" % [reason["attack"], reason["score"], ", ".join(parts)]
