# Measure the director on the infiltration level (T90): over seeded runs
# of the scripted players T70's properties use, and one that lies still and
# throws distractions, on the two hand-made levels and generated ones --
# how long it spends in each phase, how often the intensity peaks, how
# often it relaxes, and how many patrols it sends and calls back.
#
#     ./scripts/godot --headless --path godot -s res://test/infiltration/director_measure.gd
#
# Prints one line a run and the totals. Exit codes: 0 some run relaxed, 1
# none did -- a director whose relax is never reached on any level has a
# phase nobody will see.
extends SceneTree

const PLAYERS: Array[String] = ["hide", "quiet", "distract"]
## The generated levels beyond the properties' three.
const MORE_GENERATED: Array[int] = [4, 5, 6, 7, 8, 9, 10, 11]
## Five minutes a run at most: one relax alone is thirty seconds.
const STEPS: int = 3000


func _init() -> void:
	var levels: Array[InfiltrationLevel] = InfiltrationRuns.levels()
	for seed_value: int in MORE_GENERATED:
		levels.append(InfiltrationLevel.read(LevelGenerator.make(seed_value), "generated %d" % seed_value))
	var totals: Dictionary = {}
	var counted: Dictionary = {"runs": 0, "peaks": 0, "relaxes": 0, "sent": 0, "recalled": 0}
	for level: InfiltrationLevel in levels:
		for mode: String in PLAYERS:
			var run: Dictionary = DirectorRuns.run(level, mode, STEPS)
			print(DirectorRuns.line(run))
			_add(run, totals, counted)
	print("director over %d runs: seconds in each phase %s; %s" % [counted["runs"], totals, counted])
	quit(0 if int(counted["relaxes"]) > 0 else 1)


func _add(run: Dictionary, totals: Dictionary, counted: Dictionary) -> void:
	counted["runs"] = int(counted["runs"]) + 1
	for key: String in ["peaks", "relaxes", "sent", "recalled"]:
		counted[key] = int(counted[key]) + int(run[key])
	for phase: String in run["seconds"]:
		totals[phase] = snappedf(float(totals.get(phase, 0.0)) + float(run["seconds"][phase]), 0.1)
