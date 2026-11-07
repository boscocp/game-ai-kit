## The words beside the fight: the frame, and for each fighter its move, the
## frame of it, its phase and the frame data behind it, its stun and what it
## has buffered -- and what happened on the frame, and, with an opponent in
## the dummy's place, what it saw and what it drew.
##
## The frame data is written out next to the frame number on purpose: "jab,
## frame 7 of 20, active (startup 6, active 3, recovery 11)" is the sentence
## a person reads a fighting game's frame data in.
##
## When not to use it: during play at full speed. It is for a paused frame.
##
## Every sentence is one key with named placeholders (T80); the names in it
## and the frame's events are translated where they are shown
## (`FightWords`). A move's name and the frame data's terms stay as fighting
## games say them.
class_name FightingPanel
extends RefCounted

## How many rows of a learner's table the panel prints.
const ROWS_SHOWN: int = 8
## How many of a forest's votes go on one line: 25 trees are five lines.
const VOTES_PER_LINE: int = 5
## The longest a bandit's bar is drawn, in characters, a tenth of payoff
## each: a mean of 1 and an exploration term of 1.5.
const BAR_LONGEST: int = 25
## What the learner expected at its last decision: with an answer among its
## options, and without one.
## What the learner was expecting when it drew, with an answer among its
## options and without one.
const EXPECTING: Array[String] = [  # shown through tr()
	"(expecting {action}, {percent}%)",
	"(expecting {action}, {percent}%, no answer among its options)",
]
const EXPECTED: Array[String] = [  # shown through tr()
	"  at its last decision, after {after} it expected {action}, {percent}%",
	"  at its last decision, after {after} it expected {action}, {percent}% -- none of its options answers that",
]
## One test of the tree's path, by the kind of test: a word compared, or a
## number held to a threshold. `{went}` is one of `WENT`, the
## way the test sent the walk.
const TREE_TESTS: Array[String] = [  # shown through tr()
	"  {feature} is {word}? it read {seen}: {went}",
	"  {feature} at most {word}? it read {seen}: {went}",
]
const WENT: Array[String] = ["yes", "no"]  # shown through tr()


## The panel for `state`.
## `seat` holds the opponent in the dummy's place, or is null for a scripted dummy.
static func describe(state: FightState, data: FightData, paused: bool, seat: FightDelay = null) -> String:
	var heading: String = "frame {frame}  ·  paused" if paused else "frame {frame}"  # shown through tr()
	var lines: PackedStringArray = [TranslationServer.translate(heading).format({frame = state.frame}), ""]
	for index: int in range(2):
		lines.append_array(_fighter_lines(index, state.fighters[index], data))
		lines.append("")
	lines.append(TranslationServer.translate("this frame: {events}").format({events = FightWords.events(state.events)
		if not state.events.is_empty() else TranslationServer.translate("nothing connected")}))
	if seat != null:
		lines.append_array(_opponent_lines(state, seat))
	if state.winner != FightState.NOBODY:
		lines.append(TranslationServer.translate("DRAW") if state.winner == FightState.DRAW
			else TranslationServer.translate("PLAYER {number} WINS").format({number = state.winner + 1}))
	return "\n".join(lines)


static func _fighter_lines(index: int, fighter: FighterState, data: FightData) -> PackedStringArray:
	var lines: PackedStringArray = [TranslationServer.translate("player {number}, the {character}: {health} health").format({
		number = index + 1, character = fighter.character, health = fighter.health})]
	if fighter.is_airborne():
		lines.append(TranslationServer.translate("  in the air, frame {frame} of {frames}, {up} up").format({frame = fighter.jump_frame,
			frames = data.jump_length(fighter.character), up = fighter.y}))
	if fighter.stun_kind == FightBackdash.KIND:
		lines.append(_backdash_line(fighter, data))
	elif fighter.stun > 0 and fighter.stun_kind in ["takeoff", "landing"]:
		var taking_off: bool = fighter.stun_kind == "takeoff"
		var doing: String = "  taking off, {frames} frame(s) left" if taking_off else "  landing, {frames} frame(s) left"  # shown through tr()
		lines.append(TranslationServer.translate(doing).format({frames = fighter.stun}))
	elif fighter.stun > 0:
		lines.append(TranslationServer.translate("  in {kind}stun, {frames} frame(s) left").format({kind = fighter.stun_kind, frames = fighter.stun}))
	elif fighter.move != "":
		lines.append_array(_move_lines(fighter, data))
	elif not fighter.is_airborne():
		lines.append(TranslationServer.translate("  free to act, crouching") if fighter.crouching else TranslationServer.translate("  free to act"))
	if fighter.buffered != "":
		lines.append(TranslationServer.translate("  buffered: {move}, until frame {frame}").format({move = fighter.buffered,
			frame = fighter.buffered_until}))
	return lines


# The backdash, the frame of it, and which part: the frames nothing finds it,
# or the ones it cannot guard -- with the frame data, as a move's is shown.
static func _backdash_line(fighter: FighterState, data: FightData) -> String:
	var backdash: Dictionary = data.character(fighter.character)["backdash"]
	var part: String = TranslationServer.translate("strikes and throws pass through") if FightBackdash.invulnerable(fighter, data) \
			else TranslationServer.translate("cannot guard, can be thrown")
	return TranslationServer.translate("  evading, frame {frame} of {frames}: {part} (invulnerable {invulnerable}, travel {travel})").format({
		frame = FightBackdash.frame_of(fighter, data), frames = backdash["frames"], part = part,
		invulnerable = backdash["invulnerable"], travel = backdash["travel"]})


# The move, the frame of it, its phase, and the frame data it is read against.
static func _move_lines(fighter: FighterState, data: FightData) -> PackedStringArray:
	var frames: Dictionary = data.move(fighter.character, fighter.move)
	var length: int = data.length_of(fighter.character, fighter.move)
	var phase: String = FightBoxes.phase(fighter, data)
	return PackedStringArray([
		"  %s, frame %d of %d, %s" % [fighter.move, fighter.move_frame, length, phase],  # not shown as words: frame data's notation
		TranslationServer.translate("  {stance} {button}, hits {height}").format({stance = FightWords.word(frames["stance"]),
			button = FightWords.word(frames["button"]), height = FightWords.word(frames["height"])}),
		"  (startup %d, active %d, recovery %d)" % [frames["startup"], frames["active"], frames["recovery"]],  # not shown as words: frame data's notation
	])


# The opponent's last decision, with how old the fight it saw was: the
# number a person checks it against. The reaction is the seat's, which is
# the one enforced; a refused opponent says why.
static func _opponent_lines(state: FightState, seat: FightDelay) -> PackedStringArray:
	var opponent: FightOpponent = seat.opponent
	var lines: PackedStringArray = ["", TranslationServer.translate("the opponent ({level}), seeing {frames} frames late:").format({
		level = FightWords.word(opponent.level), frames = seat.reaction})]
	if seat.refusal != "":
		lines.append(TranslationServer.translate("  refused: {why}").format({why = seat.refusal}))
		return lines
	if opponent.seen_frame < 0:
		lines.append(TranslationServer.translate("  has not seen the fight yet"))
		return lines
	lines.append(TranslationServer.translate("  saw frame {frame}, {ago} frames ago: {situation}").format({frame = opponent.seen_frame,
		ago = state.frame - opponent.seen_frame, situation = FightWords.word(opponent.situation)}))
	lines.append(TranslationServer.translate("  drew: {choice}").format({choice = _drew(opponent)}))
	var voter := opponent as FightForestOpponent
	var reader := opponent as FightTreeOpponent
	var learner := opponent as FightModelOpponent
	if voter != null:
		lines.append_array(_forest_lines(voter))
	elif reader != null:
		lines.append_array(_tree_lines(reader))
	elif learner != null:
		lines.append_array(_model_lines(learner))
	var imitator := opponent as FightCloneOpponent
	if imitator != null:
		lines.append_array(_clone_lines(imitator))
	var gambler := opponent as FightBanditOpponent
	if gambler != null:
		lines.append_array(_bandit_lines(gambler))
	return lines


# The bandit of the situation it just named, one line an option, as it
# stood when it chose: its pulls, its mean payoff and its UCB1 bound, as
# numbers and as a bar -- `#` for the mean, `+` for the exploration term on
# top of it -- the chosen one marked `>` before it is played. The numbers
# are the ones the choice was made from, so the marked one has the highest
# bound. Then the last option paid, and what it earned.
static func _bandit_lines(gambler: FightBanditOpponent) -> PackedStringArray:
	var bandit: Bandit = gambler.current_bandit()
	if bandit == null:
		return PackedStringArray()
	var pulled: int = 0
	for row: Dictionary in gambler.chosen_from:
		pulled += int(row["pulls"])
	var lines: PackedStringArray = ["", TranslationServer.translate(
		"its bandit for {situation} (UCB1, exploration {exploration}), {pulls} pull(s); # mean, + exploration:").format({
		situation = FightWords.word(gambler.situation), exploration = "%.2f" % bandit.exploration, pulls = pulled})]
	for arm: int in range(gambler.chosen_from.size()):
		var row: Dictionary = gambler.chosen_from[arm]
		var mark: String = ">" if arm == gambler.chosen_arm else " "  # not shown: a mark
		var option: String = FightWords.word(row["option"])
		if int(row["pulls"]) == 0:
			lines.append("  %s %s: " % [mark, option] + TranslationServer.translate("never tried, so tried first"))
			continue
		lines.append("  %s %s: " % [mark, option] + TranslationServer.translate(
			"{pulls} pull(s), mean {mean}, bound {bound}").format({pulls = row["pulls"],
			mean = "%.2f" % row["mean"], bound = "%.2f" % row["bound"]}) + "  " + _bar(row))
	if not gambler.last_paid.is_empty():
		lines.append(TranslationServer.translate("  last paid: {option} after {situation}, {payoff}").format({
			option = FightWords.word(gambler.last_paid["option"]), situation = FightWords.word(gambler.last_paid["situation"]),
			payoff = "%.2f" % gambler.last_paid["payoff"]}))
	return lines


# An arm's bound as a bar, a tenth a character: its mean in `#`, then the
# exploration term in `+`, cut at `BAR_LONGEST` so an arm pulled once does
# not run off the panel.
static func _bar(row: Dictionary) -> String:
	var mean: int = roundi(float(row["mean"]) * 10.0)
	var bonus: int = mini(roundi((float(row["bound"]) - float(row["mean"])) * 10.0), BAR_LONGEST - mean)
	return "#".repeat(mean) + "+".repeat(bonus)


# What the opponent drew, worded from its decision's identifiers -- the
# option, how execution spoilt it, the move or the step in, and what a
# learner expected -- in the language on screen. Its `choice` is the same in
# English.
static func _drew(opponent: FightOpponent) -> String:
	if opponent.drawn == "":
		return FightWords.word(opponent.choice)
	var said: String = FightWords.word(opponent.drawn)
	if opponent.late:
		said += " " + TranslationServer.translate("(fumbled: late)")
	if opponent.came_out_as != "":
		said += " " + TranslationServer.translate("(fumbled: came out as {action})").format({
			action = FightWords.word(opponent.came_out_as)})
	if opponent.stepped_in:
		said += TranslationServer.translate(", out of reach: steps in")
	elif opponent.struck_with != "":
		said += " -- " + opponent.struck_with
	var learner := opponent as FightModelOpponent
	if learner != null:
		said += " " + TranslationServer.translate(EXPECTING[0 if learner.answered else 1]).format({
			action = FightWords.word(learner.expected), percent = roundi(learner.confidence * 100.0)})
	return said


# The learner's table, as it stands: what it expects, from which context,
# how often its guesses have been right, and the rows it has counted --
# the most useful thing on the screen to read while you change your habits.
static func _model_lines(learner: FightModelOpponent) -> PackedStringArray:
	var score: Array[int] = learner.score()
	var context: String = learner.model.context()
	var lines: PackedStringArray = ["", TranslationServer.translate("its model (order {order}, decay {decay}), right {right} of its last {last}:").format({
		order = learner.model.order, decay = "%.2f" % learner.model.decay, right = score[0], last = score[1]})]
	var after: String = FightWords.context(learner.expected_after) if learner.expected_after != "" \
		else TranslationServer.translate("nothing")
	lines.append(TranslationServer.translate(EXPECTED[0 if learner.answered else 1]).format({after = after,
		action = FightWords.word(learner.expected), percent = roundi(learner.confidence * 100.0)}))
	var now: String = FightWords.context(context) if context != "" else TranslationServer.translate("nothing yet")
	lines.append(TranslationServer.translate("  now the context is {context}").format({context = now}))
	var rows: PackedStringArray = learner.model.rows()
	for row: String in rows.slice(0, ROWS_SHOWN):
		lines.append("  " + FightWords.row(row))
	if rows.size() > ROWS_SHOWN:
		lines.append(TranslationServer.translate("  ... and {count} more").format({count = rows.size() - ROWS_SHOWN}))
	return lines


# Whom it imitates and what it saw in the recordings' words -- the situation
# its answers were looked up or computed for -- where they came from, and
# what it drew among, heaviest first.
static func _clone_lines(imitator: FightCloneOpponent) -> PackedStringArray:
	var player: ClonedPlayer = imitator.player
	if not player.is_loaded():
		return PackedStringArray(["", TranslationServer.translate("it imitates nobody: {why}").format({why = player.error})])
	var recordings: int = player.trained_on.get("recordings", []).size()
	var lines: PackedStringArray = ["", TranslationServer.translate("it imitates {player}, from {count} recording(s):").format({
		player = player.trained_on["player"], count = recordings})]
	if imitator.seen_situation.is_empty():
		lines.append(TranslationServer.translate("  has decided nothing yet"))
		return lines
	lines.append("  " + player.cases.key_of(imitator.seen_situation))
	lines.append("  (%s)" % " | ".join(FightSituation.FEATURES))
	var found: String = Sentence.translated(imitator.found_said, FightWords.word)
	if imitator.guards_instead:
		found += TranslationServer.translate("; nothing it can do, so it guards")
	lines.append(TranslationServer.translate("  {found}; drew among:").format({found = found}))
	var weighed: Array = imitator.considered.duplicate()
	weighed.sort_custom(func(one: Array, other: Array) -> bool: return one[1] > other[1])
	var cells: PackedStringArray = []
	for option: Array in weighed.slice(0, 5):
		cells.append("%s %d" % [FightWords.word(option[0]), option[1]])
	lines.append("  " + ", ".join(cells))
	return lines


# The tree's last reading, top to bottom (T113): each test it asked about
# your situation, the word it read there and which way it went, the leaf it
# ended at with the rows that reached it there, and what it expects --
# beside what the n-gram expects, and how often each has been right.
static func _tree_lines(reader: FightTreeOpponent) -> PackedStringArray:
	if reader.reader == null:
		return PackedStringArray(["", TranslationServer.translate("it reads you with no tree: {why}").format({why = TranslationServer.translate(reader.refusal)})])
	var tree_score: Array[int] = reader.tree_score()
	var ngram_score: Array[int] = reader.ngram_score()
	var lines: PackedStringArray = ["", TranslationServer.translate(
		"its decision tree, right {right} of its last {last}; the n-gram, asked at the same decisions, {ngram_right} of {ngram_last}:").format({
		right = tree_score[0], last = tree_score[1], ngram_right = ngram_score[0], ngram_last = ngram_score[1]})]
	if reader.walked.is_empty():
		lines.append(TranslationServer.translate("  has read nothing yet"))
		return lines
	for step: Dictionary in reader.walked:
		lines.append(_tree_step(step, reader.reader.classes))
	lines.append(TranslationServer.translate("  so it expects {action}, {percent}%; the n-gram expects {ngram}, {ngram_percent}%").format({
		action = FightWords.word(reader.expected), percent = roundi(reader.confidence * 100.0),
		ngram = FightWords.word(reader.ngram_expected), ngram_percent = roundi(reader.ngram_confidence * 100.0)}))
	return lines


# One step of the path: a test and which way it went, the test it could
# not read, or the leaf and its counts, the heaviest first -- of equal
# counts, in `classes` order, the order the tree settles a tie in.
static func _tree_step(step: Dictionary, classes: PackedStringArray) -> String:
	if step.has("counts"):
		return TranslationServer.translate("  leaf: {counts}").format({counts = _heaviest_first(step["counts"], classes)})
	var values: Dictionary = {feature = step["feature"], word = FightWords.word(str(step["against"])),
		seen = FightWords.word(str(step["seen"]))}
	if step["went"] == LearnedTree.UNREAD:
		return TranslationServer.translate("  {feature}: it read {seen}, which it cannot test -- the walk stops").format(values)
	values["went"] = TranslationServer.translate(WENT[0 if step["went"] == LearnedTree.YES else 1])
	return TranslationServer.translate(TREE_TESTS[0 if step["test"] == "is" else 1]).format(values)


# Counts by answer, written heaviest first -- of equal counts, in `classes`
# order, the order a tree settles a tie in, and a forest its vote.
static func _heaviest_first(counts: Dictionary, classes: PackedStringArray) -> String:
	var names: Array = Array(classes).filter(func(name: String) -> bool: return counts.has(name))
	names.sort_custom(func(one: String, other: String) -> bool:
		return counts[one] > counts[other] or (counts[one] == counts[other] and classes.find(one) < classes.find(other)))
	var cells: PackedStringArray = []
	for name: String in names:
		cells.append("%s %d" % [FightWords.word(name), counts[name]])
	return ", ".join(cells)


# The forest's last vote (T114): every tree's vote, `VOTES_PER_LINE` to a
# line, "-" for a tree that could not read your situation; the tally; and
# what it expects, beside what the n-gram expects and how often each has
# been right at the same decisions.
static func _forest_lines(voter: FightForestOpponent) -> PackedStringArray:
	if voter.forest == null:
		return PackedStringArray(["", TranslationServer.translate("it reads you with no forest: {why}").format({why = TranslationServer.translate(voter.refusal)})])
	var score: Array[int] = voter.forest_score()
	var ngram_score: Array[int] = voter.ngram_score()
	var lines: PackedStringArray = ["", TranslationServer.translate(
		"its random forest of {trees} trees, right {right} of its last {last}; the n-gram, asked at the same decisions, {ngram_right} of {ngram_last}:").format({
		trees = voter.forest.trees.size(), right = score[0], last = score[1], ngram_right = ngram_score[0], ngram_last = ngram_score[1]})]
	if voter.cast.is_empty():
		lines.append(TranslationServer.translate("  has read nothing yet"))
		return lines
	for first: int in range(0, voter.cast.size(), VOTES_PER_LINE):
		var votes: PackedStringArray = []
		for vote: String in voter.cast.slice(first, first + VOTES_PER_LINE):
			votes.append(FightWords.word(vote) if vote != "" else "-")
		lines.append(TranslationServer.translate("  trees {first} to {last} voted: {votes}").format({first = first + 1,
			last = first + votes.size(), votes = ", ".join(votes)}))
	lines.append(TranslationServer.translate("  tally: {counts}").format({counts = _heaviest_first(voter.tally, voter.forest.classes)}))
	lines.append(TranslationServer.translate("  so it expects {action}, {percent}% of the votes; the n-gram expects {ngram}, {ngram_percent}%").format({
		action = FightWords.word(voter.expected), percent = roundi(voter.confidence * 100.0),
		ngram = FightWords.word(voter.ngram_expected), ngram_percent = roundi(voter.ngram_confidence * 100.0)}))
	return lines
