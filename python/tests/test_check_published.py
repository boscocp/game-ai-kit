"""The record of what the store was handed, and the rules that read it (T159).

`scripts/check_published.py` needs the network and the engine, so it is
not in `make check`; its `--self-test` plants four faults and runs in
`lint-selftests`. What this holds, with neither: the committed record is
whole and consistent with itself, and the contents rules refuse what they
must and nothing more.
"""

import importlib.util
import json
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("check_published", ROOT / "scripts" / "check_published.py")


def load_gate():
    """The gate as a module; `godot_shards` is found beside it in `scripts/`."""
    sys.path.insert(0, str(ROOT / "scripts"))
    try:
        gate = importlib.util.module_from_spec(SPEC)
        # A dataclass looks its module up by name while it is being made.
        sys.modules[SPEC.name] = gate
        SPEC.loader.exec_module(gate)
        return gate
    finally:
        sys.path.remove(str(ROOT / "scripts"))


GATE = load_gate()
CLEAN = ["addons/ai_core/LICENSE", "addons/ai_core/NOTICE", "addons/ai_core/VERSION",
         "addons/ai_core/grid_graph.gd"]


class TheRecord(unittest.TestCase):
    def test_every_upload_is_whole(self) -> None:
        uploads = GATE.read_record(GATE.RECORD)
        self.assertTrue(uploads)
        for upload in uploads:
            self.assertRegex(upload.sha256, r"^[0-9a-f]{64}$")
            self.assertGreater(upload.size, 0)
            self.assertTrue(upload.download.startswith("https://store.godotengine.org/"))

    def test_the_shown_size_is_the_measured_one_in_the_stores_unit(self) -> None:
        # Measured in wave 168: the page shows bytes x 1.024 / 1000, so a
        # shown size that disagrees with the measured one is a typo here.
        for entry in json.loads(GATE.RECORD.read_text(encoding="utf-8"))["uploads"]:
            shown = float(entry["shown_size"].removesuffix(" KB"))
            self.assertAlmostEqual(entry["size"] * 1.024 / 1000, shown, places=2)

    def test_a_record_with_no_sha256_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder) / "published.json"
            path.write_text(json.dumps({"uploads": [{"download": "x", "version": "0.1.0", "size": 1,
                                                     "provenance": "unknown", "note": ""}]}))
            with self.assertRaises(GATE.Unreachable):
                GATE.read_record(path)

    def test_a_provenance_that_is_neither_a_tag_nor_unknown_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder) / "published.json"
            entry = {"download": "x", "version": "0.1.0", "sha256": "0" * 64, "size": 1,
                     "provenance": "main", "note": ""}
            path.write_text(json.dumps({"uploads": [entry]}))
            with self.assertRaises(GATE.Unreachable):
                GATE.read_record(path)


class TheRebuild(unittest.TestCase):
    """The compare, planted without a clone: `rebuilt_sha256` is the stub."""

    UPLOAD = GATE.Upload(download="planted", version="0.1.0", sha256="8" * 64, size=1,
                         provenance="v0.1.0", note="")

    def test_a_tag_that_builds_another_file_is_a_finding(self) -> None:
        with mock.patch.object(GATE, "rebuilt_sha256", return_value="1" * 64):
            found = GATE.rebuild_findings(self.UPLOAD)
        self.assertTrue(any(line.startswith("rebuild:") for line in found), found)

    def test_a_tag_that_builds_the_same_file_passes(self) -> None:
        with mock.patch.object(GATE, "rebuilt_sha256", return_value="8" * 64), \
                mock.patch("builtins.print"):
            self.assertEqual(GATE.rebuild_findings(self.UPLOAD), [])

    def test_an_unknown_provenance_is_not_rebuilt(self) -> None:
        unknown = GATE.Upload(**{**vars(self.UPLOAD), "provenance": "unknown"})
        with mock.patch.object(GATE, "rebuilt_sha256", side_effect=AssertionError("rebuilt")), \
                mock.patch("builtins.print"):
            self.assertEqual(GATE.rebuild_findings(unknown), [])


class TheIntegrity(unittest.TestCase):
    def test_a_right_hash_and_a_wrong_size_is_named(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder) / "download.zip"
            path.write_bytes(b"what the store handed out")
            upload = GATE.Upload(download="planted", version="0.1.0", sha256=GATE.sha256_of(path),
                                 size=path.stat().st_size + 1, provenance="unknown", note="")
            found = GATE.integrity_findings(path, upload)
        self.assertEqual(len(found), 1, found)
        self.assertIn("integrity: the size is", found[0])


class TheContentsRules(unittest.TestCase):
    def test_a_clean_archive_passes(self) -> None:
        self.assertEqual(GATE.contents_findings(CLEAN), [])

    def test_a_stray_path_a_demo_and_a_missing_licence_are_each_named(self) -> None:
        names = [name for name in CLEAN if not name.endswith("LICENSE")]
        names += ["README.md", "addons/ai_core/demo/scene.tscn"]
        found = "\n".join(GATE.contents_findings(names))
        self.assertIn("README.md is not under addons/ai_<name>/", found)
        self.assertIn("is in a demo/ folder", found)
        self.assertIn("addons/ai_core/ carries no LICENSE", found)

    def test_a_file_named_like_a_folder_is_not_a_folder(self) -> None:
        self.assertEqual(GATE.contents_findings([*CLEAN, "addons/ai_core/test"]), [])

    def test_an_empty_archive_is_refused(self) -> None:
        self.assertIn("contents: the archive holds no addon", GATE.contents_findings([]))


if __name__ == "__main__":
    unittest.main()
