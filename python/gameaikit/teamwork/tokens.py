"""Who may attack a target now: attack tokens, lent and given back.

The tier-1 half of `godot/addons/ai_teamwork/attack_tokens.gd`. The target
owns a pool per attack kind; an attack costs one token or more, as
Kingdoms of Amalur's attack weights do against the player's attack
capacity [Dawe 2013], and DOOM (2016) sets the counts by difficulty
[Thompson 2018]. Waiting requesters are served by a rule written down --
the passed over first, then priority, waiting longest, nearest, and a
seeded hash -- never by the order a dictionary stored them in. A token
comes back when the attack ends, the holder is interrupted or dies, the
game revokes it, or it times out; a timer, stretched or shrunk by how busy
the player is, spaces the grants of each kind.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

WAITING = "waiting"
HOLDING = "holding"
REFUSED_COST = "refused_cost"
REFUSED_KIND = "refused_kind"
REFUSED_HOLDING = "refused_holding"
GRANTED = "granted"
WITHDRAWN = "withdrawn"
ENDED = "ended"
INTERRUPTED = "interrupted"
DIED = "died"
REVOKED = "revoked"
TIMED_OUT = "timed_out"
RETURN_REASONS = (ENDED, INTERRUPTED, DIED, REVOKED)


@dataclass
class Config:
    """The pool's numbers, all data: a difficulty table fills one.

    Every kind needs a timeout, finite and above zero: a pool without one
    is refused, so a holder that forgets never blocks its kind for ever.
    """

    pools: dict[str, int]
    delays: dict[str, float] = field(default_factory=dict)
    timeouts: dict[str, float] = field(default_factory=dict)
    multipliers: dict[str, dict[str, float]] = field(default_factory=dict)
    patience: int = 3
    tie_seed: int = 0


@dataclass
class _Waiter:
    """One entry of the queue: who asks, for what, since when, passed how often."""

    id: str
    kind: str
    cost: int
    priority: int
    distance: float
    asked_at: float
    passed: int = 0


@dataclass
class _Holder:
    """One token lent: of which kind, how many units, since when."""

    kind: str
    cost: int
    since: float


def fnv1a(text: str) -> int:
    """A 32-bit FNV-1a hash: the tie-break, the same in GDScript."""
    value = 2166136261
    for byte in text.encode("utf-8"):
        value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
    return value


def config_problem(config: Config) -> str:
    """Why `config` cannot run a pool, or "": every kind needs a timeout."""
    for kind in config.pools:
        limit = config.timeouts.get(kind, math.inf)
        if not math.isfinite(limit) or limit <= 0:
            return f"the kind {kind} has no timeout"
    return ""


class AttackTokens:
    """One target's pool: request, step, release, revoke, withdraw."""

    def __init__(self, config: Config) -> None:
        problem = config_problem(config)
        if problem:
            raise ValueError(f"AttackTokens: {problem}")
        self.config = config
        self.events: list[dict] = []
        self._free = dict(config.pools)
        self._next_grant = {kind: -math.inf for kind in config.pools}
        self._waiting: dict[str, _Waiter] = {}
        self._holding: dict[str, _Holder] = {}
        self._now = 0.0

    def request(self, id: str, kind: str, cost: int, priority: int, distance: float, now: float) -> str:
        """WAITING, HOLDING, or a refusal by name.

        A cost above the pool, or a holder asking for another kind, is
        refused now. Asking again for the same kind and cost keeps the
        place; another kind or cost withdraws the old request and waits
        from now.
        """
        self._now = now
        if kind not in self.config.pools:
            return REFUSED_KIND
        if cost < 1 or cost > self.config.pools[kind]:
            return REFUSED_COST
        if id in self._holding:
            return HOLDING if self._holding[id].kind == kind else REFUSED_HOLDING
        waiter = self._waiting.get(id)
        if waiter and waiter.kind == kind and waiter.cost == cost:
            waiter.priority, waiter.distance = priority, distance
            return WAITING
        self.withdraw(id, now)
        self._waiting[id] = _Waiter(id, kind, cost, priority, distance, now)
        return WAITING

    def withdraw(self, id: str, now: float) -> bool:
        """Take a waiter that changed its mind out of the queue, and log it."""
        self._now = now
        if id not in self._waiting:
            return False
        self.events.append({"at": now, "id": id, "kind": self._waiting.pop(id).kind, "what": WITHDRAWN})
        return True

    def release(self, id: str, reason: str, now: float) -> bool:
        """Give a token back at once; the dead and interrupted also leave the queue."""
        self._now = now
        if reason in (DIED, INTERRUPTED):
            self._waiting.pop(id, None)
        if id not in self._holding or reason not in RETURN_REASONS:
            return False
        self._return(id, reason)
        return True

    def revoke_kind(self, kind: str, now: float) -> list[str]:
        """Take back every token of `kind`; the holders, by name."""
        revoked = self.holders(kind)
        for id in revoked:
            self.release(id, REVOKED, now)
        return revoked

    def step(self, now: float, state: str) -> list[str]:
        """Time out the forgotten, then grant what each kind's timer and pool allow.

        `state` is read at a grant: it sets the wait until the next grant
        of that kind, and a later change of state does not move that time.
        """
        self._now = now
        self._time_out(now)
        granted = []
        for kind in sorted(self.config.pools):
            granted += self._grant_kind(kind, now, state)
        return granted

    def delay_for(self, kind: str, state: str) -> float:
        """The base delay times the player state's factor."""
        factors = self.config.multipliers.get(state, {})
        return self.config.delays.get(kind, 0.0) * factors.get(kind, 1.0)

    def free_tokens(self, kind: str) -> int:
        """Tokens of `kind` free now."""
        return self._free.get(kind, 0)

    def held(self, kind: str) -> int:
        """Counted from the holders, so held + free must equal the pool."""
        return sum(holder.cost for holder in self._holding.values() if holder.kind == kind)

    def holders(self, kind: str) -> list[str]:
        """Who holds a token of `kind`, in name order."""
        return sorted(id for id, holder in self._holding.items() if holder.kind == kind)

    def waiting(self, kind: str) -> list[str]:
        """Who waits for `kind`, in the order they would be served."""
        queue = [waiter for waiter in self._waiting.values() if waiter.kind == kind]
        return [waiter.id for waiter in sorted(queue, key=self._order_of)]

    def passed_over(self, id: str) -> int:
        """How many grants of its kind `id` was passed over for, or -1."""
        return self._waiting[id].passed if id in self._waiting else -1

    def _grant_kind(self, kind: str, now: float, state: str) -> list[str]:
        # The first in the queue gets a token, or no one does: a heavy
        # attack that does not fit yet is not overtaken by light ones.
        granted = []
        while now >= self._next_grant[kind]:
            queue = self.waiting(kind)
            if not queue or self._waiting[queue[0]].cost > self._free[kind]:
                break
            self._grant(self._waiting[queue[0]], now)
            for id in queue[1:]:
                self._waiting[id].passed += 1
            granted.append(queue[0])
            self._next_grant[kind] = now + self.delay_for(kind, state)
        return granted

    def _grant(self, waiter: _Waiter, now: float) -> None:
        del self._waiting[waiter.id]
        self._holding[waiter.id] = _Holder(waiter.kind, waiter.cost, now)
        self._take(waiter.kind, waiter.cost)
        self.events.append({"at": now, "id": waiter.id, "kind": waiter.kind, "what": GRANTED})

    def _take(self, kind: str, cost: int) -> None:
        self._free[kind] -= cost

    def _time_out(self, now: float) -> None:
        expired = [id for id, holder in self._holding.items()
                   if now - holder.since >= self.config.timeouts.get(holder.kind, math.inf)]
        for id in sorted(expired):
            self._return(id, TIMED_OUT)

    def _return(self, id: str, reason: str) -> None:
        holder = self._holding.pop(id)
        self._free[holder.kind] += holder.cost
        self.events.append({"at": self._now, "id": id, "kind": holder.kind, "what": reason})

    def _order_of(self, waiter: _Waiter) -> tuple:
        patient = waiter.passed >= self.config.patience
        return (0.0 if patient else 1.0, 0.0 if patient else float(-waiter.priority),
                waiter.asked_at, waiter.distance, float(self._tie(waiter.id)), waiter.id)

    def _tie(self, id: str) -> int:
        return fnv1a(f"{self.config.tie_seed}:{id}")
