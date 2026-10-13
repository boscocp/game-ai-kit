"""The text reader: what it reads, and a refusal for each thing it will not.

The original reader skipped a condition naming a set it could not find and
kept the rule, which is how a misspelling quietly makes a rule broader. Every
test below expecting a refusal matches the *sentence* of the rule it is
about, not only its code: about a dozen refusals share `F9`, and a review
found three tests passing because a different one of them fired.
"""

import unittest

from gameaikit.fuzzy import FuzzyError, read_fcl

SMALL = """
VAR_INPUT
    noise
END
VAR_OUTPUT
    alertness
END
FUZZIFY noise
    RANGE = 0,10
    quiet = 0,0,2,6
    loud = 4,8,10
END
DEFUZZIFY alertness
    RANGE = 0,100
    SAMPLES = 11
    calm = 0,0,20,50
    alarmed = 50,80,100,100
END
RULEBLOCK
    RULE 1 = IF noise IS quiet THEN alertness IS calm
    RULE 2 = IF noise IS loud OR noise IS quiet THEN alertness IS alarmed
END
"""


def but(old: str, new: str) -> str:
    """The small file with one passage changed, so each test names its defect.

    The passage must occur exactly once. `RANGE = 0,10` also matches the
    output's `RANGE = 0,100`, and a replacement that changed both blocks once
    let a test pass for a reason it did not name.
    """
    if SMALL.count(old) != 1:
        raise AssertionError(f"the fixture holds {old!r} {SMALL.count(old)} times, not once")
    return SMALL.replace(old, new)


class ReadsTests(unittest.TestCase):
    def test_the_small_file_reads(self) -> None:
        controller = read_fcl(SMALL)
        self.assertEqual([one.name for one in controller.inputs], ["noise"])
        self.assertEqual(controller.outputs[0].samples, 11)
        self.assertEqual(controller.rules[1].connective, "or")
        self.assertEqual(controller.rules[1].conditions, (("noise", "loud"), ("noise", "quiet")))

    def test_keywords_are_read_in_any_case(self) -> None:
        controller = read_fcl(but("IF noise IS quiet THEN", "if noise is quiet then"))
        self.assertEqual(controller.rules[0].conditions, (("noise", "quiet"),))

    def test_a_single_condition_joins_with_and(self) -> None:
        self.assertEqual(read_fcl(SMALL).rules[0].connective, "and")


class RefusesTests(unittest.TestCase):
    def assert_refused(self, text: str, sentence: str) -> None:
        """The text is refused, by the rule whose sentence is given."""
        with self.assertRaisesRegex(FuzzyError, sentence):
            read_fcl(text)

    def test_a_line_outside_any_block(self) -> None:
        self.assert_refused("stray\n" + SMALL, "line 1: expected a block")

    def test_a_block_with_no_end(self) -> None:
        self.assert_refused(SMALL.rstrip().removesuffix("END"), "ends inside RULEBLOCK")

    def test_words_after_a_block_keyword(self) -> None:
        self.assert_refused(but("VAR_INPUT\n", "VAR_INPUT junk\n"), "unexpected words")

    def test_words_after_end(self) -> None:
        self.assert_refused(but("loud = 4,8,10\nEND", "loud = 4,8,10\nEND whatever"),
                            "unexpected words")

    def test_a_fuzzify_naming_two_variables(self) -> None:
        self.assert_refused(but("FUZZIFY noise", "FUZZIFY noise extra"), "unexpected words")

    def test_two_names_on_one_declaration_line(self) -> None:
        self.assert_refused(but("    noise\nEND\nVAR_OUTPUT", "    noise light\nEND\nVAR_OUTPUT"),
                            "unexpected words")

    def test_a_variable_declared_twice(self) -> None:
        self.assert_refused(but("    alertness\nEND", "    alertness\n    noise\nEND"),
                            "F4 line 7: noise is declared twice")

    def test_a_fuzzify_for_an_undeclared_input(self) -> None:
        self.assert_refused(but("FUZZIFY noise", "FUZZIFY volume"), "names no declared input")

    def test_a_defuzzify_for_an_input(self) -> None:
        self.assert_refused(but("DEFUZZIFY alertness", "DEFUZZIFY noise"),
                            "names no declared output")

    def test_a_variable_given_two_blocks(self) -> None:
        self.assert_refused(SMALL.replace("RULEBLOCK", "FUZZIFY noise\nEND\nRULEBLOCK"),
                            "already has a block")

    def test_a_declared_variable_with_no_block(self) -> None:
        self.assert_refused(but("    noise\nEND\nVAR_OUTPUT", "    noise\n    light\nEND\nVAR_OUTPUT"),
                            "F2 variable 'light' has no block")

    def test_a_variable_with_no_range(self) -> None:
        self.assert_refused(but("    RANGE = 0,10\n", ""), "F2 variable 'noise' has no block")

    def test_a_range_of_one_number(self) -> None:
        self.assert_refused(but("RANGE = 0,10\n", "RANGE = 10\n"), "F2 variable 'noise'")

    def test_a_range_given_twice(self) -> None:
        self.assert_refused(but("RANGE = 0,10\n", "RANGE = 0,10\n    RANGE = 0,5\n"),
                            "RANGE is given twice")

    def test_numbers_that_are_not_numbers(self) -> None:
        self.assert_refused(but("quiet = 0,0,2,6", "quiet = 0,zero,2,6"),
                            "line 10: .* is not a list of numbers")

    def test_nan_and_inf_are_not_numbers_here(self) -> None:
        self.assert_refused(but("quiet = 0,0,2,6", "quiet = 0,0,2,inf"), "not a list of numbers")
        self.assert_refused(but("RANGE = 0,10\n", "RANGE = 0,nan\n"), "not a list of numbers")

    def test_a_set_line_with_no_equals(self) -> None:
        self.assert_refused(but("quiet = 0,0,2,6", "quiet 0,0,2,6"), "expected `name = numbers`")

    def test_a_set_with_no_name(self) -> None:
        self.assert_refused(but("quiet = 0,0,2,6", "= 0,0,2,6"), "not a usable set name")

    def test_a_set_name_with_a_space(self) -> None:
        self.assert_refused(but("quiet = 0,0,2,6", "very quiet = 0,0,2,6"),
                            "not a usable set name")

    def test_a_set_with_the_wrong_number_of_points_names_its_line(self) -> None:
        self.assert_refused(but("quiet = 0,0,2,6", "quiet = 0,6"),
                            r"F1 set 'quiet' needs three or four points.*\(line 10\)")

    def test_samples_on_an_input(self) -> None:
        self.assert_refused(but("RANGE = 0,10\n", "RANGE = 0,10\n    SAMPLES = 1,2,3\n"),
                            "only an output has it")

    def test_samples_that_are_not_a_whole_number(self) -> None:
        for written in ("2.9", "5,6", "nan", "-3"):
            with self.subTest(samples=written):
                self.assert_refused(but("SAMPLES = 11", f"SAMPLES = {written}"),
                                    "SAMPLES is one whole number")

    def test_samples_given_twice(self) -> None:
        self.assert_refused(but("SAMPLES = 11", "SAMPLES = 11\n    SAMPLES = 21"),
                            "SAMPLES is given twice")

    def test_a_rule_line_without_its_label(self) -> None:
        self.assert_refused(but("RULE 1 =", "garbage ="), "starts `RULE <number> =`")

    def test_a_rule_naming_a_set_nobody_declared_names_its_line(self) -> None:
        self.assert_refused(but("IF noise IS quiet THEN alertness", "IF noise IS silent THEN alertness"),
                            "F7 line 20: noise IS silent is no input's set")

    def test_a_rule_concluding_a_set_nobody_declared(self) -> None:
        self.assert_refused(but("THEN alertness IS calm", "THEN alertness IS bored"),
                            "F7 line 20: alertness IS bored is no output's set")

    def test_a_rule_with_no_then(self) -> None:
        self.assert_refused(but("THEN alertness IS calm", "XYZ alertness IS calm"),
                            "a rule reads IF ... THEN")

    def test_a_rule_not_starting_with_if(self) -> None:
        self.assert_refused(but("IF noise IS quiet THEN", "WHEN noise IS quiet THEN"),
                            "a rule reads IF ... THEN")

    def test_a_conclusion_without_is(self) -> None:
        self.assert_refused(but("THEN alertness IS calm", "THEN alertness WAS calm"),
                            "the conclusion reads")

    def test_a_rule_ending_on_a_connective(self) -> None:
        self.assert_refused(but("IF noise IS quiet THEN", "IF noise IS quiet AND THEN"),
                            "a condition reads")

    def test_a_condition_without_is(self) -> None:
        self.assert_refused(but("IF noise IS quiet THEN", "IF noise WAS quiet THEN"),
                            "a condition reads")

    def test_a_connective_that_is_neither_and_nor_or(self) -> None:
        self.assert_refused(but("loud OR noise", "loud XOR noise"), "joined by AND or OR")

    def test_a_rule_mixing_and_with_or(self) -> None:
        mixed = "IF noise IS loud OR noise IS quiet AND noise IS loud THEN"
        self.assert_refused(but("IF noise IS loud OR noise IS quiet THEN", mixed),
                            "F6 line 21: one rule mixes AND and OR")


if __name__ == "__main__":
    unittest.main()
