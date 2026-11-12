0.2.0 -- what changed since 0.1.0, for the person installing

Paste this into the Godot Asset Store's changelog for version 0.2.0, and
into PyPI's release description if one is asked for.

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
  takes its step among the others (a group moves as a flock).

Fixed
- Loading every addon no longer leaves scripts alive at exit: no addon
  names its own class as a value (0.1.0 printed 7 still in use, 14 leaked).

Python (gameaikit on PyPI)
- New: gameaikit.bayes, gameaikit.sifting, gameaikit.valley; the tree and
  forest trainers in gameaikit.training; opponent tree and forest in
  gameaikit.cloning; flocking in gameaikit.steering; tokens and rings in
  gameaikit.teamwork.

Godot range: 4.7 and above. Tested on 4.7.2.
