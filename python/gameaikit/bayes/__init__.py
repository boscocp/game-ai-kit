"""A Bayesian network: how likely something unseen is, from the evidence seen.

The Python half of `godot/addons/ai_bayes/` (T115), written again so the
conformance vectors in `spec/vectors/bayes/` can hold the two languages to
the same answers, and so AIMA's burglary network can be asked with no
engine. The tables are written by hand, in data; nothing here learns them.

    network.py  variables, parents and tables, asked by enumeration
                (AIMA 4th ed., fig. 13.10), and what each piece of
                evidence did to the answer
"""

from gameaikit.bayes.network import BayesNetwork, most_moved

__all__ = ["BayesNetwork", "most_moved"]
