"""A language model as one more decider, behind a validator.

The tier-1 half of `ai_llm`, standard library only and no model: the
validator that decides what a reply may contain (`validator.py`), and a
replay of a recorded conversation through it and a game's rules
(`replay.py`). `spec/vectors/llm/` holds this validator and the addon's
`LlmValidator` to one answer per reply.

    from gameaikit.llm import Declaration, validate
    guard = Declaration({"greet": [], "ask": ["the_gate"]}, "Say that again.")
    validate('{"speech": "Evening.", "intent": "greet", "argument": ""}', guard)

Read `validator.py` first: its docstring lists every rule. `replay` is
imported by name (`from gameaikit.llm.replay import replay`), because it
also runs as a program and a package that imports it first warns.
"""

from .validator import (
    FALLBACK_INTENT,
    Declaration,
    Reply,
    fallback,
    json_schema,
    validate,
    why_declaration_is_wrong,
    why_refused,
)

__all__ = [
    "FALLBACK_INTENT",
    "Declaration",
    "Reply",
    "fallback",
    "json_schema",
    "validate",
    "why_declaration_is_wrong",
    "why_refused",
]
