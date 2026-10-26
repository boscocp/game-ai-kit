# Conformance vectors: the model file

<!-- doc-meta
half_life: structure
verified_on: 2026-10-26
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
`bias`. Anything else at the top level is the publishing game's, handed to
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
fail, and the Python side checks that every code from M2 to M10 has a case:
a rule with no case could be deleted from either language with both suites
green. M1, a missing file, is a path and not content, and each side tests it
on its own. There is no M9: it was the tactical board's conventions rule,
which that game now holds itself.

## Where the cases came from

Written by hand, one rule broken per file, each beside the sentence saying
why that rule exists. A loaded file's claims are names, which need no
arithmetic; the arithmetic of a loaded model is the learning vectors'.
