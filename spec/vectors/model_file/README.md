# Conformance vectors: the model file

<!-- doc-meta
half_life: structure
verified_on: 2026-11-06
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a model file field is renamed, or a refusal code changes meaning
teaches: none
-->

> One file format, two readers, and the file that says they refuse the same
> things.

Python writes a model file (`gameaikit.training.model_file`) and the game
reads it (`ai_learning`'s `ModelFile`). The format belongs to no game: a
JSON object whose `models` maps a name to `kind`, `features`, `weights` and
`bias` -- or, for a decision tree (T113), `kind` "tree", `features`,
`classes` and `nodes`. The kind is read first, because it says which fields
the rest must be. Anything else at the top level is the publishing game's, handed to
it unread -- the tactical board's `feature_conventions` are checked by
`TacticalWeights` and `gameaikit.tactical.report`, not here.

`refusals.json` is a list of cases. Each carries the file, as a JSON object
(`file`) or as text (`text`, for what an object cannot hold: text that is not
JSON, and a `1e400`), and claims one of two things:

- `refused`: the code of the first rule the file breaks -- the code only,
  because the sentences are each language's own;
- `loads` and `extra`: the names of the models it publishes, and of the
  fields beside them.

`godot/test/ai_learning/model_file_test.gd` checks every case through
`ModelFile`, and `python/tests/test_model_file.py` through
`gameaikit.training.model_file`. Both also plant a wrong claim and watch it
fail, and the Python side checks that every code from M2 to M15 has a case:
a rule with no case could be deleted from either language with both suites
green. M1, a missing file, is a path and not content, and each side tests it
on its own. There is no M9: it was the tactical board's conventions rule,
which that game now holds itself.

A tree's own rules are M11 to M15: its answers named (`classes`, distinct
words), its nodes each a test or a leaf, a test asking about a listed
feature with a word (`is`) or a finite number (`at_most`), every child a
later node -- so a walk always ends -- and every leaf counting whole rows of
named answers, at least one. The nodes are checked first to last, each
whole, so the first wrong node is the one both languages report.

## Where the two readers had to be made to agree

Found by review, each now a case: Python's `json` accepts `NaN` and
`Infinity` and Godot's does not, so Python refuses them as M2 too; an
integer too big for a float (`1` and four hundred zeros) is infinity to
Godot and made Python's `math.isfinite` raise, so Python converts it first
and refuses it as M8; and the feature names are walked once, in order, so
`["a", "a", 1]` is "listed twice" in both. A parse error's line is counted
from 1 in both (Godot's `get_error_line()` counts from 0).

## Where the cases came from

Written by hand, one rule broken per file, each beside the sentence saying
why that rule exists. A loaded file's claims are names, which need no
arithmetic; the arithmetic of a loaded model is the learning vectors'.
