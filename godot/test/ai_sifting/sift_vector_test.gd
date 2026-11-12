# The sifting vector's rules, each refusing a planted case, and two planted
# sifters -- one that lets two names find the same event, one that forgets
# `unless` -- each failing the vectors it must.
extends GdUnitTestSuite

const DIRECTORY: String = "../spec/vectors/sifting"


## Every name may find any event, the one another name found included.
class OneEventTwice extends StorySifter:
	func _extend(events: Array, pattern: Dictionary, found: Dictionary, bound: Dictionary,
			matches: Array[Dictionary]) -> void:
		var clauses: Array = pattern["find"]
		if found.size() == clauses.size():
			matches.append({"events": found.duplicate(), "bindings": bound.duplicate()})
			return
		var clause: Dictionary = clauses[found.size()]
		for index: int in range(events.size()):
			var binds: Variant = StorySifter.bindings_if_matches(events[index], clause["where"], bound)
			if binds != null:
				found[clause["as"]] = index
				_extend(events, pattern, found, binds, matches)
				found.erase(clause["as"])


## Never finds an event that must not be there.
class NoUnless extends StorySifter:
	func _absent_found(_events: Array, _pattern: Dictionary, _found: Dictionary, _bound: Dictionary) -> bool:
		return false


func _directory() -> String:
	return ProjectSettings.globalize_path("res://").path_join(DIRECTORY)


func _vector(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_directory().path_join(name + ".json")))


func _names() -> Array[String]:
	var names: Array[String] = []
	for file: String in DirAccess.get_files_at(_directory()):
		if file.ends_with(".json"):
			names.append(file.get_basename())
	return names


func test_the_directory_holds_every_rule() -> void:
	var refused: Array[String] = []
	for name: String in _names():
		var rule: String = _vector(name)["refused"]
		if rule != "" and not rule in refused:
			refused.append(rule)
	refused.sort()
	assert_int(_names().size()).is_greater_equal(15)
	assert_array(refused).is_equal(SiftVector.RULES)


func test_the_vectors_are_vectors_and_hold() -> void:
	for name: String in _names():
		var vector: Dictionary = _vector(name)
		assert_str(SiftVector.why_not_a_vector(vector)).override_failure_message(name).is_empty()
		assert_array(SiftVector.wrong_claims(vector, StorySifter.new())).override_failure_message(name).is_empty()


func test_a_broken_vector_is_refused_by_its_rule() -> void:
	var sound: Dictionary = _vector("every-later-repair")
	var changes: Array[Array] = [["V1", "match", []], ["V2", "refused", "P9"], ["V3", "refused", "P1"],
			["V4", "matches", [{"events": {"down": 4}, "bindings": {}}]],
			["V5", "matches", [{"events": {"down": 4, "up": 99}, "bindings": {}}]]]
	for change: Array in changes:
		var broken: Dictionary = sound.duplicate(true)
		broken[change[1]] = change[2]
		assert_str(SiftVector.why_not_a_vector(broken)).override_failure_message(change[0]).starts_with(change[0])


# T121: a list given as text, in a copy of a real file, must be refused
# before anything casts it.
func test_a_vector_of_the_wrong_types_is_refused_before_it_is_read() -> void:
	var vector: Dictionary = _vector("the-third-time")
	var paths: Array = [["events"], ["events", 0], ["pattern"], ["matches"], ["matches", 0, "events"],
			["matches", 0, "events", "first"], ["refused"]]
	for path: Array in paths:
		var why: String = SiftVector.why_not_a_vector(VectorShape.planted(vector, path, "x" if path != ["refused"] else 1))
		assert_str(why).override_failure_message(str(path)).starts_with("V8")


func test_a_sifter_that_lets_two_names_find_one_event_fails() -> void:
	assert_array(SiftVector.wrong_claims(_vector("two-events-are-two-events"), OneEventTwice.new())).is_not_empty()


func test_a_sifter_that_forgets_unless_fails() -> void:
	for name: String in ["unless-between-keeps-the-next-one", "the-third-time", "unless-after-never-again"]:
		var wrong: Array[String] = SiftVector.wrong_claims(_vector(name), NoUnless.new())
		assert_array(wrong).override_failure_message(name).is_not_empty()
