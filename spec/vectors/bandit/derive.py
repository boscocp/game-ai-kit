"""Write the bandit vectors in this directory.

Imports nothing from the repository, so the choices come from neither
implementation the vectors hold. The payoffs are exact binary fractions
(halves, quarters, eighths), so every sum is exact; UCB1's bound is the one
place a logarithm and a square root enter, written as the README says:

    python3 spec/vectors/bandit/derive.py spec/vectors/bandit
"""
import json
import math
import sys


def xorshift(seed):
    state = seed & 0xFFFFFFFF or 1
    while True:
        state ^= (state << 13) & 0xFFFFFFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFFFFFF
        yield state


def run(policy, arms, exploration, epsilon, seed, payoffs, count):
    pulls, sums, chosen = [0] * arms, [0.0] * arms, []
    draws = xorshift(seed)
    for _ in range(count):
        if 0 in pulls:
            arm = pulls.index(0)
        elif arms == 1:
            arm = 0
        elif policy == "ucb1":
            total = sum(pulls)
            scores = [sums[j] / pulls[j] + exploration * math.sqrt(math.log(total) / pulls[j]) for j in range(arms)]
            arm = scores.index(max(scores))
        elif next(draws) / 4294967296.0 < epsilon:
            arm = next(draws) % arms
        else:
            means = [sums[j] / pulls[j] for j in range(arms)]
            arm = means.index(max(means))
        payoff = payoffs[arm][pulls[arm] % len(payoffs[arm])]
        pulls[arm] += 1
        sums[arm] += payoff
        chosen.append(arm)
    return chosen, pulls, sums


ROOT2 = math.sqrt(2.0)
VECTORS = {
    "ucb1-two-arms-by-hand": dict(
        description="UCB1, two arms, small enough to work by hand (the README does): each arm once, then the one that paid 1 four times running, until the other's bonus, growing with every pull it is left out of, outweighs the gap.",
        policy="ucb1", arms=2, exploration=ROOT2, epsilon=0.0, seed=1,
        payoffs=[[1.0], [0.0, 0.5]], count=7),
    "ucb1-settles-on-the-best": dict(
        description="UCB1, three arms paying 1/4, 3/4 and 1/2 on average: it tries each, keeps trying the others now and then, and pulls the best most.",
        policy="ucb1", arms=3, exploration=ROOT2, epsilon=0.0, seed=1,
        payoffs=[[0.25, 0.0, 0.5], [1.0, 0.5, 0.75], [0.5, 0.25, 0.75]], count=40),
    "ucb1-ties-go-to-the-first": dict(
        description="UCB1 with every arm paying the same: equal bounds go to the first, so it cycles in order.",
        policy="ucb1", arms=3, exploration=ROOT2, epsilon=0.0, seed=1,
        payoffs=[[0.5], [0.5], [0.5]], count=9),
    "ucb1-without-exploration-is-greedy": dict(
        description="UCB1 with the constant at 0 is greedy: the arm that paid best on its first pull is never left, though another pays more on average.",
        policy="ucb1", arms=2, exploration=0.0, epsilon=0.0, seed=1,
        payoffs=[[0.75, 0.25], [0.5, 1.0]], count=10),
    "epsilon-greedy-seeded": dict(
        description="Epsilon-greedy at 1/4, seed 7: one uniform draw a pull once every arm is tried, and below epsilon a second draw picks any arm, the best included.",
        policy="epsilon-greedy", arms=3, exploration=ROOT2, epsilon=0.25, seed=7,
        payoffs=[[0.25, 0.5], [0.75, 0.5, 1.0], [0.5, 0.0]], count=40),
    "epsilon-one-is-random": dict(
        description="Epsilon-greedy at 1 explores on every pull after the first round: two draws a pull, the arm the second one's remainder.",
        policy="epsilon-greedy", arms=4, exploration=ROOT2, epsilon=1.0, seed=1,
        payoffs=[[0.0], [0.25], [0.5], [1.0]], count=16),
    "one-arm-draws-nothing": dict(
        description="One arm: there is no choice, so no draw is spent and the arm is pulled every time.",
        policy="epsilon-greedy", arms=1, exploration=ROOT2, epsilon=0.5, seed=3,
        payoffs=[[0.5, 0.25]], count=5),
}

for name, vector in VECTORS.items():
    chosen, pulls, sums = run(vector["policy"], vector["arms"], vector["exploration"], vector["epsilon"],
                              vector["seed"], vector["payoffs"], vector.pop("count"))
    document = dict(vector, chosen=chosen, pulls=pulls, sums=sums)
    with open(f"{sys.argv[1]}/{name}.json", "w", encoding="utf-8") as out:
        out.write(json.dumps(document, indent=1) + "\n")
    print(name, "".join(map(str, chosen)), pulls)
