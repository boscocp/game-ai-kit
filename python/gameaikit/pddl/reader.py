"""Read a STRIPS domain and problem out of PDDL text.

The subset
----------
Propositional STRIPS and nothing else: zero-argument predicates, actions with
an empty `:parameters`, conjunctions of positive atoms as preconditions, and
effects that are positive atoms or `(not (atom))`.

That is the same shape `ai_planning` plans over, and the limit is deliberate.
A lifted planner reasoning about `(holds ?faction ?node)` is a much larger
lesson and a much larger piece of code, and a reader that quietly *ignored* the
parameters it could not handle would hand back a domain that parses perfectly
and plans wrongly.

So everything outside the subset raises `PddlError` **naming the construct it
refused**, because "`when` is a conditional effect and this reader has none" is
a sentence an author can act on and a dump of the parse tree is not. A reader
that skips what it does not understand is the most expensive kind of defect
here: the failure appears later, somewhere else, as a plan.

The three rules that are not about the subset
---------------------------------------------
All three were found by a review that fed this reader ordinary PDDL, and each
one let a file through whose meaning was not what it said:

* **a section may not appear twice.** A domain with two `:predicates` blocks --
  an entirely ordinary way to write one -- used to keep the second and drop the
  first, in silence, and nothing downstream could tell;
* **a predicate used by an action must be declared** in `(:predicates ...)`.
  The classic PDDL defect is a typo in an effect: the action then adds
  something no precondition will ever test, and the plan silently never
  arrives;
* **names are folded to lower case**, because PDDL is case-insensitive and
  this reader is not the place to invent a second convention. `(At_Home)` and
  `(at_home)` are one predicate, as every real planner reads them.

Why Python
----------
Reading a domain file is not something a game does in a frame; it is something
a tool does once, offline. The planner that runs in the game is GDScript and
has no parser in it at all.
"""


from __future__ import annotations

import dataclasses

from .sexpr import PddlError, parse, unparse
from gameaikit.techniques import technique

#: The only requirement flag this reader understands.
SUPPORTED_REQUIREMENTS = (":strips",)

#: Constructs a real PDDL file uses and this subset cannot plan, each with the
#: words an author would recognise. Naming them is the difference between a
#: message somebody can act on and a message about this reader.
BEYOND_THE_SUBSET = {
    "and": "a nested conjunction",
    "or": "a disjunction",
    "not": "a negation",
    "imply": "an implication",
    "when": "a conditional effect",
    "forall": "a universal quantifier",
    "exists": "an existential quantifier",
    "increase": "a numeric effect",
    "decrease": "a numeric effect",
    "assign": "a numeric effect",
    "=": "an equality",
}


@dataclasses.dataclass(frozen=True)
class Action:
    """One STRIPS action: what must hold, what stops holding, what starts."""

    name: str
    preconditions: tuple[str, ...]
    deletes: tuple[str, ...]
    adds: tuple[str, ...]


@dataclasses.dataclass(frozen=True)
class Domain:
    """What can be done, independently of any particular situation."""

    name: str
    predicates: tuple[str, ...]
    actions: tuple[Action, ...]


@dataclasses.dataclass(frozen=True)
class Problem:
    """One situation: where it starts and what counts as finished."""

    name: str
    domain: str
    init: tuple[str, ...]
    goal: tuple[str, ...]


@technique("pddl-domain", "a STRIPS planning domain read from PDDL, every predicate checked")
def read_domain(text: str) -> Domain:
    """The domain in `text`, or `PddlError` saying why it is not one."""
    form = _one_form(text, "domain")
    # Read before the sections rather than after them: a problem file handed to
    # this function should be told what it is, not told that `:domain` is not a
    # section of a domain.
    name = _named(form, "domain")
    predicates: tuple[str, ...] = ()
    actions: list[Action] = []

    for section in _sections(form):
        heading = _heading(section)
        if heading == ":requirements":
            _check_requirements(section[1:])
        elif heading == ":predicates":
            predicates = tuple(_atom(item, ":predicates") for item in section[1:])
        elif heading == ":action":
            actions.append(_one_more_action(actions, section))
        else:
            raise PddlError(
                f"`{heading}` is not part of the STRIPS subset this reader "
                "handles; see the module docstring"
            )

    domain = Domain(name=name, predicates=predicates, actions=tuple(actions))
    _check_every_predicate_is_declared(domain)
    return domain


def _sections(form: list) -> list:
    """The sections of a `define`, with a repeat refused rather than kept.

    Only `:action` may appear more than once. Everything else was a plain
    assignment here until a review wrote a domain with two `:predicates`
    blocks: the second replaced the first, in silence, and a declaration that
    had gone missing is exactly what nothing downstream can notice.
    """
    seen: set[str] = set()
    for section in form[2:]:
        heading = _heading(section)
        if heading != ":action" and heading in seen:
            raise PddlError(
                f"`{heading}` appears twice; the second would replace the first"
            )
        seen.add(heading)
    return form[2:]


def _one_more_action(already: list[Action], section: list) -> Action:
    """One `:action`, refused when an action of that name is already read."""
    action = _read_action(section)
    if any(earlier.name == action.name for earlier in already):
        raise PddlError(
            f"action `{action.name}` is declared twice; whichever came first "
            "would be the one nothing ever checks"
        )
    return action


def _check_every_predicate_is_declared(domain: Domain) -> None:
    """Refuse an action naming a predicate the domain never declared.

    The classic PDDL defect is a typo in an effect. The action then adds
    something no precondition will ever test, the domain parses perfectly, and
    the plan silently never arrives.
    """
    used: set[str] = set()
    for action in domain.actions:
        used |= set(action.preconditions) | set(action.deletes) | set(action.adds)
    undeclared = sorted(used - set(domain.predicates))
    if undeclared:
        raise PddlError(
            f"{', '.join('`' + name + '`' for name in undeclared)} used by an "
            "action and never declared in `(:predicates ...)`"
        )


def read_problem(text: str) -> Problem:
    """The problem in `text`, or `PddlError` saying why it is not one."""
    form = _one_form(text, "problem")
    name = _named(form, "problem")
    domain = ""
    init: tuple[str, ...] = ()
    goal: tuple[str, ...] = ()

    for section in _sections(form):
        heading = _heading(section)
        if heading == ":domain":
            domain = _only_word(section, ":domain").lower()
        elif heading == ":init":
            init = tuple(_atom(item, ":init") for item in section[1:])
        elif heading == ":goal":
            goal = _conjunction(_only_form(section, ":goal"), ":goal")
        else:
            raise PddlError(f"`{heading}` is not a section of a problem")

    if not domain:
        raise PddlError("the problem does not say which domain it is for")
    if not goal:
        raise PddlError("the problem has no goal, so every state satisfies it")
    return Problem(name=name, domain=domain, init=init, goal=goal)


def _check_requirements(flags: list) -> None:
    """Refuse a domain that needs more than this reader has.

    A requirement flag is the domain telling you what it is about to use. The
    expensive mistake is to read the flag and carry on anyway: `:adl` means
    conditional effects and quantifiers, a propositional reader skips them
    silently, and what comes out is a domain that plans a world the author did
    not describe.
    """
    for flag in flags:
        if not isinstance(flag, str) or flag.lower() not in SUPPORTED_REQUIREMENTS:
            raise PddlError(
                f"`{flag}` is a requirement this reader does not meet; it reads "
                + ", ".join(SUPPORTED_REQUIREMENTS)
            )


def _read_action(section: list) -> Action:
    """One `:action` block, with its three lists."""
    name = _only_word(section[:2], ":action").lower()
    fields = _fields_of(section[2:], name)

    # PDDL requires `:parameters`, and `fields.get` is falsy whether it is
    # empty or absent -- so a domain that forgot it read as propositional and
    # was accepted by a reader whose whole claim is that it refuses what it
    # cannot plan.
    if ":parameters" not in fields:
        raise PddlError(
            f"action `{name}` has no `:parameters`; PDDL requires it, and this "
            "reader requires it to be empty"
        )
    if fields[":parameters"]:
        raise PddlError(
            f"action `{name}` takes parameters, and this reader is "
            "propositional: write the actions out, one per case"
        )
    preconditions = _conjunction(fields.get(":precondition", []), f"{name} precondition")
    adds, deletes = _effects(fields.get(":effect", []), name)
    return Action(name=name, preconditions=preconditions, deletes=deletes, adds=adds)


def _fields_of(rest: list, action_name: str) -> dict[str, list]:
    """The `:keyword value` pairs of an action block, as a dictionary."""
    if len(rest) % 2 != 0:
        raise PddlError(f"action `{action_name}` has a `:keyword` with no value")
    fields: dict[str, list] = {}
    for keyword, value in zip(rest[::2], rest[1::2]):
        if not isinstance(keyword, str) or not keyword.startswith(":"):
            raise PddlError(
                f"action `{action_name}`: {unparse(keyword)} is not a `:keyword`"
            )
        if keyword in fields:
            raise PddlError(f"action `{action_name}` has two `{keyword}` keywords")
        # A bare word used to be wrapped into a one-item list here, which is
        # the shape `_atom` accepts -- so `:precondition at_home`, with the
        # parentheses missing, was read as the predicate `at_home`.
        if not isinstance(value, list):
            raise PddlError(
                f"action `{action_name}`: `{keyword} {value}` is a bare word; "
                f"a predicate is written `({value})`"
            )
        fields[keyword] = value
    return fields


def _effects(effect: list, action_name: str) -> tuple[tuple[str, ...], tuple[str, ...]]:
    """An effect, split into what it adds and what it deletes."""
    adds: list[str] = []
    deletes: list[str] = []
    for item in _effect_items(effect, action_name):
        if isinstance(item, list) and item and item[0] == "not":
            if len(item) != 2:
                raise PddlError(f"action `{action_name}`: `not` takes one atom")
            deletes.append(_atom(item[1], f"{action_name} effect"))
            continue
        adds.append(_atom(item, f"{action_name} effect"))
    return tuple(adds), tuple(deletes)


def _effect_items(effect: list, action_name: str) -> list:
    """The parts of an effect: the members of an `(and ...)`, or the one atom."""
    if not effect:
        raise PddlError(f"action `{action_name}` has no effect, so it does nothing")
    if effect[0] == "and":
        # `(and)` is a conjunction of nothing, which parses as a non-empty list
        # and means an action that changes nothing -- past the refusal above,
        # which was written for exactly that action.
        if len(effect) == 1:
            raise PddlError(
                f"action `{action_name}` has the empty effect `(and)`, so it "
                "does nothing"
            )
        return effect[1:]
    return [effect]


def _conjunction(form: list, where: str) -> tuple[str, ...]:
    """A conjunction of positive atoms: `(and (a) (b))`, `(a)`, or nothing."""
    if not form:
        return ()
    items = form[1:] if form[0] == "and" else [form]
    # Every refusal below this line is `_atom`'s, so a construct is named the
    # same way wherever it turns up. This function used to name three of them
    # itself, and a `when` in an effect -- the single most common thing a real
    # domain has that this subset does not -- got the fallback message.
    return tuple(_atom(item, where) for item in items)


def _atom(item: object, where: str) -> str:
    """A zero-argument predicate, `(name)`, as its name in lower case."""
    if isinstance(item, list) and item and isinstance(item[0], str):
        beyond = BEYOND_THE_SUBSET.get(item[0].lower())
        if beyond is not None:
            raise PddlError(
                f"{where} uses `{item[0]}`, which is {beyond}; this reader "
                "reads positive atoms only"
            )
    if isinstance(item, str):
        raise PddlError(
            f"{where}: `{item}` is a bare word; a predicate is written `({item})`"
        )
    if not isinstance(item, list) or len(item) != 1 or not isinstance(item[0], str):
        raise PddlError(
            f"{where}: {unparse(item)} is not a `(predicate)` with no arguments"
        )
    # PDDL is case-insensitive, and a reader that is not would read `(At_Home)`
    # and `(at_home)` as two predicates where every real planner reads one.
    return item[0].lower()


def _one_form(text: str, kind: str) -> list:
    """The single `(define (<kind> name) ...)` this text must hold."""
    forms = parse(text)
    if len(forms) != 1:
        raise PddlError(f"expected one `define`, found {len(forms)}")
    form = forms[0]
    if not form or form[0] != "define":
        raise PddlError(f"this is not a PDDL {kind}: it does not start with `define`")
    return form


def _named(form: list, kind: str) -> str:
    """The name out of `(define (domain frontier-node) ...)`."""
    if len(form) < 2 or not isinstance(form[1], list) or len(form[1]) != 2:
        raise PddlError(f"the `define` does not say `({kind} <name>)`")
    if form[1][0] != kind:
        raise PddlError(f"this is a {form[1][0]}, and a {kind} was expected")
    return str(form[1][1]).lower()


def _only_form(section: list, keyword: str) -> list:
    """The single form after a keyword, as in `(:goal (and (won)))`."""
    if len(section) != 2 or not isinstance(section[1], list):
        raise PddlError(f"`{keyword}` takes exactly one form")
    return section[1]


def _heading(section: object) -> str:
    """The `:keyword` a section opens with."""
    if not isinstance(section, list) or not section or not isinstance(section[0], str):
        raise PddlError(f"{section!r} is not a `(:keyword ...)` section")
    return section[0]


def _only_word(section: list, keyword: str) -> str:
    """The single word after a keyword, as in `(:domain frontier-node)`."""
    if len(section) != 2 or not isinstance(section[1], str):
        raise PddlError(f"`{keyword}` takes exactly one name")
    return section[1]
