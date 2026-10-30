"""The registry the library hands out: the kit's techniques and a user's.

`gameaikit.techniques` lists what the kit offers by a decorator on each
technique, and what other distributions add through an entry point. These
check that the list cannot drift from the modules that own the techniques,
that a plug-in is read the two ways the docstring promises, and that a name
taken twice is refused rather than shadowed.
"""

import json
import pathlib
import unittest
from importlib import metadata

from gameaikit import techniques

REPO = pathlib.Path(__file__).resolve().parents[2]

#: A decorated Technique a test plug-in's entry point can load.
DECLARED = techniques.Technique("a-declared-one", "declared as a Technique", print)


def technique_packages() -> set[str]:
    """The Python packages the manifests of kind `technique` own."""
    owned = set()
    for path in (REPO / "modules").glob("*.json"):
        manifest = json.loads(path.read_text(encoding="utf-8"))
        if manifest["kind"] != "technique":
            continue
        for owns in manifest["owns"]:
            if owns.startswith("python/gameaikit/") and owns.endswith("/"):
                owned.add(owns.split("/")[2])
    return owned


def plugged(name: str, value: str) -> list[metadata.EntryPoint]:
    """One entry point in the kit's group, as a distribution would declare it."""
    return [metadata.EntryPoint(name, value, techniques.GROUP)]


class TheKitsOwnTechniques(unittest.TestCase):
    def test_every_technique_module_is_imported_and_nothing_else(self) -> None:
        listed = {module.split(".")[0] for module in techniques.KIT_MODULES}
        self.assertEqual(listed, technique_packages())

    def test_every_technique_package_registers_one_at_least(self) -> None:
        found = techniques.kit()
        registering = {found_one.entry.__module__.split(".")[1] for found_one in found.values()}
        self.assertEqual(registering, technique_packages())

    def test_each_says_what_it_decides_and_can_be_called(self) -> None:
        for name, found in techniques.kit().items():
            with self.subTest(name=name):
                self.assertTrue(found.about)
                self.assertTrue(callable(found.entry))
                self.assertEqual(found.source, "gameaikit")

    def test_a_name_taken_twice_is_refused(self) -> None:
        techniques.kit()
        with self.assertRaises(ValueError):
            techniques.technique("seek", "a second seek")(len)

    def test_a_technique_is_frozen(self) -> None:
        with self.assertRaises(AttributeError):
            techniques.kit()["seek"].about = "changed"


class APluggedInTechnique(unittest.TestCase):
    def test_a_plain_callable_is_wrapped_with_its_docstring(self) -> None:
        found = techniques.available(plugged("pretty-json", "json:dumps"))
        self.assertIs(found["pretty-json"].entry, json.dumps)
        self.assertEqual(found["pretty-json"].about, json.dumps.__doc__.strip().splitlines()[0])

    def test_a_declared_technique_is_kept_as_declared(self) -> None:
        found = techniques.available(plugged("a-declared-one", "tests.test_techniques:DECLARED"))
        self.assertEqual(found["a-declared-one"].about, "declared as a Technique")
        self.assertIs(found["a-declared-one"].entry, print)

    def test_it_sits_beside_the_kits_own(self) -> None:
        found = techniques.available(plugged("pretty-json", "json:dumps"))
        self.assertIn("seek", found)
        self.assertEqual(list(found), sorted(found))

    def test_it_may_not_take_a_name_the_kit_uses(self) -> None:
        with self.assertRaises(ValueError):
            techniques.available(plugged("seek", "json:dumps"))

    def test_with_none_installed_only_the_kits_are_listed(self) -> None:
        self.assertEqual(techniques.available([]), techniques.kit())


if __name__ == "__main__":
    unittest.main()
