"""Markov decision processes, solved: value iteration and policy iteration (T98).

`model` is a finite MDP written out as a table, `solve` the two solvers
AIMA gives (4th ed., 17.2), `maze` T97's maze made into an MDP from its
own rules, `publish` the policy and values Godot looks up, and `measure`
the MDP's play against a greedy controller. Everything here runs in
Python; the game only reads what `publish` wrote (invariant 6).
"""
