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

**The hash file is not in the repository.** An earlier version of this
docstring claimed storing a term's length was "a small thing to give away" and
that the term was "not published". A review brute-forced the entry from the
published salt and length in 0.02 seconds: for a short term the file *is* the
name, which is precisely what invariant 10 forbids.

So the list is gitignored and lives only on the machine of whoever runs this.
Build it with `--add-term`, which reads from a hidden prompt. See
`docs/adr/0005`.

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

# The hash list is hashes, so scanning it finds nothing. This file used to be
# exempt too, on the grounds that scanning the gate is circular. It is not: this
# file holds a salt and some rules, never a term. What the exemption actually
# bought was the one place in the repository where a match could be quoted while
# being documented and no gate would object -- and it was, four times. The
# comments below describe their false positives instead of reproducing them.
SKIP_PATHS = {TERMS_FILE}


def digest(term: str) -> str:
    """The stored form of a term: salted, lowercased, hex."""
    return hashlib.sha256((SALT + term.strip().lower()).encode("utf-8")).hexdigest()


def load_hashes(repo: pathlib.Path) -> set[tuple[int, str]]:
    """Read the list as (length, hash) pairs, ignoring blanks and comments.

    The length is stored because a hash cannot be searched for inside a longer
    string: without it, the only possible test is "is this whole token the
    term", and a review showed that a hyphen or a space then defeated the gate
    entirely -- `acme-corp` and `Acme Corp` passed while `ACMECORP` was caught.
    Knowing the length lets a window of that size slide along the text.

    The length makes a short term cheap to brute-force -- see the module
    docstring, which no longer claims otherwise.
    """
    path = repo / TERMS_FILE
    if not path.exists():
        return set()
    pairs = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        length, _, value = line.partition(":")
        if value and length.isdigit():
            pairs.add((int(length), value))
    return pairs


# How many separators a single match may span. One covers `acme-corp` and
# `Acme Corp`; more than that is welding unrelated words together, which a
# review measured happening on real prose: scanning 601 files of ordinary
# documentation produced a hit welded out of a URL path and the two words that
# followed it, in a file where the term appears zero times.
MAX_SEPARATORS_INSIDE_A_MATCH = 1


def squash(text: str) -> tuple[str, list[int]]:
    """Lowercase letters and digits only, plus where each came from.

    Separators are dropped rather than split on, so the term survives being
    written with a hyphen, an underscore, a space or a full stop between its
    parts. The positions come back too, so a match can be asked how much
    punctuation it had to swallow to exist.
    """
    kept, positions = [], []
    for index, char in enumerate(text.lower()):
        if char.isalnum():
            kept.append(char)
            positions.append(index)
    return "".join(kept), positions


def offending_tokens(text: str, hashes: set[tuple[int, str]]) -> set[str]:
    """Every stretch of `text` that hashes to a stored term.

    Matching is on the squashed text, so a term is found when it carries a
    suffix or has a separator inside it. Two things keep that from welding
    unrelated words together: a match may swallow at most one separator, and it
    must begin where a word begins.
    """
    flat, positions = squash(text)
    hits = set()
    for length, value in hashes:
        if length > len(flat):
            continue
        for start in range(len(flat) - length + 1):
            window = flat[start:start + length]
            if digest(window) != value:
                continue
            # How much punctuation this match had to swallow. A term written
            # with one separator is the case worth catching; three is two
            # unrelated words welded into a coincidence.
            span = positions[start + length - 1] - positions[start] + 1
            if span - length > MAX_SEPARATORS_INSIDE_A_MATCH:
                continue
            # A mention of a name starts a word. The false positive that
            # survived the separator limit sat inside a URL path: one separator,
            # and the match began in the middle of a longer word.
            # The end is deliberately not anchored, so a term with a suffix
            # glued on still matches.
            origin = positions[start]
            end = positions[start + length - 1]
            if origin > 0 and text[origin - 1].isalnum():
                continue
            # A name is not written across a line break. A wrapped URL is: a
            # commit message here wrapped one mid-word, which left the start of
            # the next line looking like a word start and fired on this
            # project's own history.
            if "\n" in text[origin:end + 1]:
                continue
            hits.add(text[origin:end + 1])
    return hits


def tree_files(repo: pathlib.Path) -> list[str]:
    """Tracked files, plus untracked ones git would let you add.

    Tracked-only was the original mistake: writing the term into a new file and
    running the gate gave a clean result, and it only appeared after `git add`.
    The moment someone most wants this gate is before the first add. Ignored
    files stay out -- they are not going anywhere.
    """
    tracked = subprocess.run(
        ["git", "-C", str(repo), "ls-files"], capture_output=True, text=True, check=True
    ).stdout.splitlines()
    untracked = subprocess.run(
        ["git", "-C", str(repo), "ls-files", "--others", "--exclude-standard"],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    return sorted(set(tracked) | set(untracked))


def read_as_text(path: pathlib.Path) -> str | None:
    """A file's text, or None when it is genuinely binary.

    Catching UnicodeDecodeError and moving on treated a latin-1 or UTF-16 text
    file exactly like a PNG: skipped, silently. A file with no NUL byte is text
    in some encoding, and prose hides in it just as well, so it is decoded
    leniently rather than dropped.
    """
    try:
        raw = path.read_bytes()
    except OSError:
        return None
    return decode_leniently(raw)


def decode_leniently(raw: bytes) -> str | None:
    """Text in whatever encoding it is in; None for genuinely binary bytes.

    UTF-16 is tried only behind its byte order mark. Without one, Python
    decodes almost any even number of bytes as UTF-16 garbage, so a latin-1
    file of even length never reached latin-1 and its term passed clean.
    """
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        try:
            return raw.decode("utf-16")
        except UnicodeError:
            return None
    if b"\x00" in raw:
        return None
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        # Latin-1 maps every byte, so this cannot fail.
        return raw.decode("latin-1")


def scan_tree(repo: pathlib.Path, hashes: set[tuple[int, str]]) -> list[str]:
    """Report forbidden terms anywhere in the working tree."""
    findings = []
    for name in tree_files(repo):
        if name in SKIP_PATHS:
            continue
        path = repo / name
        text = read_as_text(path)
        if text is None:
            continue
        for token in sorted(offending_tokens(text, hashes)):
            findings.append(f"E1 {name}: forbidden term {token!r}")
    return findings


def decode_message(raw: bytes) -> str:
    """A commit's text as UTF-8 when it is, and as latin-1 when it is not.

    Git re-encodes a message to UTF-8 on output only when it knows the
    encoding it was written in. A wrong or missing `encoding` header leaves
    the original bytes, and read as strict UTF-8 they crashed the gate with
    a traceback before the blob scan ran. Latin-1 maps every byte, so it
    cannot fail. A message is never binary, so no NUL test is needed.
    """
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("latin-1")


def scan_messages(repo: pathlib.Path, hashes: set[tuple[int, str]]) -> list[str]:
    """Report forbidden terms in the message and identities of every commit.

    Author and committer identity, not just the message. A commit authored
    from a work address carries the domain in the object itself, and the
    seeded term is derived from exactly that domain -- so this was the most
    on-point thing the scan could miss. `rev-list --objects` does not list
    commit objects with a path, so they never reached the blob loop either.

    Every ref, not only HEAD. The blobs were read with `--all` and the
    messages without it, so a finished branch that `main` never merged,
    which is published with the rest, had its messages skipped (T145).

    Each finding names its commit, so a person can find it without the term
    being read out loud.
    """
    log = subprocess.run(
        ["git", "-C", str(repo), "log", "--all",
         "--format=%x00%H%n%an%n%ae%n%cn%n%ce%n%B"],
        capture_output=True, check=True,
    )
    findings = []
    # Each record starts with a NUL, so the first piece of the split is the
    # empty text before it, not a commit.
    for record in log.stdout.split(b"\x00")[1:]:
        commit, _, text = decode_message(record).partition("\n")
        for token in sorted(offending_tokens(text, hashes)):
            findings.append(
                f"E2 commit {commit[:12]}: its message or author identity "
                f"contains the forbidden term {token!r}"
            )
    return findings


def scan_history(repo: pathlib.Path, hashes: set[tuple[int, str]]) -> list[str]:
    """Report forbidden terms in commit messages and in every blob ever committed."""
    findings = scan_messages(repo, hashes)

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
        text = decode_leniently(blob.stdout)
        if text is None:
            continue
        for token in sorted(offending_tokens(text, hashes)):
            findings.append(f"E3 history: {name} once contained the forbidden term {token!r}")
    return findings


def run(repo: pathlib.Path, check_history: bool) -> int:
    hashes = load_hashes(repo)
    if not hashes:
        # Absent is the normal state for anyone but the author: the list is
        # gitignored on purpose. Printing it on every run means the author
        # notices the day their own copy goes missing, which is the only way
        # this can fail quietly.
        print(
            f"E0 note: no {TERMS_FILE} on this machine, so nothing was checked. "
            "Build it with --add-term; it is gitignored by design (docs/adr/0005)."
        )
        return 0

    tree = scan_tree(repo, hashes)
    history = scan_history(repo, hashes) if check_history else []

    for finding in tree + history:
        print(finding)

    if history:
        return 3
    return 1 if tree else 0


# --- self-test -------------------------------------------------------------
#
# Every case builds a throwaway repository, plants a made-up term in one
# place, and states the exit code the gate owes it. The cases are grouped by
# where the term hides, one function per group, so each reads on one screen.

# Made up for the self-test, and never a real entry on anyone's list.
PLANTED_TERM = "acmecorp"


class Planted:
    """Throwaway repositories under one folder, and the failures seen so far."""

    def __init__(self, root: pathlib.Path) -> None:
        self.root = root
        self.failures: list[str] = []

    def expect(self, label: str, got: int, want: int) -> None:
        """Record a failure when the gate's exit code is not the one owed."""
        if got != want:
            self.failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(self, repo: pathlib.Path, history: bool = True) -> int:
        """Run the gate without printing, since its output may hold the term."""
        with contextlib.redirect_stdout(io.StringIO()):
            return run(repo, history)

    def git(self, repo: pathlib.Path, *args: str) -> None:
        """Run git in a repository, isolated from the user's own config."""
        subprocess.run(["git", "-C", str(repo), *args], check=True,
                       capture_output=True, env=_isolated_env())

    def add(self, repo: pathlib.Path, name: str, content: str | bytes) -> None:
        """Write a file and stage it, so the tree scan sees it as tracked."""
        path = repo / name
        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_text(content)
        self.git(repo, "add", "-A")

    def make_repo(self, name: str, terms: list[str] | None = None) -> pathlib.Path:
        """A repository with one clean commit and, by default, the planted term listed."""
        repo = self.root / name
        (repo / "scripts").mkdir(parents=True)
        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)],
                       check=True, capture_output=True)
        listed = [PLANTED_TERM] if terms is None else terms
        (repo / TERMS_FILE).write_text(
            "\n".join(f"{len(term)}:{digest(term)}" for term in listed) + "\n"
        )
        self.add(repo, "README.md", "A game kit about pathfinding and planning.\n")
        self.git(repo, "commit", "-qm", "chore: start")
        return repo


def planted_in_the_tree(planted: Planted) -> None:
    """The term in a file, tracked or not, and the files that must stay quiet."""
    secret = PLANTED_TERM
    planted.expect("clean repository", planted.quiet(planted.make_repo("clean")), 0)

    # An absent list is the normal state for anyone but the author -- it
    # is gitignored by design (docs/adr/0005). It prints a note and passes;
    # what keeps that from being invisible is that the note prints on every
    # run, and every case here proves the gate can still fail.
    planted.expect("no terms listed", planted.quiet(planted.make_repo("noterms", [])), 0)

    # Planted: the term in a file that was never added. This used to pass
    # clean, and the moment someone wants this gate is before the first add.
    untracked = planted.make_repo("untracked")
    (untracked / "draft.md").write_text(f"notes from the {secret} handbook\n")
    planted.expect("term in an untracked file", planted.quiet(untracked, history=False), 1)

    # An ignored file is not a finding: it is not going anywhere.
    ignored = planted.make_repo("ignored")
    (ignored / ".gitignore").write_text("scratch/\n")
    (ignored / "scratch").mkdir()
    (ignored / "scratch" / "notes.md").write_text(f"{secret} scratch\n")
    planted.expect("term in an ignored file", planted.quiet(ignored, history=False), 0)

    # A compound of a stored term is caught by the prefix rule.
    compound = planted.make_repo("compound")
    planted.add(compound, "y.md", f"see the {secret}ai handbook\n")
    planted.expect("compound of a stored term", planted.quiet(compound, history=False), 1)

    # An ordinary word that merely starts the same way is not a finding.
    innocent = planted.make_repo("innocent")
    planted.add(innocent, "z.md", "The acme of readable code.\n")
    planted.expect("short lookalike word", planted.quiet(innocent, history=False), 0)


def planted_in_history(planted: Planted) -> None:
    """The term committed: in a file, then deleted, then in a message or identity."""
    secret = PLANTED_TERM

    # Planted: the term in a tracked file.
    in_tree = planted.make_repo("intree")
    planted.add(in_tree, "notes.md", f"Ported from the {secret} internal repo.\n")
    planted.expect("term in the working tree", planted.quiet(in_tree, history=False), 1)

    # The same repository scanned with history: worse, and a different code.
    planted.git(in_tree, "commit", "-qm", "docs: add notes")
    planted.expect("term committed to history", planted.quiet(in_tree), 3)

    # Planted: deleting the file does not clean the history.
    (in_tree / "notes.md").unlink()
    planted.git(in_tree, "add", "-A")
    planted.git(in_tree, "commit", "-qm", "docs: remove notes")
    planted.expect("term deleted but still in history", planted.quiet(in_tree), 3)
    planted.expect("tree is clean again", planted.quiet(in_tree, history=False), 0)

    # Planted: the term inside a commit message only.
    in_message = planted.make_repo("inmessage")
    planted.add(in_message, "x.md", "ordinary text\n")
    planted.git(in_message, "commit", "-qm", f"docs: as discussed at {secret}")
    planted.expect("term in a commit message", planted.quiet(in_message), 3)

    # Planted: the term in the author identity rather than the message.
    identity = planted.make_repo("identity")
    planted.add(identity, "p.md", "ordinary\n")
    env = _isolated_env()
    env["GIT_AUTHOR_EMAIL"] = f"someone@{secret}.com"
    env["GIT_COMMITTER_EMAIL"] = f"someone@{secret}.com"
    subprocess.run(["git", "-C", str(identity), "commit", "-qm", "docs: a note"],
                   check=True, capture_output=True, env=env)
    planted.expect("term in the author identity", planted.quiet(identity), 3)


def planted_on_an_unmerged_branch(planted: Planted) -> None:
    """The term only in a message on a branch HEAD does not reach.

    The blobs were read on every ref and the messages only along HEAD, so a
    finished branch that was never merged -- and is published with the
    rest -- passed clean (T112's review, finding 9). The finding must also
    name the commit, so a person can find it without the term.
    """
    on_branch = planted.make_repo("onbranch")
    planted.git(on_branch, "switch", "-qc", "side")
    planted.add(on_branch, "s.md", "ordinary text\n")
    planted.git(on_branch, "commit", "-qm", f"docs: as discussed at {PLANTED_TERM}")
    side_commit = subprocess.run(
        ["git", "-C", str(on_branch), "rev-parse", "side"],
        check=True, capture_output=True, text=True,
    ).stdout.strip()[:12]
    planted.git(on_branch, "switch", "-q", "main")

    report = io.StringIO()
    with contextlib.redirect_stdout(report):
        got = run(on_branch, True)
    planted.expect("term in a message on an unmerged branch", got, 3)
    if f"commit {side_commit}:" not in report.getvalue():
        planted.failures.append("a message finding does not name its commit")


def planted_in_other_encodings(planted: Planted) -> None:
    """The term in bytes that are not UTF-8, and bytes that are not text at all."""
    secret = PLANTED_TERM

    # Planted: the term in a latin-1 file. Catching UnicodeDecodeError and
    # moving on treated it exactly like a PNG. Two lengths, because UTF-16
    # decodes almost any even number of bytes into garbage: tried before
    # latin-1, it swallowed the even-length file and the term passed clean.
    for label, padding in (("odd", ""), ("even", "!")):
        latin = planted.make_repo(f"latin-{label}")
        text = f"café from {secret}{padding}\n"
        planted.add(latin, "legacy.txt", text.encode("latin-1"))
        planted.expect(f"term in a latin-1 file, {label} length",
                       planted.quiet(latin, history=False), 1)

    # Planted: a message git cannot re-encode -- an unknown encoding header
    # over a latin-1 byte. Read as strict UTF-8, it raised a traceback and
    # exit 1, and the blob scan after it never ran.
    bogus = planted.make_repo("bogus-encoding")
    planted.add(bogus, "b.md", "ordinary text\n")
    message = bogus / "message.txt"
    message.write_bytes(f"docs: café at {secret}\n".encode("latin-1"))
    planted.git(bogus, "-c", "i18n.commitEncoding=bogus", "commit", "-q", "-F", str(message))
    message.unlink()
    planted.expect("term in a message git cannot re-encode", planted.quiet(bogus), 3)

    # A real binary must still be skipped, or the gate becomes noise.
    binary = planted.make_repo("binary")
    planted.add(binary, "image.png", b"\x89PNG\r\n\x1a\n\x00" + secret.encode())
    planted.expect("term-like bytes inside a binary", planted.quiet(binary, history=False), 0)


def planted_spellings(planted: Planted) -> None:
    """The term with a separator inside, and lookalikes that must not match."""
    secret = PLANTED_TERM

    # Planted: the term spelled with a separator. A hyphen or a space used
    # to defeat the prefix rule entirely.
    for label, spelling in (("hyphen", "acme-corp"), ("space", "Acme Corp")):
        separated = planted.make_repo(f"sep-{label}")
        planted.add(separated, "n.md", f"from {spelling} internal docs\n")
        planted.expect(f"term split by a {label}", planted.quiet(separated, history=False), 1)

    # Planted: the shape a review found on real documentation -- unrelated
    # words whose letters happen to spell the term once the punctuation is
    # removed. Matching across that much separator is a coincidence, not a
    # mention.
    welded = planted.make_repo("welded")
    planted.add(welded, "w.md", "see acm.e/c-o-r-p for details\n")
    planted.expect("letters welded across punctuation", planted.quiet(welded, history=False), 0)

    # Planted: the exact survivor measured on real documentation -- the
    # term's letters starting in the middle of another word.
    midword = planted.make_repo("midword")
    planted.add(midword, "m.md",
                f"see host.example/proj{secret[0]}/{secret[1:]} and co\n"
                + f"also wrap{secret[0]}/{secret[1:]} here\n")
    planted.expect("match starting mid-word", planted.quiet(midword, history=False), 0)

    # Planted: a line break inside what would otherwise match. This fired
    # on this repository's own history, where a commit message wrapped a
    # URL mid-word.
    #
    # The first version of this case put the split inside a longer word, so
    # the word-start rule above rejected it first and deleting the line-break
    # rule left the self-test green. The match now begins at a word start,
    # which leaves the line break as the only thing standing between it and
    # a finding.
    wrapped = planted.make_repo("wrapped")
    planted.add(wrapped, "wrap.md", f"see host.example/{secret[0]}\n{secret[1:]}/x\n")
    planted.expect("match spanning a line break", planted.quiet(wrapped, history=False), 0)


def self_test() -> int:
    """Run every planted case, and the usage error, in a throwaway folder."""
    with tempfile.TemporaryDirectory() as workspace:
        planted = Planted(pathlib.Path(workspace))
        planted_in_the_tree(planted)
        planted_in_history(planted)
        planted_on_an_unmerged_branch(planted)
        planted_in_other_encodings(planted)
        planted_spellings(planted)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
        planted.expect("unknown flag", extra.returncode, 2)

    for failure in planted.failures:
        print(f"self-test FAIL: {failure}")
    count = len(planted.failures)
    print(f"self-test: {'ok' if not count else str(count) + ' failure(s)'}")
    return 1 if count else 0


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
    new = (len(term.strip().lower()), digest(term))
    if new in existing:
        print("already on the list")
        return 0

    header = "" if path.exists() else (
        "# Salted SHA-256 of each forbidden term, one per line. The terms\n"
        "# themselves are deliberately not here -- see the script's docstring.\n"
        "# Add one with: python3 scripts/check_no_employer_refs.py --add-term\n"
    )
    with path.open("a", encoding="utf-8") as handle:
        handle.write(f"{header}{new[0]}:{new[1]}\n")
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
    except SystemExit as exit_request:
        # argparse raises SystemExit for `--help` too, with code 0. Catching it
        # blindly turned a successful --help into exit 2 in every gate here.
        if exit_request.code == 0:
            raise
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
