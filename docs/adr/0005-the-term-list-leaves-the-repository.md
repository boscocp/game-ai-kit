# 0005 — The forbidden-term list leaves the repository

Status: accepted · 2026-10-12 (wave 06)

## Context

Invariant 10 says nothing from the author's employer enters this repository. The
gate enforcing it has to know the employer's name, and a file saying "never
mention X" is itself a mention of X. The first answer was to store salted
SHA-256 hashes instead of the terms.

A review broke that in 0.02 seconds. The seeded term is four characters, the
salt is a literal in the script, and the file stores each term's length — which
had been added so a sliding window could catch `acme-corp` and `Acme Corp`.
Brute-forcing 36⁴ candidates recovers the term immediately. The docstring's
claim that "the term is not published" was false, and the gate enforcing
invariant 10 was violating it.

## Decision

`scripts/forbidden-term-hashes.txt` is gitignored. It is built locally with
`check_no_employer_refs.py --add-term`, which reads from a hidden prompt so the
term reaches neither a file in the repository nor a shell history.

When the list is absent the gate prints that it checked nothing and exits 0.

## Alternatives considered

- **Accept it and record it.** The employer's name is not a secret; the gate
  exists to catch an accidental mention, not to withstand an attack. Rejected by
  the owner: a recoverable hash in a public repository is the name in the
  repository, and the invariant says nothing, not nothing-in-plain-text.
- **Store longer, more distinctive terms** (a full domain, an internal
  repository name). Raises the brute-force cost usefully, but does not protect
  the short name, which is the easiest one to type by accident.
- **A slow KDF (scrypt, PBKDF2).** Would make brute force impractical. Rejected
  by measurement, not by taste: the scan slides a window and hashes every
  position, already 0.3s per term per megabyte with SHA-256. A deliberately slow
  hash turns that into hours.
- **Removing the hash from git history.** Not done here; it is a separate
  decision, and the repository has no remote yet. Recorded so it is not
  forgotten.

## Consequences

- The gate is strong for the one person who can actually commit the employer's
  name, and silent for everyone else. That asymmetry is the point: a contributor
  cloning this repository has no reason to type it.
- Exiting 0 when the list is absent is a deliberate fail-open. What stops it
  being invisible is that the note prints on **every** run of `make check`, so a
  list that goes missing is seen rather than assumed.
- CI does not have the list, and so does not run this check. The author's
  machine does, and the author is where the risk is.
- **The hashes already committed stay in history**, and the term is recoverable
  from them by the same attack. Removing them means rewriting history, which is
  cheap today — no remote, nothing published — and expensive later.
