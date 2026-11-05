"""Talk your way past the guard: a text game whose challenge is a conversation (T94).

`rules` is the guard's trust and suspicion, read from `gate.json` (a copy of
`spec/talk/gate.json`); `replay` plays a recorded conversation back through
`gameaikit.llm`'s validator and those rules, with no model -- the tier-1
lesson. `godot/game/talk/` is the same game with a window, and
`spec/vectors/talk/` holds the two to the same turn after turn.
"""
