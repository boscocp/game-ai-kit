## A difficulty level in the words of the screen's language: the header's
## "blue is played by easy: plans 0 actions ahead, ..." in pt-BR as well.
##
## `Difficulty` lives in `ai_planning`, an addon, and an addon has no
## translation table: it depends on `ai_core` and nothing else (invariant 2),
## not on a game's locale, and no addon here calls `tr()`. So
## `Difficulty.describe()` stays English -- for the logs, the measurements and
## `difficulty_knobs.gd` -- and the tactical game, which shows it, copies its
## sentence as keys its own table translates. The behaviour demo does the
## same with the addon English it shows (docs/godot/localisation.md).
##
## A copy can drift from what it copies without a sound, so
## `test/tactical/difficulty_words_test.gd` holds it to the addon: in English
## the two say the same thing, and a field added to `Difficulty` that this
## does not word fails there.
##
## When not to use it: in a log or a gate, which want the English that does
## not change with the language -- that is `Difficulty.describe()`.
class_name DifficultyWords
extends RefCounted

## Every field of `Difficulty` the sentence says. The test holds this list to
## the class's own fields, so a new knob cannot reach the screen unworded.
const FIELDS: Array[String] = ["name", "plan_horizon", "search_depth", "evaluation_noise"]  # not shown


## `level` in one line, in the language on screen: its name and its three
## knobs, the sentence `Difficulty.describe()` writes in English. The name is
## said as the roster says it, whose rows the table already holds.
static func said(level: Difficulty) -> String:
	var horizon: String = TranslationServer.translate("any length")
	if level.plan_horizon != HeuristicPlanner.NO_HORIZON:
		horizon = TranslationServer.translate("{count} actions").format({count = level.plan_horizon})
	return TranslationServer.translate("{level}: plans {horizon} ahead, searches {depth} ply/plies, noise {noise}").format({
		level = TacticalStatus.name_said(level.name), horizon = horizon, depth = level.search_depth,
		noise = Language.decimal(level.evaluation_noise, 2)})
