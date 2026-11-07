# T114: a random forest read back through the model file, and asked for its votes.
# The votes' numbers are the vectors' (`make test-forest-vectors`); these hold
# what a game relies on beside them: the kinds kept apart, the trees built
# whole, an abstaining tree left out of the tally, and a tie by `classes`.
extends GdUnitTestSuite

const SPLIT: Array = [{"feature": "distance", "is": "close", "yes": 1, "no": 2}, {"counts": {"low": 3.0}},
	{"counts": {"high": 2}}]
const FOREST: Dictionary = {"kind": "forest", "features": ["distance", "health"], "classes": ["high", "low"],
	"trees": [SPLIT, [{"counts": {"high": 1, "low": 4}}], [{"feature": "health", "at_most": 2.5, "yes": 1, "no": 2},
		{"counts": {"high": 5}}, {"counts": {"low": 1}}]]}


func _published() -> ModelFile:
	return ModelFile.from_dictionary({"models": {"votes": FOREST,
		"chance": {"kind": "logistic", "features": ["one"], "weights": [1.0], "bias": 0.0}}}, "the test")


func test_a_forest_is_found_by_its_own_kind() -> void:
	var published: ModelFile = _published()
	assert_str(published.error).is_empty()
	assert_object(published.forest("votes")).is_not_null()
	assert_object(published.tree("votes")).is_null()
	assert_object(published.model("votes")).is_null()
	assert_object(published.forest("chance")).is_null()
	assert_array(published.model_names()).contains_exactly(["chance", "votes"])


func test_every_tree_is_built_whole_with_the_forest_s_features_and_classes() -> void:
	var forest: LearnedForest = _published().forest("votes")
	assert_int(forest.trees.size()).is_equal(3)
	for tree: LearnedTree in forest.trees:
		assert_array(Array(tree.classes)).is_equal(["high", "low"])
		assert_array(Array(tree.features)).is_equal(["distance", "health"])
	assert_int(typeof(forest.trees[0].nodes[1]["counts"]["low"])).is_equal(TYPE_INT)


func test_each_tree_votes_and_the_most_votes_win() -> void:
	var forest: LearnedForest = _published().forest("votes")
	var cast: PackedStringArray = forest.votes({"distance": "close", "health": 1})
	assert_array(Array(cast)).is_equal(["low", "low", "high"])
	assert_dict(forest.tally_of(cast)).is_equal({"high": 1, "low": 2})
	assert_str(forest.likeliest({"distance": "close", "health": 1})).is_equal("low")
	assert_float(forest.shares_of(forest.tally_of(cast))["low"]).is_equal_approx(2.0 / 3.0, 0.0001)


# A split vote's shares are of the votes cast, every answer named, the
# unvoted ones at zero -- what the learner leans by.
func test_a_split_vote_s_shares_are_of_the_votes_cast() -> void:
	var forest: LearnedForest = _published().forest("votes")
	assert_dict(forest.shares_of({"high": 1, "low": 3})).is_equal({"high": 0.25, "low": 0.75})
	assert_dict(forest.shares_of({"low": 2})).is_equal({"high": 0.0, "low": 1.0})


# A tree that cannot read the situation abstains: it is not counted as a
# vote for anything, and the shares are of the votes actually cast.
func test_a_tree_that_cannot_read_abstains() -> void:
	var forest: LearnedForest = _published().forest("votes")
	var cast: PackedStringArray = forest.votes({"distance": 7, "health": 1})
	assert_array(Array(cast)).is_equal(["", "low", "high"])
	assert_dict(forest.tally_of(cast)).is_equal({"high": 1, "low": 1})
	assert_dict(forest.shares_of({})).is_empty()


# The planted case for the tie rule: one vote each, and the first voter
# said low -- but high comes first in `classes`, and wins.
func test_a_tie_goes_to_the_first_in_classes_not_to_the_first_voter() -> void:
	var forest: LearnedForest = _published().forest("votes")
	assert_str(forest.likeliest({"distance": 7, "health": 1})).is_equal("high")
	assert_str(forest.likeliest_in({"low": 1, "high": 1})).is_equal("high")
	assert_str(forest.likeliest_in({})).is_equal("")
