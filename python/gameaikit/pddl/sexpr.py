"""S-expressions, which is the whole of PDDL's syntax.

PDDL looks intimidating and is not: it is Lisp's parenthesised lists with a
vocabulary on top. Separating the two halves is what keeps the reader small --
this module knows nothing about domains, actions or predicates, and
`reader.py` knows nothing about parentheses.

A form comes back as a list of strings and lists, so `(and (a) (b))` reads as
``["and", ["a"], ["b"]]``.
"""

from __future__ import annotations

import re

#: A token is a parenthesis or a run of anything that is not whitespace or a
#: parenthesis. PDDL names may contain ``-``, ``_``, ``:`` and ``?``, and
#: listing them would be a rule to maintain for no benefit.
TOKEN_RE = re.compile(r"\(|\)|[^\s()]+")


class PddlError(Exception):
    """A file that is not the PDDL this kit reads.

    It carries a line number because the first thing anyone does with a parse
    error is look for the line, and a reader that says only "unexpected token"
    makes that a search.
    """

    def __init__(self, message: str, line: int | None = None) -> None:
        self.line = line
        super().__init__(message if line is None else f"line {line}: {message}")


def tokenize(text: str) -> list[tuple[str, int]]:
    """Every token in `text`, each with the line it came from.

    Comments run from a `;` to the end of the line, exactly as in Lisp. They
    are dropped here rather than in the reader so that a `;` inside a domain
    cannot change what the reader sees.
    """
    tokens: list[tuple[str, int]] = []
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.split(";", 1)[0]
        tokens += [(token, number) for token in TOKEN_RE.findall(line)]
    return tokens


def parse(text: str) -> list[list]:
    """Every top-level form in `text`.

    A PDDL file holds one form -- a domain or a problem -- but returning a list
    is what makes an unbalanced file detectable: two forms where one was
    expected is a file someone concatenated, and the reader can say so instead
    of silently using the first.
    """
    tokens = tokenize(text)
    forms: list[list] = []
    position = 0
    while position < len(tokens):
        form, position = _read_form(tokens, position)
        if not isinstance(form, list):
            raise PddlError(f"{form!r} is outside any list", tokens[position - 1][1])
        forms.append(form)
    return forms


def _read_form(tokens: list[tuple[str, int]], position: int) -> tuple[object, int]:
    """One form, and where the next one starts."""
    token, line = tokens[position]
    if token == ")":
        raise PddlError("a `)` with nothing open", line)
    if token != "(":
        return token, position + 1

    items: list = []
    position += 1
    while position < len(tokens):
        if tokens[position][0] == ")":
            return items, position + 1
        item, position = _read_form(tokens, position)
        items.append(item)
    raise PddlError("a `(` that is never closed", line)
