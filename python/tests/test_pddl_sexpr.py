"""The parenthesis half of the reader, tested apart from the PDDL half.

Nothing here knows what a domain is. That separation is the reason both halves
stay small, and it is also why a broken file produces a message about a
parenthesis rather than about an action.
"""

import unittest

from gameaikit.pddl import PddlError, parse
from gameaikit.pddl.sexpr import tokenize


class Parsing(unittest.TestCase):
    def test_a_nested_form_becomes_nested_lists(self) -> None:
        self.assertEqual(parse("(and (a) (b))"), [["and", ["a"], ["b"]]])

    def test_an_empty_list_is_an_empty_list(self) -> None:
        # `(:init)` is a legal and meaningful PDDL section: nothing is true yet.
        self.assertEqual(parse("(:init)"), [[":init"]])

    def test_whitespace_and_newlines_do_not_matter(self) -> None:
        self.assertEqual(parse("(a\n  (b)\n)"), parse("(a (b))"))

    def test_a_comment_runs_to_the_end_of_its_line(self) -> None:
        self.assertEqual(parse("(a) ; (b) is a comment\n(c)"), [["a"], ["c"]])

    def test_a_semicolon_cannot_hide_a_parenthesis_from_the_reader(self) -> None:
        # The reason comments are stripped in the tokenizer: a `;` inside what
        # the reader sees would let a comment change the shape of a domain.
        self.assertEqual(parse("(a ; )\n)"), [["a"]])

    def test_two_top_level_forms_both_come_back(self) -> None:
        self.assertEqual(parse("(a) (b)"), [["a"], ["b"]])


class Refusals(unittest.TestCase):
    def test_an_unclosed_list_is_refused_with_its_line(self) -> None:
        with self.assertRaises(PddlError) as refused:
            parse("(define\n  (domain x)\n")
        self.assertEqual(refused.exception.line, 1)

    def test_a_stray_closing_parenthesis_is_refused(self) -> None:
        with self.assertRaises(PddlError) as refused:
            parse("(a))")
        self.assertIn("nothing open", str(refused.exception))

    def test_a_bare_word_outside_any_list_is_refused(self) -> None:
        # A file that is a word is not a form, and treating it as one gives a
        # reader downstream a string where it expects a section.
        with self.assertRaises(PddlError):
            parse("hello")


class Tokens(unittest.TestCase):
    def test_every_token_carries_the_line_it_came_from(self) -> None:
        self.assertEqual(tokenize("(a)\n(b)"), [
            ("(", 1), ("a", 1), (")", 1), ("(", 2), ("b", 2), (")", 2),
        ])

    def test_a_name_may_hold_the_punctuation_pddl_uses(self) -> None:
        self.assertEqual(
            [token for token, _line in tokenize("(:action march-to_node)")],
            ["(", ":action", "march-to_node", ")"],
        )


if __name__ == "__main__":
    unittest.main()
