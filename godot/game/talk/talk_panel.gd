## The words beside the guard: what he heard, which rule decided, and the talk.
##
## Invariant 13 for a conversation: for each line the player said, the act
## the language model read and its argument -- or the validator's refusal
## and the fallback that stood in -- then the rule that fired and how trust
## and suspicion moved, against the marks that open the door and sound the
## alarm. The decision and what decided it, not only the guard's words.
##
## Static and stateless: `TalkDemo` hands it the guard's turns and state.
##
## When not to use it: for the numbers a test compares, which are the
## turns themselves; these are sentences for a person.
class_name TalkPanel
extends RefCounted

## How many turns the reasoning panel shows, newest last.
const PANEL_TURNS: int = 4
## How many exchanges the conversation shows, newest last.
const HISTORY_TURNS: int = 3

## Each refusal's code, in words a player reads. The validator's own
## sentence is English and names the rule; this says what it means here.
const REFUSALS: Dictionary = {  # shown through tr()
	"R1": "the model's answer was not JSON",
	"R2": "the model's answer was not a JSON object",
	"R3": "the model's answer missed a field",
	"R4": "the model's answer had a field too many",
	"R5": "the model's answer had a field that was not text",
	"R6": "the model named an act the guard does not know",
	"R7": "the model gave the act a value it does not take",
	"R8": "the guard's line was empty or too long",
	"R9": "the guard's line had a line break",
	"R10": "the guard's line had markup in it",
	"R11": "the guard's line gave away the password",
	"F1": "no answer came from the model",
	"F2": "the server refused the request",
}


## The reasoning panel: the last turns, each with its act, rule and numbers.
static func describe(turns: Array[Dictionary], state: Dictionary, language: String) -> String:
	var lines := PackedStringArray([TranslationServer.translate("What the guard heard, and what decided")])
	for index: int in range(maxi(0, turns.size() - PANEL_TURNS), turns.size()):
		lines.append_array(_turn_lines(index + 1, turns[index], language))
	if turns.is_empty():
		lines.append(TranslationServer.translate("Nothing said yet."))
	lines.append("")
	lines.append(TranslationServer.translate("trust {trust} of {open} opens the door; suspicion {suspicion} of {alarm} sounds the alarm").format({
		"trust": state["trust"], "open": int(TalkRules.scene()["open_at"]),
		"suspicion": state["suspicion"], "alarm": int(TalkRules.scene()["alarm_at"])}))
	return "\n".join(lines)


## The conversation's last exchanges, the player's and the guard's.
static func history(turns: Array[Dictionary], pending: String) -> String:
	var lines := PackedStringArray()
	for index: int in range(maxi(0, turns.size() - HISTORY_TURNS), turns.size()):
		lines.append(TranslationServer.translate("You: {line}").format({"line": turns[index]["player"]}))
		lines.append(TranslationServer.translate("Bram: {line}").format({"line": turns[index]["speech"]}))
	if pending != "":
		lines.append(TranslationServer.translate("You: {line}").format({"line": pending}))
		lines.append(TranslationServer.translate("Bram is thinking..."))
	return "\n".join(lines)


## How the conversation ended, or "" while it goes on.
static func outcome(state: Dictionary) -> String:
	match state["outcome"]:
		TalkRules.OPEN:
			return TranslationServer.translate("The door opens: trust reached its mark. You are in.")
		TalkRules.ALARM:
			return TranslationServer.translate("The alarm sounds: suspicion reached its mark. You lost.")
		TalkRules.SENT_AWAY:
			return TranslationServer.translate("Out of turns: the guard sends you away. You lost.")
	return ""


# One turn in three lines: the line, what the model read, the rule.
static func _turn_lines(number: int, turn: Dictionary, language: String) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("%d. \"%s\"" % [number, turn["player"]])
	var seconds: String = Language.decimal(float(turn["seconds"]), 2)
	if turn["refusal_code"] == "":
		lines.append("   " + TranslationServer.translate("the model read: {act}  ({seconds} s)").format({
			"act": TalkRules.act_of(turn["intent"], turn["argument"]), "seconds": seconds}))
	else:
		lines.append("   " + TranslationServer.translate("refused, {code}: {why}; the guard's own line stood in").format({
			"code": turn["refusal_code"],
			"why": TranslationServer.translate(REFUSALS.get(turn["refusal_code"], ""))}))
	lines.append("   " + TranslationServer.translate("rule {rule}: {why}").format({
		"rule": turn["rule"], "why": TalkRules.why_of(turn["rule"], language)}))
	lines.append("   " + TranslationServer.translate("trust {moved_trust} = {trust}, suspicion {moved_suspicion} = {suspicion}").format({
		"moved_trust": "%+d" % turn["trust_moved"], "trust": turn["trust"],
		"moved_suspicion": "%+d" % turn["suspicion_moved"], "suspicion": turn["suspicion"]}))
	return lines
