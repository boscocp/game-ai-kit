# ai_bayes — is anyone there, and what makes you think so?

<!-- doc-meta
half_life: practice
verified_on: 2026-11-07
tier: 1
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 13, Probabilistic Reasoning, sections 13.2 and 13.3.1, figures 13.2 and 13.10
invalidated_if: the kit's BayesNetwork signature or its data shape changes, or the infiltration demo stops asking it
teaches: stealth-ai
-->

> Português: [ai_bayes.pt-BR.md](ai_bayes.pt-BR.md). The words that stay
> in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

How likely something you cannot see is, from what you can -- and which of
the things you saw made you think so. A *Bayesian network* is a list of
discrete variables, each with a few values ("yes" and "no"; or "calm",
"windy", "storm") and its *parents*, the variables it depends on directly.
Each variable holds a *conditional probability table*: one row for every
way its parents can be, each row the chance of each of its values. Those
rows are every number there is. The network says that a variable, once its
parents are known, cares about nothing else above it, so the chance of any
whole assignment is a product, one table entry a variable.

`BayesNetwork.ask(query, evidence)` answers P(query | evidence) as AIMA 4th
edition's ENUMERATION-ASK (13.3.1, fig. 13.10) does: for each value of the
query, with the evidence and that value fixed, it sums the product over
every value of every variable left hidden, then normalises. The book's
example, the burglar alarm John and Mary call about, comes out at 0.284,
worked by hand in [the vectors' README](../../spec/vectors/bayes/README.md).
`influence(query, value, evidence)` then says what each piece of evidence
did: the answer with it, less the answer without it. The largest of those
by size is `most_moved` -- either way, so it can be a sign *not* seen that
lowered the belief ("no noise"). What a guard acts on is narrower: the sign
it saw that raised the belief most, its *lead*, which is where it walks and
what its panel marks.

A cause that explains an effect makes the other causes of that effect less
likely: an alarm explained by an earthquake makes a burglary less likely
than the alarm alone did. That is *explaining away*, and it falls out of
the sums with no rule written for it. The guard's network has one: a
partner gone quiet is the intruder's work, unless the radio is at fault.

## When not to use it {#when-not}

When the network has tens of variables: enumeration is exponential in the
hidden ones, every yes-or-no variable doubling the work. *Variable
elimination* (AIMA 13.3.2) keeps each sum's partial products instead of
computing them again, and is the next step; it is not built here, nor is
sampling (13.4). When a variable is a number, not a few values: discretise
it, or use a filter, as `ai_perception`'s particles do for a place. When
the belief must follow time -- someone was here a minute ago, so may be
there now -- that is a dynamic network (ch. 14); this one is asked afresh
each time, and a game decides how long a sign is kept. And when the tables
are guesses nobody can defend: the arithmetic is exact, but only as good as
what it multiplies. Here the tables are written by hand, in data, and never
change at game time (invariant 6); learning them from logs would happen in
Python, offline.

## Where to watch it {#watch}

- `make demo-infiltration` -- the panel under the radar is the watched
  guard's network: "is anyone there?" with the belief as a bar and a tick
  where checking the evidence starts (0.3); the radio's chance of being at
  fault; each sign -- noise, open door, partner gone quiet -- seen or not,
  with what it did to the belief, the lead -- the sign seen that raised it
  most, where the guard will walk -- marked `>`;
  and the last change, which sign and the belief before and after. Walk to
  a door, press **F** to open it, and leave: a guard that sees it open
  rises over the tick, goes to it (its action reads "check the evidence"),
  shuts it, and its belief falls again. **Tab** watches the next guard.
  On the market (**L** past the generated levels, T152) a fourth sign, the
  figure the guard's eye picked out of a crowd: walk in step with a group
  and it "blends in", lowering the belief; sprint or crouch and it "stands
  out", raising it.
- Which demo uses which technique, both ways: the
  [catalogue](catalogue.md).

## In this kit {#in-this-kit}

`godot/game3d/infiltration/intruder_network.json` is the guard's network:
the intruder (0.05) and a faulty radio (0.02) as causes; a noise heard,
a door found open and a partner gone quiet as signs. `GuardSuspicion` holds
each guard's signs -- a sound of a kind the file names, a door its eyes saw
open, a partner it noticed silent -- each seen "yes" for as long as the
file keeps it, "no" otherwise, and asks the network again whenever what is
seen changes. Explaining away is on the panel: with only a partner gone
quiet, the radio's chance of a fault is 0.548; once a door is also found
open, it falls to 0.047 -- the intruder now explains the silence. A noise alone gives 0.07, a door alone 0.42, both 0.94. On a crowded level a `figure` with the intruder as parent joins them, observed only while the guard's eye picks someone out of a group and summed over otherwise: blending in gives 0.0018 where nothing seen gives 0.0036, standing out alone 0.08 -- still under the threshold -- and with a noise 0.65. The
guard's selector (`ai_utility`) reads the belief as one more number: the
action "check the evidence" scores from 0.3 up, so the guard walks to the
sign that raised its belief most. There the sign is settled -- a door it
finds open is shut -- and the belief falls again. The same tables are a
conformance vector, so the game's numbers are checked in both languages.
The knobs:

| knob | where | what it changes |
|---|---|---|
| variables | `{"name", "values", "parents", "table"}` in the data, a parent before its child | what is reasoned about, and what depends on what |
| table | one row per combination of the parents' values, the first parent varying slowest | every chance there is; a row must sum to 1 |
| evidence | the dictionary handed to `ask`, a variable to a value | what was seen; a variable left out is summed over |
| threshold | the "check the evidence" action's step on `intruder`, in `guard_actions.json` | how sure a guard must be before it goes to look |
| remember_for, settled_within | each sign in `intruder_network.json`, and the file | how long a sign counts, and how near the guard must walk to settle it |

## In your own project {#your-project}

### What to copy {#copy}

From the library: unzip `ai_bayes-<version>.zip` into your project's
root, `res://` -- [using the library](using-the-library.md) has every step,
the Python wheel too. Or copy it from a checkout:

One folder: `godot/addons/ai_bayes/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its class. The Python twin is `gameaikit.bayes`, for asking
the same network with no engine.

### A minimal example {#example}

A night watchman of your own who hears the dog and sees the gate, and
wants to know whether anyone came in -- and why he thinks so. This file is
run by `watchman_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/ai_bayes/watchman_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_bayes.md, run by
# watchman_example_test.gd. A night watchman of your own who hears the dog
# and sees the gate, and wants to know whether anyone came in -- and why he
# thinks so.
extends Node

# Written by hand: a parent before its child, one row per way its parents
# can be, the chances in a row summing to 1. Nothing here changes them.
const NETWORK: Dictionary = {"variables": [
	{"name": "intruder", "values": ["yes", "no"], "parents": [], "table": [[0.05, 0.95]]},
	{"name": "dog_barks", "values": ["yes", "no"], "parents": ["intruder"], "table": [[0.8, 0.2], [0.1, 0.9]]},
	{"name": "gate_open", "values": ["yes", "no"], "parents": ["intruder"], "table": [[0.6, 0.4], [0.02, 0.98]]},
]}

var _network := BayesNetwork.new(NETWORK)
# What the watchman has noticed, yes or no; what he has not checked is left
# out, and the network sums over it.
var _seen: Dictionary = {}


func _ready() -> void:
	# A parent given after its child, a row short or a row not summing to 1
	# is refused here.
	if _network.problem() != "":
		push_error(_network.problem())


## He noticed `evidence` -- "dog_barks" or "gate_open" -- happen, or not.
func noticed(evidence: String, happened: bool) -> void:
	_seen[evidence] = "yes" if happened else "no"


## He stops counting `evidence`: he checked, and it meant nothing.
func forget(evidence: String) -> void:
	_seen.erase(evidence)


## The chance someone came in, from what he has noticed.
func chance_of_intruder() -> float:
	return _network.ask("intruder", _seen)[0]


## What moved his belief most -- the line to show over his head.
func reason() -> String:
	return BayesNetwork.most_moved(_network.influence("intruder", "yes", _seen))
```

### What you implement {#implement}

The tables, and what counts as each piece of evidence. Write a parent
before its child; give each table one row per combination of its parents'
values, the first parent varying slowest, each row summing to 1; call
`problem()` after building -- `""` means it can be asked, and anything else
names the rule broken (B1 to B5, the vectors' README lists them). Decide,
in your game, when a variable is seen "yes", seen "no", or not seen at all:
left out of the evidence, it is summed over, which is different from "no".
`ask` returns an empty array when the evidence cannot happen under your
tables (a chance of 0), so read it before indexing. And keep the network
small: each hidden variable doubles the work of every question.

## Deeper {#deeper}

- How stealth guards perceive and decide, and where this network sits
  beside the awareness and the belief map:
  [concepts/stealth-ai.md](../concepts/stealth-ai.md).
- The burglary worked by hand, and the rules a third implementation must
  follow: [spec/vectors/bayes/README.md](../../spec/vectors/bayes/README.md).
- Where Bayesian networks sit among the field's techniques:
  [concepts/the-literature-and-the-kit.md](../concepts/the-literature-and-the-kit.md).
