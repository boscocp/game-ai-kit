<!-- For the owner: paste everything below this comment into the Godot
Asset Store's changelog for version 0.2.0, then add the zip's sha256 line
at the end (publish.md). Not this comment. -->
0.2.0 -- what changed since 0.1.0

New addons
- ai_bayes: BayesNetwork, a discrete Bayesian network with exact inference
  by enumeration.
- ai_sifting: SiftPattern and StorySifter, story sifting over an event log
  (Felt-style patterns with variables, order and "unless"); read-only.

New classes in existing addons
- ai_learning: LearnedTree and LearnedForest, a decision tree and a random
  forest trained in Python and only evaluated in Godot.
- ai_steering: Flock, with SeparationBehaviour, AlignmentBehaviour and
  CohesionBehaviour (Reynolds' three rules).
- ai_teamwork: AttackTokens and EngagementRings: who may attack a target
  now, and where the others stand on rings round it while they wait.
- ai_rts_core: GakRtsCrowd, a port for how a unit following a flow field
  takes its step among the others; its default steps straight, as 0.1.0
  did. Not yet a promised name (ADR 0024).

Changed
- ai_llm: rule R9 of LlmValidator (and the Python validator) now also
  refuses Unicode format characters in a speech -- zero-width characters,
  bidirectional overrides, the soft hyphen. Text that needs one (an emoji
  joined by U+200D, Persian with U+200C) is refused. is_refused_by_r9 is new and public.

Fixed
- Loading every addon no longer leaves scripts alive at exit: no addon
  names its own class as a value (0.1.0 printed 7 still in use, 14 leaked).

Python (gameaikit on PyPI)
- New: gameaikit.bayes, gameaikit.sifting; the tree and forest trainers
  in gameaikit.training; flocking in gameaikit.steering; tokens and rings
  in gameaikit.teamwork. The same R9 change in gameaikit.llm.

Godot range: 4.7 and above. Tested on 4.7.2.
