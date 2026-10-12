"""What the reader accepts, and -- mostly -- what it refuses.

The refusals are the point. A reader that skips a section it does not
understand hands back a domain that parses perfectly and plans a world the
author did not describe, and the failure then appears somewhere else entirely,
as a plan that makes no sense. Every case below is a thing a real PDDL file
contains and this subset does not handle.
"""

import unittest

from gameaikit.pddl import PddlError, read_domain, read_problem

DOMAIN = """
(define (domain errands)
  (:requirements :strips)
  (:predicates (at_home) (at_shop) (has_bread))

  (:action walk_to_shop
    :parameters ()
    :precondition (and (at_home))
    :effect (and (at_shop) (not (at_home))))

  (:action buy_bread
    :parameters ()
    :precondition (and (at_shop))
    :effect (and (has_bread))))
"""

PROBLEM = """
(define (problem bread)
  (:domain errands)
  (:init (at_home))
  (:goal (and (has_bread))))
"""


class ReadingADomain(unittest.TestCase):
    def setUp(self) -> None:
        self.domain = read_domain(DOMAIN)

    def test_the_domain_keeps_its_name_and_predicates(self) -> None:
        self.assertEqual(self.domain.name, "errands")
        self.assertEqual(self.domain.predicates, ("at_home", "at_shop", "has_bread"))

    def test_an_effect_under_not_becomes_a_delete(self) -> None:
        walk = self.domain.actions[0]
        self.assertEqual(walk.adds, ("at_shop",))
        self.assertEqual(walk.deletes, ("at_home",))
        self.assertEqual(walk.preconditions, ("at_home",))

    def test_an_action_that_deletes_nothing_has_an_empty_delete_list(self) -> None:
        # Not the same as a missing one: STRIPS says what stops being true, and
        # "nothing" is an answer.
        self.assertEqual(self.domain.actions[1].deletes, ())

    def test_a_single_atom_is_a_conjunction_of_one(self) -> None:
        # `(:precondition (at_shop))` without the `and` is legal PDDL.
        terse = DOMAIN.replace("(and (at_shop))", "(at_shop)")
        self.assertEqual(read_domain(terse).actions[1].preconditions, ("at_shop",))


class ReadingAProblem(unittest.TestCase):
    def test_the_problem_carries_its_domain_its_start_and_its_goal(self) -> None:
        problem = read_problem(PROBLEM)
        self.assertEqual(problem.domain, "errands")
        self.assertEqual(problem.init, ("at_home",))
        self.assertEqual(problem.goal, ("has_bread",))

    def test_an_empty_init_is_read_rather_than_refused(self) -> None:
        # A world where nothing is true yet is a perfectly ordinary problem.
        self.assertEqual(read_problem(PROBLEM.replace("(:init (at_home))", "(:init)")).init, ())


class RefusingWhatItCannotPlan(unittest.TestCase):
    def refusal(self, text: str, *, problem: bool = False) -> str:
        with self.assertRaises(PddlError) as refused:
            read_problem(text) if problem else read_domain(text)
        return str(refused.exception)

    def test_a_requirement_it_does_not_meet_is_named(self) -> None:
        # `:adl` brings conditional effects and quantifiers. Reading the flag
        # and carrying on regardless is the expensive version of this bug.
        self.assertIn(":adl", self.refusal(DOMAIN.replace(":strips", ":adl")))

    def test_an_action_with_parameters_is_refused(self) -> None:
        lifted = DOMAIN.replace(":parameters ()", ":parameters (?where - place)", 1)
        self.assertIn("propositional", self.refusal(lifted))

    def test_a_predicate_with_arguments_is_refused(self) -> None:
        self.assertIn("no arguments", self.refusal(DOMAIN.replace("(at_shop)", "(at ?x)")))

    def test_a_negative_precondition_is_refused(self) -> None:
        # STRIPS as taught here has no negative preconditions, and silently
        # reading one as positive would invert the plan.
        negated = DOMAIN.replace("(and (at_home))", "(and (not (at_shop)))", 1)
        self.assertIn("positive atoms only", self.refusal(negated))

    def test_a_section_outside_the_subset_is_refused_by_name(self) -> None:
        typed = DOMAIN.replace("(:requirements :strips)", "(:types place - object)")
        self.assertIn(":types", self.refusal(typed))

    def test_an_action_with_no_effect_is_refused(self) -> None:
        pointless = DOMAIN.replace("    :effect (and (has_bread))))", "))")
        self.assertIn("does nothing", self.refusal(pointless))

    def test_a_problem_read_as_a_domain_says_so(self) -> None:
        self.assertIn("this is a problem", self.refusal(PROBLEM))

    def test_a_problem_without_a_goal_is_refused(self) -> None:
        goalless = PROBLEM.replace("(:goal (and (has_bread)))", "")
        self.assertIn("no goal", self.refusal(goalless, problem=True))

    def test_a_problem_that_names_no_domain_is_refused(self) -> None:
        orphan = PROBLEM.replace("(:domain errands)", "")
        self.assertIn("which domain", self.refusal(orphan, problem=True))

    def test_two_defines_in_one_file_are_refused(self) -> None:
        self.assertIn("found 2", self.refusal(DOMAIN + PROBLEM))

    def test_a_conditional_effect_is_refused_by_its_own_name(self) -> None:
        # The single most common thing a real domain has that this subset does
        # not. The message used to be a dump of the parse tree, which tells an
        # author nothing about what to change.
        conditional = DOMAIN.replace("(and (has_bread))", "(when (at_shop) (has_bread))")
        self.assertIn("`when`", self.refusal(conditional))
        self.assertIn("conditional effect", self.refusal(conditional))

    def test_a_quantifier_is_refused_by_its_own_name(self) -> None:
        quantified = DOMAIN.replace("(and (has_bread))", "(forall (?x) (has_bread))")
        self.assertIn("universal quantifier", self.refusal(quantified))

    def test_a_section_appearing_twice_is_refused_rather_than_replaced(self) -> None:
        # A domain whose predicates are written in two blocks is ordinary PDDL.
        # The second used to replace the first, in silence.
        split = DOMAIN.replace(
            "(:predicates (at_home) (at_shop) (has_bread))",
            "(:predicates (at_home) (at_shop))\n  (:predicates (has_bread))",
        )
        self.assertIn("appears twice", self.refusal(split))

    def test_a_problem_section_appearing_twice_is_refused(self) -> None:
        doubled = PROBLEM.replace("(:init (at_home))", "(:init (at_home))\n  (:init)")
        self.assertIn("appears twice", self.refusal(doubled, problem=True))

    def test_an_action_with_two_of_the_same_keyword_is_refused(self) -> None:
        doubled = DOMAIN.replace(
            "    :effect (and (has_bread))))",
            "    :effect (and (has_bread))\n    :effect (and (at_home))))",
        )
        self.assertIn("two `:effect`", self.refusal(doubled))

    def test_an_empty_conjunction_as_an_effect_is_refused(self) -> None:
        # `(and)` parses as a non-empty list, so it walked straight past the
        # refusal written for an action that does nothing.
        self.assertIn(
            "does nothing", self.refusal(DOMAIN.replace("(and (has_bread))", "(and)"))
        )

    def test_a_predicate_without_its_parentheses_is_refused(self) -> None:
        bare = DOMAIN.replace(":precondition (and (at_shop))", ":precondition at_shop")
        self.assertIn("bare word", self.refusal(bare))

    def test_an_action_declared_twice_is_refused(self) -> None:
        self.assertIn("declared twice", self.refusal(_twice()))

    def test_an_action_with_no_parameters_section_is_refused(self) -> None:
        # `:parameters` is mandatory in PDDL, and a missing one is indistinguishable
        # from an empty one to `fields.get`.
        self.assertIn(
            "no `:parameters`", self.refusal(DOMAIN.replace("    :parameters ()\n", "", 1))
        )

    def test_a_predicate_nothing_declares_is_refused(self) -> None:
        # The classic PDDL typo: the action adds something no precondition will
        # ever test, and the plan silently never arrives.
        typo = DOMAIN.replace("(and (has_bread))", "(and (has_bred))")
        self.assertIn("never declared", self.refusal(typo))

    def test_a_keyword_with_no_value_is_refused(self) -> None:
        self.assertIn(
            "no value", self.refusal(DOMAIN.replace(":effect (and (has_bread))))", ":effect))"))
        )

    def test_a_field_that_is_not_a_keyword_is_refused(self) -> None:
        stray = DOMAIN.replace("    :parameters ()\n    :precondition (and (at_home))", "    (oops) ()")
        self.assertIn("is not a `:keyword`", self.refusal(stray))

    def test_a_negation_of_more_than_one_atom_is_refused(self) -> None:
        self.assertIn(
            "takes one atom",
            self.refusal(DOMAIN.replace("(not (at_home))", "(not (at_home) (at_shop))")),
        )

    def test_a_file_that_does_not_start_with_define_is_refused(self) -> None:
        self.assertIn("does not start with `define`", self.refusal("(domain errands)"))

    def test_a_goal_of_more_than_one_form_is_refused(self) -> None:
        self.assertIn(
            "exactly one form",
            self.refusal(PROBLEM.replace("(:goal (and (has_bread)))",
                                         "(:goal (and (has_bread)) (at_home))"), problem=True),
        )

    def test_a_domain_reference_of_more_than_one_name_is_refused(self) -> None:
        self.assertIn(
            "exactly one name",
            self.refusal(PROBLEM.replace("(:domain errands)", "(:domain errands shop)"),
                         problem=True),
        )

    def test_a_section_a_problem_does_not_have_is_refused(self) -> None:
        # The domain twin of this rule was tested and this one was not, so a
        # reader could have started swallowing `:objects` with nothing noticing.
        self.assertIn(
            "not a section of a problem",
            self.refusal(PROBLEM.replace("(:init (at_home))", "(:objects bread)"),
                         problem=True),
        )


class NamesAreCaseInsensitive(unittest.TestCase):
    """PDDL folds case; a reader that did not would read two predicates where
    every real planner reads one."""

    def test_a_predicate_is_the_same_predicate_in_any_case(self) -> None:
        shouted = DOMAIN.replace("(at_home)", "(At_Home)").replace(
            "(not (at_home))", "(not (AT_HOME))"
        )
        walk = read_domain(shouted).actions[0]
        self.assertEqual(walk.preconditions, ("at_home",))
        self.assertEqual(walk.deletes, ("at_home",))

    def test_a_domain_name_and_an_action_name_fold_too(self) -> None:
        shouted = DOMAIN.replace("(domain errands)", "(domain Errands)").replace(
            ":action walk_to_shop", ":action Walk_To_Shop"
        )
        domain = read_domain(shouted)
        self.assertEqual(domain.name, "errands")
        self.assertEqual(domain.actions[0].name, "walk_to_shop")


def _twice() -> str:
    """The errands domain with `buy_bread` declared a second time."""
    return DOMAIN.replace(
        "  (:action buy_bread",
        "  (:action buy_bread\n    :parameters ()\n    :precondition (and (at_home))\n"
        "    :effect (and (has_bread)))\n\n  (:action buy_bread",
        1,
    )


if __name__ == "__main__":
    unittest.main()
