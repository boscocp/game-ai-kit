"""The text reader: what it reads, and a refusal for each thing it will not.

The original reader printed a message for a name it could not find and
carried on, which is how a controller ends up one rule short and evaluating
perfectly. Every test below that expects a refusal is a case that reader
would have let through.
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
    """The small file with one line changed, so each test names its defect."""
    if old not in SMALL:
        raise AssertionError(f"the test's own fixture has no {old!r}")
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
    def assert_refused(self, text: str, code: str) -> None:
        """The text is refused, by the rule whose code is given."""
        with self.assertRaisesRegex(FuzzyError, code):
            read_fcl(text)

    def test_a_line_outside_any_block(self) -> None:
        self.assert_refused("stray\n" + SMALL, "F9 line 1")

    def test_a_block_with_no_end(self) -> None:
        self.assert_refused(SMALL.rstrip().removesuffix("END"), "F9 .*RULEBLOCK")

    def test_a_fuzzify_for_an_undeclared_input(self) -> None:
        self.assert_refused(but("FUZZIFY noise", "FUZZIFY volume"), "F9")

    def test_a_defuzzify_for_an_input(self) -> None:
        self.assert_refused(but("DEFUZZIFY alertness", "DEFUZZIFY noise"), "F9")

    def test_a_variable_given_two_blocks(self) -> None:
        self.assert_refused(SMALL.replace("RULEBLOCK", "FUZZIFY noise\nEND\nRULEBLOCK"), "F9")

    def test_a_declared_variable_with_no_block(self) -> None:
        self.assert_refused(but("    noise\nEND\nVAR_OUTPUT", "    noise\n    light\nEND\nVAR_OUTPUT"),
                            "F2 variable 'light'")

    def test_a_variable_with_no_range(self) -> None:
        self.assert_refused(but("    RANGE = 0,10\n", ""), "F2 variable 'noise'")

    def test_a_range_of_one_number(self) -> None:
        self.assert_refused(but("RANGE = 0,10", "RANGE = 10"), "F2")

    def test_numbers_that_are_not_numbers(self) -> None:
        self.assert_refused(but("quiet = 0,0,2,6", "quiet = 0,zero,2,6"), "F9 line 10")

    def test_a_set_line_with_no_equals(self) -> None:
        self.assert_refused(but("quiet = 0,0,2,6", "quiet 0,0,2,6"), "F9")

    def test_samples_on_an_input(self) -> None:
        # SAMPLES means nothing to an input; read as a set it is refused for
        # having one point, which is the right outcome and names the line.
        self.assert_refused(but("RANGE = 0,10", "RANGE = 0,10\n    SAMPLES = 5"), "F1")

    def test_a_rule_naming_a_set_nobody_declared(self) -> None:
        self.assert_refused(but("noise IS quiet THEN", "noise IS silent THEN"), "F7")

    def test_a_rule_with_no_then(self) -> None:
        self.assert_refused(but("THEN alertness IS calm", "alertness IS calm"), "F9")

    def test_a_rule_ending_on_a_connective(self) -> None:
        self.assert_refused(but("IF noise IS quiet THEN", "IF noise IS quiet AND THEN"), "F9")

    def test_a_condition_without_is(self) -> None:
        self.assert_refused(but("IF noise IS quiet THEN", "IF noise WAS quiet THEN"), "F9")

    def test_a_connective_that_is_neither_and_nor_or(self) -> None:
        self.assert_refused(but("loud OR noise", "loud XOR noise"), "F9")

    def test_a_rule_mixing_and_with_or(self) -> None:
        mixed = "IF noise IS loud OR noise IS quiet AND noise IS loud THEN"
        self.assert_refused(but("IF noise IS loud OR noise IS quiet THEN", mixed), "F6")


if __name__ == "__main__":
    unittest.main()
