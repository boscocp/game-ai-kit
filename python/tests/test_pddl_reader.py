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


if __name__ == "__main__":
    unittest.main()
