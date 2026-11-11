"""The valley's record, rules and standing, held on records the vectors do not cover.

The vectors pin exact days; these hold what must be true of any record
(T164, ADR 0025): rebuilding twice gives the same world; a record cut at
day n gives the world and the standing of day n; an unknown verb, or a
target that is a person, is refused by name. And of the authored files:
the first day is at rest, no two rules can hold at once and disagree, and
every verb, rule and weight carries its reason.
"""

import itertools
import random
import unittest

from gameaikit.valley import record
from gameaikit.valley.rules import ValleyRules
from gameaikit.valley.standing import Standing

LAST_DAY = 12


def random_deeds(rules: ValleyRules, seed: int) -> list[dict]:
    """A seeded record: about one deed a day, each a verb on a place it acts on."""
    draw = random.Random(seed)
    deeds = []
    for day in range(1, LAST_DAY + 1):
        for _ in range(draw.randint(0, 2)):
            verb = draw.choice(sorted(rules.verbs))
            deeds.append(record.make(day, verb, draw.choice(sorted(rules.verbs[verb]))))
    return deeds


def disagreements(rules: list[dict], facts: list[str]) -> list[tuple[int, int, str]]:
    """Every pair of rules that can both hold on one day and write different values to one fact.

    Two rules can both hold unless their `when`s ask one fact for
    different values; a fact either writes is then contested.
    """
    found = []
    for (first, one), (second, other) in itertools.combinations(enumerate(rules), 2):
        if any(one["when"][name] != other["when"][name] for name in set(one["when"]) & set(other["when"])):
            continue
        found += [(first, second, name) for name in set(one["then"]) & set(other["then"])
                  if one["then"][name] != other["then"][name] and name in facts]
    return found


class TheRecord(unittest.TestCase):
    def setUp(self) -> None:
        self.rules = ValleyRules.read()

    def test_a_person_as_a_target_is_refused_by_name(self) -> None:
        log = self.rules.new_record()
        planted = {"verb": "burn", "target": "villager_3"}
        self.assertIn("target", log.append(planted))
        self.assertIn("villager_3", log.append(record.make(1, "burn", "villager_3")))
        self.assertEqual(log.deeds(), [])

    def test_an_unknown_verb_is_refused_by_name(self) -> None:
        log = self.rules.new_record()
        self.assertIn("kick", log.append(record.make(1, "kick", "barn")))
        self.assertEqual(log.deeds(), [])

    def test_a_deed_read_out_cannot_change_the_record(self) -> None:
        log = self.rules.new_record()
        log.append(record.make(1, "burn", "barn"))
        log.deeds()[0]["place"] = "mill"
        self.assertEqual(log.deeds(), [record.make(1, "burn", "barn")])

    def test_a_record_of_another_version_or_none_is_refused_by_name(self) -> None:
        deed = '{"day": 1, "place": "field", "verb": "plant"}'
        self.assertIn("version 2", record.read_lines(['{"version": 2}', deed], self.rules.new_record()))
        self.assertIn("no version", record.read_lines([deed], self.rules.new_record()))
        self.assertEqual(record.read_lines(['{"version": 1}', deed], self.rules.new_record()), "")


class TheFileAppendedTo(unittest.TestCase):
    """`append_refusal`: an append reads the file first, and refuses by name."""

    HEADER = '{"version": 1}\n'
    DAY_5 = '{"day": 5, "place": "field", "verb": "plant"}\n'

    def setUp(self) -> None:
        self.rules = ValleyRules.read()

    def test_a_day_before_the_files_last_deed_is_refused_without_a_load(self) -> None:
        why = record.append_refusal(self.HEADER + self.DAY_5, self.rules.new_record(), record.make(1, "burn", "barn"))
        self.assertIn("day 1 comes after day 5", why)

    def test_a_file_of_another_version_is_refused(self) -> None:
        why = record.append_refusal('{"version": 2}\n', self.rules.new_record(), record.make(1, "burn", "barn"))
        self.assertIn("version 2", why)

    def test_a_torn_last_line_is_refused(self) -> None:
        torn = self.HEADER + '{"day": 1, "verb": "pla'
        self.assertIn("torn", record.append_refusal(torn, self.rules.new_record(), record.make(2, "burn", "barn")))

    def test_an_empty_file_with_no_header_is_refused(self) -> None:
        self.assertIn("empty", record.append_refusal("", self.rules.new_record(), record.make(1, "burn", "barn")))

    def test_a_record_in_memory_unlike_the_file_is_refused(self) -> None:
        why = record.append_refusal(self.HEADER + self.DAY_5, self.rules.new_record(), record.make(6, "burn", "barn"))
        self.assertIn("load it before appending", why)

    def test_the_loaded_record_may_append(self) -> None:
        log = self.rules.new_record()
        self.assertEqual(record.read_text(self.HEADER + self.DAY_5, log), "")
        self.assertEqual(record.append_refusal(self.HEADER + self.DAY_5, log, record.make(6, "burn", "barn")), "")


class TheRebuild(unittest.TestCase):
    def setUp(self) -> None:
        self.rules = ValleyRules.read()
        self.standing = Standing.read()

    def filled(self, seed: int) -> record.DeedLog:
        log = self.rules.new_record()
        for deed in random_deeds(self.rules, seed):
            self.assertEqual(log.append(deed), "")
        return log

    def test_rebuilding_twice_gives_the_same_world(self) -> None:
        for seed in range(20):
            log = self.filled(seed)
            self.assertEqual(self.rules.rebuild(log, LAST_DAY), self.rules.rebuild(log, LAST_DAY), seed)
            self.assertEqual(self.standing.of(log), self.standing.of(log), seed)

    def test_a_record_cut_at_day_n_gives_day_n(self) -> None:
        for seed in range(20):
            log = self.filled(seed)
            for day in range(LAST_DAY + 1):
                cut = log.cut(day)
                self.assertEqual(self.rules.rebuild(cut, day), self.rules.rebuild(log, day), (seed, day))
                self.assertTrue(all(deed["day"] <= day for deed in cut.deeds()))
                partial = [deed for deed in log.deeds() if deed["day"] <= day]
                self.assertEqual(self.standing.of(cut), {
                    virtue: sum(self.standing.weight(deed, virtue) for deed in partial)
                    for virtue in self.standing.virtues}, (seed, day))

    def test_the_contributions_name_the_deeds_that_sum_to_each_virtue(self) -> None:
        log = self.rules.new_record()
        for deed in (record.make(1, "burn", "barn"), record.make(2, "dig_well", "square"),
                     record.make(3, "plant", "field")):
            log.append(deed)
        care = self.standing.contributions(log, "care")
        fear = self.standing.contributions(log, "fear")
        self.assertEqual([found["deed"]["verb"] for found in care], ["burn", "dig_well", "plant"])
        self.assertEqual([found["deed"]["verb"] for found in fear], ["burn"])
        for virtue, found in (("care", care), ("fear", fear)):
            self.assertEqual(sum(one["weight"] for one in found), self.standing.of(log)[virtue])


class TheAuthoredFiles(unittest.TestCase):
    def setUp(self) -> None:
        self.rules = ValleyRules.read()
        self.standing = Standing.read()

    def test_the_first_day_is_at_rest(self) -> None:
        self.assertEqual(self.rules.overnight(self.rules.start), self.rules.start)

    def test_no_two_rules_can_hold_at_once_and_disagree(self) -> None:
        self.assertEqual(disagreements(self.rules.rules, list(self.rules.start)), [])

    def test_a_planted_pair_of_rules_that_disagree_is_found(self) -> None:
        planted = self.rules.rules + [{"when": {"barn.standing": True}, "then": {"market.bread": False}, "why": "x"}]
        self.assertNotEqual(disagreements(planted, list(self.rules.start)), [])

    def test_every_rule_names_known_facts_and_says_why(self) -> None:
        for rule in self.rules.rules:
            self.assertLessEqual(set(rule["when"]) | set(rule["then"]), set(self.rules.start), rule)
            self.assertTrue(rule["why"].strip(), rule)

    def test_every_verb_sets_facts_of_its_own_place_and_says_why(self) -> None:
        for verb, places in self.rules.verbs.items():
            for place, act in places.items():
                self.assertIn(place, self.rules.places, verb)
                self.assertLessEqual({f"{place}.{fact}" for fact in act["sets"]}, set(self.rules.start), (verb, place))
                self.assertTrue(act["why"].strip(), (verb, place))

    def test_every_deed_there_can_be_has_a_weight_for_each_virtue_and_a_reason(self) -> None:
        for verb, places in self.rules.verbs.items():
            for place in places:
                deed = record.make(1, verb, place)
                for virtue in self.standing.virtues:
                    self.assertIsInstance(self.standing.weight(deed, virtue), int, (verb, place, virtue))
                self.assertTrue(self.standing.why(deed).strip(), (verb, place))


if __name__ == "__main__":
    unittest.main()
