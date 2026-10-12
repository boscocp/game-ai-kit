#!/usr/bin/env python3
"""Fail a markdown link that points nowhere.

The rule
--------
Every link in this repository's markdown resolves. A dead link in teaching
material is worse than a missing one: the reader follows it, loses the thread,
and stops trusting the rest of the page.

Two halves, deliberately split
------------------------------
The **local** half -- links to files and anchors in this repository -- runs in
`make check`, because it costs nothing and is nobody's network.

The **remote** half needs `--remote`, and CI runs it. Keeping it out of the
default means a gate does not start failing because a laptop is on a train, and
keeping it in CI means it still fails somewhere.

A URL that is known to be unreachable goes in `docs/links-exceptions.txt`, one
per line, followed by **a reason of at least three words**. An exception with no
reason does not count and is reported, because "we knew about that one" with
nothing after it is how an exceptions file turns into a graveyard.

Exit codes
----------
0   every link resolves, or is excepted with a reason
1   a link does not resolve (each one printed)
2   wrong usage, or no markdown where it was expected

Usage
-----
    check_links.py [--repo PATH] [--remote]
    check_links.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

EXCEPTIONS_FILE = "docs/links-exceptions.txt"
MIN_REASON_WORDS = 3
TIMEOUT_SECONDS = 20

# `[text](target)`, with the target stopping at a space (which starts a title).
LINK_RE = re.compile(r"\[[^\]]*\]\(\s*([^)\s]+)")

SKIPPED_SCHEMES = ("mailto:", "data:", "#")


def markdown_files(repo: pathlib.Path) -> list[pathlib.Path]:
    """Every markdown file git is tracking or would let you add."""
    listings = []
    for args in (["ls-files"], ["ls-files", "--others", "--exclude-standard"]):
        listings += subprocess.run(
            ["git", "-C", str(repo), *args], capture_output=True, text=True, check=True
        ).stdout.splitlines()
    return [repo / name for name in sorted(set(listings)) if name.endswith(".md")]


def load_exceptions(repo: pathlib.Path) -> tuple[set[str], list[str]]:
    """Excepted URLs, plus complaints about entries with no real reason."""
    path = repo / EXCEPTIONS_FILE
    if not path.exists():
        return set(), []

    excepted, problems = set(), []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        url, _, reason = line.partition(" ")
        if len(reason.split()) < MIN_REASON_WORDS:
            problems.append(
                f"K4 {EXCEPTIONS_FILE}:{number} {url} has no reason of at least "
                f"{MIN_REASON_WORDS} words"
            )
            continue
        excepted.add(url)
    return excepted, problems


def check_local(path: pathlib.Path, repo: pathlib.Path, targets: list[str]) -> list[str]:
    """Report a link to a file in this repository that is not there."""
    findings = []
    for target in targets:
        if target.startswith(("http://", "https://")) or target.startswith(SKIPPED_SCHEMES):
            continue
        # An anchor on a local path still names a file.
        file_part = target.split("#", 1)[0]
        if not file_part:
            continue
        resolved = (path.parent / file_part).resolve()
        if not resolved.exists():
            findings.append(f"K1 {path.relative_to(repo)}: {target} does not exist")
    return findings


def check_remote(path: pathlib.Path, repo: pathlib.Path, targets: list[str],
                 excepted: set[str]) -> list[str]:
    """Report a URL that does not answer."""
    findings = []
    for target in sorted(set(targets)):
        if not target.startswith(("http://", "https://")) or target in excepted:
            continue
        request = urllib.request.Request(target, method="HEAD", headers={
            "User-Agent": "Mozilla/5.0 (compatible; game-ai-kit link check)",
        })
        try:
            urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS)
        except urllib.error.HTTPError as error:
            # Some hosts refuse HEAD but serve GET.
            if error.code in (403, 405):
                continue
            findings.append(f"K2 {path.relative_to(repo)}: {target} answered {error.code}")
        except (urllib.error.URLError, OSError) as error:
            findings.append(f"K3 {path.relative_to(repo)}: {target} unreachable ({error})")
    return findings


def run(repo: pathlib.Path, remote: bool) -> int:
    files = markdown_files(repo)
    if not files:
        print(f"K0 no markdown under {repo} -- this gate would pass on an empty tree")
        return 1

    excepted, findings = load_exceptions(repo)
    for path in files:
        targets = LINK_RE.findall(path.read_text(encoding="utf-8"))
        findings += check_local(path, repo, targets)
        if remote:
            findings += check_remote(path, repo, targets, excepted)

    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(repo: pathlib.Path, remote: bool = False) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(repo, remote)

    def build(root: pathlib.Path, name: str, files: dict[str, str]) -> pathlib.Path:
        repo = root / name
        repo.mkdir(parents=True)
        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)],
                       check=True, capture_output=True)
        for relative, text in files.items():
            path = repo / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        return repo

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        expect("links that resolve", quiet(build(root, "good", {
            "README.md": "See [the guide](docs/guide.md) and [a heading](#a-heading).\n",
            "docs/guide.md": "# A heading\n",
        })), 0)

        # Planted: no markdown at all.
        bare = build(root, "bare", {"x.txt": "nothing\n"})
        expect("no markdown", quiet(bare), 1)

        # Planted: a local link to a file that is not there.
        expect("dead local link", quiet(build(root, "dead", {
            "README.md": "See [the guide](docs/missing.md).\n",
        })), 1)

        # A link with an anchor still names a real file.
        expect("link with an anchor", quiet(build(root, "anchor", {
            "README.md": "See [a part](docs/guide.md#somewhere).\n",
            "docs/guide.md": "# Somewhere\n",
        })), 0)

        # A remote URL is not a local link, and the local half ignores it.
        expect("remote link, local half", quiet(build(root, "remote", {
            "README.md": "See [the docs](https://example.invalid/nothing).\n",
        })), 0)

        # Planted: an exception with no reason. "We knew about it" is not one.
        expect("exception with no reason", quiet(build(root, "noreason", {
            "README.md": "See [the guide](docs/guide.md).\n",
            "docs/guide.md": "# A heading\n",
            EXCEPTIONS_FILE: "https://example.invalid/x known\n",
        })), 1)

        # An exception with a real reason is accepted.
        expect("exception with a reason", quiet(build(root, "reason", {
            "README.md": "See [the guide](docs/guide.md).\n",
            "docs/guide.md": "# A heading\n",
            EXCEPTIONS_FILE: "https://example.invalid/x not published yet, 404 by design\n",
        })), 0)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--repo", default=None)
    parser.add_argument("--remote", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)
    try:
        return run(repo, args.remote)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"check_links: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
