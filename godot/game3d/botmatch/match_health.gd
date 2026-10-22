## Health that comes back (T68, the owner's ask): after the rules' delay
## without a hit, a bot's health returns a little each step, as in the
## shooters people know -- Halo's shields, Call of Duty's health (the
## sources are in `docs/concepts/shooter-ai.md`). The person's bot comes
## back by the same rule: it is the same body.
##
## Health is a whole number and a step gives back a fraction of a point, so
## what is not yet a point is carried to the next step, and a hit throws it
## away with the clock. Constant time a bot a step.
##
## When not to use it: a game whose healing is a pickup or a medic -- then
## health only comes back by an errand, and this file has nothing to do.
class_name MatchHealth
extends RefCounted


## Give `bot` back what `delta` seconds of regeneration is worth, if its
## last hit is older than the rules' delay; never past the rules' cap nor
## its whole health. What it gained, in points, for the counts.
static func regenerate(rules: MatchRules, bot: MatchBot, now: float, delta: float) -> int:
	var cap: int = mini(rules.regeneration_to, rules.health)
	if now - bot.hurt_at < rules.regeneration_delay or bot.health >= cap:
		bot.regeneration_carry = 0.0
		return 0
	bot.regeneration_carry += rules.regeneration_rate * delta
	var whole: int = floori(bot.regeneration_carry)
	bot.regeneration_carry -= whole
	var gained: int = mini(whole, cap - bot.health)
	bot.health += gained
	return gained


## Seconds until `bot` begins to come back, at `now`: 0 once it has begun.
static func delay_left(rules: MatchRules, bot: MatchBot, now: float) -> float:
	return maxf(0.0, rules.regeneration_delay - (now - bot.hurt_at))
