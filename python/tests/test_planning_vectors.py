"""The Python half of the planning conformance run.

The vectors in `spec/vectors/planning/` are read from both languages, and each
side checks what it owns. GDScript builds the domain out of the JSON and plans
over it; this asserts that the two PDDL files beside each vector describe
*exactly* that domain, start and goal.

That is what makes the pair worth having. A reader that drops an action's
delete list parses perfectly, and only the comparison with a domain that is
also run catches it.

Order is ignored throughout: `(and (a) (b))` and `(and (b) (a))` are the same
precondition, and a reader that imposed an order would be inventing one.
"""

import json
import pathlib
import unittest

from gameaikit.pddl import Action, Domain, Problem, read_domain, read_problem

SPEC = pathlib.Path(__file__).resolve().parents[2] / "spec"

#: Where planning vectors live. The second is the tactical board's own domain
#: (T11): it is a vector like the others, so the domain the game plays with is
#: held to its PDDL by the same tests, and planned over by the same runner.
DIRECTORIES = (SPEC / "vectors" / "planning", SPEC / "pddl")

#: Fewer than this and something has gone wrong with the directory rather than
#: with the vectors. A conformance run that inspects nothing and reports
#: success is the failure this repository is arranged against, and a test that
#: iterates over an empty glob passes in exactly that way.
FEWEST_VECTORS = 3


def vector_files() -> list[pathlib.Path]:
    """Every vector in every directory, in a fixed order."""
    return [path for directory in DIRECTORIES for path in sorted(directory.glob("*.json"))]


def lists_of(action: Action) -> tuple[frozenset, frozenset, frozenset]:
    """One action's three lists, as sets, for comparing across languages."""
    return (
        frozenset(action.preconditions),
        frozenset(action.deletes),
        frozenset(action.adds),
    )


def lists_of_entry(entry: dict) -> tuple[frozenset, frozenset, frozenset]:
    """The same three lists, out of the JSON.

    Folded to lower case on this side too. The reader folds because PDDL is
    case-insensitive, and comparing a folded name against an unfolded one would
    report a difference that is not one.
    """
    return (
        frozenset(name.lower() for name in entry["preconditions"]),
        frozenset(name.lower() for name in entry["deletes"]),
        frozenset(name.lower() for name in entry["adds"]),
    )


class TheDirectoryItself(unittest.TestCase):
    def test_there_are_vectors_to_check(self) -> None:
        self.assertGreaterEqual(len(vector_files()), FEWEST_VECTORS)

    def test_the_tactical_domain_is_among_them(self) -> None:
        # The directory list is a second place a vector can go missing from.
        self.assertIn(SPEC / "pddl" / "tactics.json", vector_files())

    def test_every_vector_names_two_pddl_files_that_are_there(self) -> None:
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            with self.subTest(vector=path.name):
                for field in ("domain", "problem"):
                    self.assertTrue((path.parent / vector[field]).exists(), field)


class ThePddlMatchesTheJson(unittest.TestCase):
    def test_the_actions_are_the_same_actions(self) -> None:
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            domain = read_domain((path.parent / vector["domain"]).read_text(encoding="utf-8"))
            with self.subTest(vector=path.name):
                # Both sides are keyed by name, so the count is asserted
                # separately: two actions sharing a name collapse into one
                # entry, and `assertEqual` on the dictionaries would not see
                # the one that went missing. A vector with no actions at all
                # compares `{}` with `{}`, which is the shape of a test that
                # passes while measuring nothing.
                self.assertGreater(len(vector["actions"]), 0)
                self.assertEqual(len(domain.actions), len(vector["actions"]))
                self.assertEqual(
                    {action.name: lists_of(action) for action in domain.actions},
                    {entry["name"].lower(): lists_of_entry(entry)
                     for entry in vector["actions"]},
                )

    def test_the_start_and_the_goal_are_the_same(self) -> None:
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            problem = read_problem((path.parent / vector["problem"]).read_text(encoding="utf-8"))
            with self.subTest(vector=path.name):
                self.assertEqual(set(problem.init),
                                 {name.lower() for name in vector["init"]})
                self.assertEqual(set(problem.goal),
                                 {name.lower() for name in vector["goal"]})

    def test_each_problem_is_for_the_domain_beside_it(self) -> None:
        # Two vectors whose files were copied and half-edited would otherwise
        # pass: the pairing is only in the filenames.
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            domain = read_domain((path.parent / vector["domain"]).read_text(encoding="utf-8"))
            problem = read_problem((path.parent / vector["problem"]).read_text(encoding="utf-8"))
            with self.subTest(vector=path.name):
                self.assertEqual(problem.domain, domain.name)


class ThePddlIsInternallyHonest(unittest.TestCase):
    def test_every_predicate_used_is_one_the_domain_declares(self) -> None:
        # The classic PDDL defect: a typo in an action's effect names a
        # predicate nothing else mentions, so the action adds something no
        # precondition will ever test and the plan silently never arrives.
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            domain = read_domain((path.parent / vector["domain"]).read_text(encoding="utf-8"))
            problem = read_problem((path.parent / vector["problem"]).read_text(encoding="utf-8"))
            declared = set(domain.predicates)
            with self.subTest(vector=path.name):
                self.assertEqual(self.used(domain, problem) - declared, set())

    @staticmethod
    def used(domain: Domain, problem: Problem) -> set:
        """Every predicate named anywhere in a domain and its problem."""
        names = set(problem.init) | set(problem.goal)
        for action in domain.actions:
            names |= set(action.preconditions) | set(action.deletes) | set(action.adds)
        return names


if __name__ == "__main__":
    unittest.main()
