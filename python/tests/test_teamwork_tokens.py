"""Attack tokens' promises over random fights, and the planted pools each
check must reject: one that leaks, one whose tokens never time out, and
one that breaks a tie by the order a dictionary stored the requests in.

The vectors pin answers on stated scripts; these hold what must be true of
every fight. `godot/test/ai_teamwork/attack_tokens_test.gd` holds the same
promises for the GDScript side.
"""

import random
import unittest

from gameaikit.teamwork import tokens

FIGHTERS = 6
STEPS = 80
TRIALS = 40


class LeakyTokens(tokens.AttackTokens):
    """Grants without counting: the free count never goes down."""

    def _take(self, kind: str, cost: int) -> None:
        pass


class NeverTimesOut(tokens.AttackTokens):
    """The safety net gone: a holder that forgets keeps its token."""

    def _time_out(self, now: float) -> None:
        pass


class DictionaryOrder(tokens.AttackTokens):
    """Breaks a tie by the order the requests were stored in."""

    def _tie(self, id: str) -> int:
        return list(self._waiting).index(id)


def config(patience: int = 3, tie_seed: int = 7) -> tokens.Config:
    return tokens.Config(pools={"melee": 2, "ranged": 1}, delays={"melee": 0.5, "ranged": 2.0},
                         timeouts={"melee": 4.0, "ranged": 6.0},
                         multipliers={"busy": {"ranged": 2.0}, "idle": {"melee": 0.5, "ranged": 0.5}},
                         patience=patience, tie_seed=tie_seed)


def why_broken(pool: tokens.AttackTokens) -> str:
    """Held, counted from the holders, plus free must be the pool, never more."""
    for kind, size in pool.config.pools.items():
        if pool.held(kind) > size or pool.held(kind) + pool.free_tokens(kind) != size:
            return f"{kind}: {pool.held(kind)} held, {pool.free_tokens(kind)} free, pool {size}"
    return ""


def fight(pool: tokens.AttackTokens, seed: int) -> str:
    """A random fight; the first broken promise, or ""."""
    dice = random.Random(seed)
    for tick in range(STEPS):
        now = tick * 0.25
        for fighter in range(FIGHTERS):
            name, kind, roll = f"f{fighter}", "ranged" if fighter >= 4 else "melee", dice.random()
            if roll < 0.3:
                pool.request(name, kind, dice.randint(1, 2) if kind == "melee" else 1, dice.randint(0, 3),
                             dice.uniform(1.0, 20.0), now)
            elif roll < 0.4:
                pool.release(name, tokens.ENDED, now)
            elif roll < 0.42:
                pool.release(name, tokens.DIED, now)
        pool.step(now, dice.choice(["busy", "idle", "normal"]))
        if why_broken(pool):
            return f"step {tick}: {why_broken(pool)}"
    return ""


def forgetful_holder_keeps_it(pool: tokens.AttackTokens) -> bool:
    pool.request("forgetful", "melee", 1, 0, 1.0, 0.0)
    pool.step(0.0, "normal")
    pool.step(4.0, "normal")
    return "forgetful" in pool.holders("melee")


def winner(pool: tokens.AttackTokens, order: list[str]) -> str:
    for name in order:
        pool.request(name, "melee", 2, 0, 5.0, 0.0)
    return pool.step(0.0, "normal")[0]


class AttackTokenTests(unittest.TestCase):
    def test_never_more_held_than_the_pool(self) -> None:
        for trial in range(TRIALS):
            self.assertEqual(fight(tokens.AttackTokens(config()), trial), "")

    def test_a_pool_that_leaks_is_caught(self) -> None:
        self.assertNotEqual(fight(LeakyTokens(config()), 1), "")

    def test_a_cost_above_the_pool_is_refused_not_queued(self) -> None:
        pool = tokens.AttackTokens(config())
        self.assertEqual(pool.request("giant", "melee", 3, 9, 1.0, 0.0), tokens.REFUSED_COST)
        self.assertEqual(pool.waiting("melee"), [])

    def test_a_token_never_released_comes_back_by_timeout(self) -> None:
        self.assertFalse(forgetful_holder_keeps_it(tokens.AttackTokens(config())))
        self.assertTrue(forgetful_holder_keeps_it(NeverTimesOut(config())))

    def test_the_same_seed_gives_the_same_grants(self) -> None:
        first, second = tokens.AttackTokens(config()), tokens.AttackTokens(config())
        fight(first, 5)
        fight(second, 5)
        self.assertTrue(first.events)
        self.assertEqual(first.events, second.events)

    def test_a_tie_goes_by_the_seed_not_by_the_order_stored(self) -> None:
        winners = set()
        for tie_seed in range(8):
            one = winner(tokens.AttackTokens(config(3, tie_seed)), ["left", "right"])
            self.assertEqual(one, winner(tokens.AttackTokens(config(3, tie_seed)), ["right", "left"]))
            winners.add(one)
        self.assertEqual(winners, {"left", "right"})
        self.assertNotEqual(winner(DictionaryOrder(config()), ["left", "right"]),
                            winner(DictionaryOrder(config()), ["right", "left"]))

    def test_the_hash_is_the_one_godot_computes(self) -> None:
        # FNV-1a's published value for "a", so both languages share one hash.
        self.assertEqual(tokens.fnv1a("a"), 0xE40C292C)


if __name__ == "__main__":
    unittest.main()
