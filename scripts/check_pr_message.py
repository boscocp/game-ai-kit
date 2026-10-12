#!/usr/bin/env python3
"""Check a pull request's own title and body, read from the environment.

A hook cannot see a pull request. The commit messages on a branch go through
`.githooks/commit-msg`, but a PR's title and body are written in a browser and
never touch it -- and a squash merge turns that body into a commit message on
`main`. So they are checked where they exist, in CI, by the same script the hook
uses rather than a second copy of the rule.

The values arrive in `PR_TITLE` and `PR_BODY` rather than on the command line: a
PR title is text a stranger can write, and interpolating it into a shell command
would evaluate it as part of that command.

Exit codes
----------
0   the title and body are fine, or there is no pull request to check
1   the message breaks a rule (printed by check_commit_msg)
2   wrong usage

Usage
-----
    PR_TITLE="feat: a thing" PR_BODY="why" check_pr_message.py
    check_pr_message.py --self-test
"""

from __future__ import annotations

import os
import pathlib
import subprocess
import sys
import tempfile

CHECKER = pathlib.Path(__file__).resolve().parent / "check_commit_msg.py"


def check(title: str, body: str, quiet: bool = False) -> int:
    """Run the commit-message rules over a title and body joined as a message."""
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as handle:
        handle.write(f"{title.strip()}\n\n{body}\n")
        path = handle.name
    try:
        done = subprocess.run([sys.executable, str(CHECKER), path],
                              capture_output=quiet, text=True)
        return done.returncode
    finally:
        os.unlink(path)


def self_test() -> int:
    failures = []
    cases = [
        ("clean", "feat: a thing", "What changed and why.\n", 0),
        ("co-author trailer", "feat: a thing",
         "What changed.\n\nCo-Authored-By: Someone <x@y>\n", 1),
        ("generated-with line", "feat: a thing",
         "What changed.\n\nGenerated with a tool\n", 1),
        ("robot emoji", "feat: a thing", "What changed.\n\n\U0001F916 by a tool\n", 1),
        ("title in Title Case", "Feat: A Thing That Was Done", "Why.\n", 1),
        ("title with no type", "just did some stuff", "Why.\n", 1),
    ]
    for label, title, body, want in cases:
        got = check(title, body, quiet=True)  # a planted finding is not a failure
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    if argv and argv[0] == "--self-test":
        return self_test()
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if argv:
        print(__doc__, file=sys.stderr)
        return 2

    title = os.environ.get("PR_TITLE")
    if not title:
        # Not a pull request build. Saying so beats a silent pass.
        print("check_pr_message: PR_TITLE is unset; nothing to check")
        return 0
    return check(title, os.environ.get("PR_BODY") or "")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
