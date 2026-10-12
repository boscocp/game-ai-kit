#!/usr/bin/env python3
"""Keep the author's day job out of a personal, public repository.

The rule
--------
Nothing from the author's employer enters this repository: no company name, no
internal repository or client name, no internal measurement, no file copied
from a private repository, no work-domain example. The examples here are games.

Why the terms are stored as hashes
----------------------------------
A gate that searches for a company's name has to contain that name, and a file
saying "never mention X" is itself a mention of X. So the repository stores
**salted SHA-256 hashes** of the forbidden terms, never the terms. The script
hashes every word it finds and compares.

This is not cryptography and does not pretend to be: anyone who guesses a term
can confirm it. It stops the name from being *published*, which is the actual
requirement.

Add a term without ever writing it down:

    python3 scripts/check_no_employer_refs.py --add-term
    (the term is read from a prompt, hashed, and appended to the list)

Why the history is scanned too
------------------------------
Deleting a file does not remove it from git. A term that reached a commit is
published the moment the repository is, and no later edit fixes it. That is a
different and worse situation than a term sitting in the working tree, so it
gets its own exit code.

Exit codes
----------
0   clean
1   a forbidden term in the working tree -- fix the file
2   wrong usage, or something unreadable
3   a forbidden term in git history -- more serious: history cannot be fixed
    by deleting a file, and the repository must not be published as it stands

Usage
-----
    check_no_employer_refs.py [--repo PATH] [--no-history]
    check_no_employer_refs.py --add-term
    check_no_employer_refs.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import getpass
import hashlib
import io
import pathlib
import re
import subprocess
import sys
import tempfile

# Fixed, public, and not a secret. It only stops a plain dictionary of common
# words from matching the list by accident of reuse elsewhere.
SALT = "game-ai-kit/no-employer-refs/v1"

TERMS_FILE = "scripts/forbidden-term-hashes.txt"

# Only tokens of at least this length are considered, and only prefixes of at
# least this length are checked. Shorter than this and ordinary English starts
# colliding with the list.
MIN_TOKEN = 4

TOKEN_RE = re.compile(r"[a-z][a-z0-9_-]{2,}")

# Scanning the gate's own file would be circular, and the hash list is hashes.
SKIP_PATHS = {TERMS_FILE, "scripts/check_no_employer_refs.py"}


def digest(term: str) -> str:
    """The stored form of a term: salted, lowercased, hex."""
    return hashlib.sha256((SALT + term.strip().lower()).encode("utf-8")).hexdigest()


def load_hashes(repo: pathlib.Path) -> set[str]:
    """Read the hash list, ignoring blank lines and comments."""
    path = repo / TERMS_FILE
    if not path.exists():
        return set()
    hashes = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            hashes.add(line)
    return hashes


def offending_tokens(text: str, hashes: set[str]) -> set[str]:
    """Every token in `text` whose hash, or a prefix's hash, is on the list.

    Prefixes are checked so that one stored term covers its compounds: a term
    stored once also matches the same word with a suffix glued on.
    """
    hits = set()
    for token in set(TOKEN_RE.findall(text.lower())):
        for size in range(MIN_TOKEN, len(token) + 1):
            if digest(token[:size]) in hashes:
                hits.add(token)
                break
    return hits


def scan_tree(repo: pathlib.Path, hashes: set[str]) -> list[str]:
    """Report forbidden terms in the files git is tracking."""
    listing = subprocess.run(
        ["git", "-C", str(repo), "ls-files"], capture_output=True, text=True, check=True
    )
    findings = []
    for name in listing.stdout.splitlines():
        if name in SKIP_PATHS:
            continue
        path = repo / name
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue  # binary or unreadable: not where prose hides
        for token in sorted(offending_tokens(text, hashes)):
            findings.append(f"E1 {name}: forbidden term {token!r}")
    return findings


def scan_history(repo: pathlib.Path, hashes: set[str]) -> list[str]:
    """Report forbidden terms in commit messages and in every blob ever committed."""
    findings = []

    messages = subprocess.run(
        ["git", "-C", str(repo), "log", "--format=%H%n%B"],
        capture_output=True, text=True, check=True,
    )
    for token in sorted(offending_tokens(messages.stdout, hashes)):
        findings.append(f"E2 a commit message contains the forbidden term {token!r}")

    revisions = subprocess.run(
        ["git", "-C", str(repo), "rev-list", "--all", "--objects"],
        capture_output=True, text=True, check=True,
    )
    seen = set()
    for line in revisions.stdout.splitlines():
        parts = line.split(" ", 1)
        if len(parts) != 2:
            continue
        object_id, name = parts
        if name in SKIP_PATHS or object_id in seen:
            continue
        seen.add(object_id)
        blob = subprocess.run(
            ["git", "-C", str(repo), "cat-file", "-p", object_id],
            capture_output=True, check=False,
        )
        try:
            text = blob.stdout.decode("utf-8")
        except UnicodeDecodeError:
            continue
        for token in sorted(offending_tokens(text, hashes)):
            findings.append(f"E3 history: {name} once contained the forbidden term {token!r}")
    return findings


def run(repo: pathlib.Path, check_history: bool) -> int:
    hashes = load_hashes(repo)
    if not hashes:
        print(f"E0 {TERMS_FILE} lists no terms; this gate cannot fail as it stands")
        return 1

    tree = scan_tree(repo, hashes)
    history = scan_history(repo, hashes) if check_history else []

    for finding in tree + history:
        print(finding)

    if history:
        return 3
    return 1 if tree else 0


# --- self-test -------------------------------------------------------------


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(repo: pathlib.Path, history: bool = True) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(repo, history)

    def git(repo: pathlib.Path, *args: str) -> None:
        subprocess.run(["git", "-C", str(repo), *args], check=True,
                       capture_output=True, env=_isolated_env())

    def make_repo(root: pathlib.Path, name: str, terms: list[str] | None) -> pathlib.Path:
        repo = root / name
        (repo / "scripts").mkdir(parents=True)
        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)],
                       check=True, capture_output=True)
        if terms is not None:
            (repo / TERMS_FILE).write_text(
                "\n".join(digest(term) for term in terms) + "\n"
            )
        (repo / "README.md").write_text("A game kit about pathfinding and planning.\n")
        git(repo, "add", "-A")
        git(repo, "commit", "-qm", "chore: start")
        return repo

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)
        secret = "acmecorp"

        clean = make_repo(root, "clean", [secret])
        expect("clean repository", quiet(clean), 0)

        # Planted: an empty hash list. A gate that cannot fail is not a gate.
        expect("no terms listed", quiet(make_repo(root, "noterms", [])), 1)

        # Planted: the term in a tracked file.
        in_tree = make_repo(root, "intree", [secret])
        (in_tree / "notes.md").write_text(f"Ported from the {secret} internal repo.\n")
        git(in_tree, "add", "-A")
        expect("term in the working tree", quiet(in_tree, history=False), 1)

        # The same repository scanned with history: worse, and a different code.
        git(in_tree, "commit", "-qm", "docs: add notes")
        expect("term committed to history", quiet(in_tree), 3)

        # Planted: deleting the file does not clean the history.
        (in_tree / "notes.md").unlink()
        git(in_tree, "add", "-A")
        git(in_tree, "commit", "-qm", "docs: remove notes")
        expect("term deleted but still in history", quiet(in_tree), 3)
        expect("tree is clean again", quiet(in_tree, history=False), 0)

        # Planted: the term inside a commit message only.
        in_message = make_repo(root, "inmessage", [secret])
        (in_message / "x.md").write_text("ordinary text\n")
        git(in_message, "add", "-A")
        git(in_message, "commit", "-qm", f"docs: as discussed at {secret}")
        expect("term in a commit message", quiet(in_message), 3)

        # A compound of a stored term is caught by the prefix rule.
        compound = make_repo(root, "compound", [secret])
        (compound / "y.md").write_text(f"see the {secret}ai handbook\n")
        git(compound, "add", "-A")
        expect("compound of a stored term", quiet(compound, history=False), 1)

        # An ordinary word that merely starts the same way is not a finding.
        innocent = make_repo(root, "innocent", [secret])
        (innocent / "z.md").write_text("The acme of readable code.\n")
        git(innocent, "add", "-A")
        expect("short lookalike word", quiet(innocent, history=False), 0)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def _isolated_env() -> dict[str, str]:
    """Git environment for the self-test, independent of the user's config."""
    import os

    env = dict(os.environ)
    env.update({
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_SYSTEM": "/dev/null",
        "GIT_AUTHOR_NAME": "Self Test",
        "GIT_AUTHOR_EMAIL": "selftest@example.invalid",
        "GIT_COMMITTER_NAME": "Self Test",
        "GIT_COMMITTER_EMAIL": "selftest@example.invalid",
    })
    return env


def add_term(repo: pathlib.Path) -> int:
    """Append a term's hash to the list without the term touching the disk."""
    term = getpass.getpass("term to forbid (not echoed): ").strip()
    if not term:
        print("check_no_employer_refs: nothing entered", file=sys.stderr)
        return 2
    if len(term) < MIN_TOKEN:
        print(f"check_no_employer_refs: a term must be at least {MIN_TOKEN} characters",
              file=sys.stderr)
        return 2

    path = repo / TERMS_FILE
    existing = load_hashes(repo)
    new = digest(term)
    if new in existing:
        print("already on the list")
        return 0

    header = "" if path.exists() else (
        "# Salted SHA-256 of each forbidden term, one per line. The terms\n"
        "# themselves are deliberately not here -- see the script's docstring.\n"
        "# Add one with: python3 scripts/check_no_employer_refs.py --add-term\n"
    )
    with path.open("a", encoding="utf-8") as handle:
        handle.write(header + new + "\n")
    print(f"added; the list now has {len(existing) + 1} terms")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--repo", default=None)
    parser.add_argument("--no-history", action="store_true")
    parser.add_argument("--add-term", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit:
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)

    if args.add_term:
        return add_term(repo)

    try:
        return run(repo, check_history=not args.no_history)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"check_no_employer_refs: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
