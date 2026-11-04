"""Monte Carlo tree search, the Python half of T86.

The same search as `godot/addons/ai_adversarial/mcts.gd`, over the same
interface (`AdversarialGame`) and drawing from the same generator
(`gameaikit.core`'s `Xorshift`, which `ai_core` writes for Godot), written
again so that `spec/vectors/adversarial/` can hold the two languages to the
same tree, visit for visit. Nothing is trained here: the search samples,
fits nothing, and keeps nothing between searches.

It imports nothing of any example. The two games its vectors are played on,
Nim and a dice race, are in `toy_games` and in the addon's test folder.
"""

from gameaikit.adversarial.game import AdversarialGame, Game
from gameaikit.adversarial.mcts import MctsResult, MonteCarloSearch

__all__ = ["AdversarialGame", "Game", "MctsResult", "MonteCarloSearch"]
