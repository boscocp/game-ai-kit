# Conformance vectors: planning

<!-- doc-meta
half_life: structure
verified_on: 2026-10-12
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the STRIPS action shape changes, or a vector field is renamed
teaches: none
-->

> One domain, one question, and two sides held to the same answer.

Each vector is a `.json` file beside two `.pddl` files, and the two languages
check different halves of it:

- **GDScript** (`make test-vectors`) builds the domain out of the JSON, plans
  over it, and checks what `expect` claims;
- **Python** (`make test-python`) reads the two PDDL files and checks they
  describe exactly the domain, start and goal the JSON spells out.

So the JSON is the pivot. The planner is held to answers nobody can quietly
edit beside it, and the PDDL reader is held to a domain that is also *run*
rather than only parsed — a reader that drops an action's delete list parses
perfectly and plans wrongly, and only the comparison catches it.

```json
{
  "name": "a short label for a reader; the file name is what failures quote",
  "why": "what this domain is for -- the sentence a reader needs",
  "domain": "name-domain.pddl",
  "problem": "name-problem.pddl",
  "actions": [
    {"name": "mine_the_node", "preconditions": ["node_held"], "deletes": [], "adds": ["resources_banked"]}
  ],
  "init": ["army_in_reserve"],
  "goal": ["enemy_beaten"],
  "expect": { "solved": true, "steps": 8 }
}
```

- `preconditions`, `deletes` and `adds` are the three STRIPS lists. Deletes run
  before adds, so a predicate in both survives.
- `init` may be empty; `goal` may not. A goal of `[]` holds in every state and
  pins nothing.
- `expect.steps` is required when `solved` is true and refused when it is
  false: a vector that claims a plan exists and says nothing about it is a
  vector that passes on a planner returning anything at all.

**What a vector deliberately does not pin: the plan itself.** Several orders of
the same actions reach the same goal in the same number of steps — in the
supply chain, scouting can happen anywhere after the march — and pinning one of
them would fail a correct planner for a reason that is not about correctness.
The number of steps is pinned, because *that* is the claim breadth-first makes.

**What the runner checks whatever the file says.** Every returned plan is
replayed from `init`: each step's preconditions must hold at the moment it runs,
and the goal must hold at the end. That is not read from `expect`, because a
planner's own report that it solved something is the one claim a conformance
runner must never take on trust — the wave 08 review found exactly that hole on
the search side, where every *step* of a path was legal and nobody checked
where it ended up.

Comparing PDDL with JSON ignores order: the actions are matched by name, and
each one's three lists are compared as sets. `(and (a) (b))` and `(and (b) (a))`
are the same precondition, and a reader that imposed an order would be inventing
one.

Run them with `make test-vectors` and `make test-python`.
