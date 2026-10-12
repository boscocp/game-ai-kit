# 0003 — Apache-2.0, and what attribution actually obliges

Status: accepted · 2026-10-12 (T0)

## Context

The author wants the kit to be usable in other people's games, and wants to be
credited for it. Those two wishes pull in opposite directions: the stronger the
credit obligation, the fewer people adopt.

## Decision

Apache-2.0, with a `NOTICE` file that names the copyright holder and asks — but
does not require — a line in the game's credits.

## Alternatives considered

- **MIT.** The de facto standard in game development; Godot itself is MIT.
  Equivalent in practice, but Apache-2.0 adds the NOTICE obligation and an
  explicit patent grant for one line more of ceremony.
- **CC-BY-4.0.** Real attribution: name, title, link, and a statement of
  changes. Written for creative work, ambiguous over source code, and poorly
  regarded as a dependency licence. It may still suit the prose and diagrams
  later; it does not suit the libraries.
- **Attribution Assurance License.** Literally what was asked for: it obliges
  displaying the author's attribution when the program starts. Rejected — it is
  obscure, almost never used, and nobody puts a stranger's name on their splash
  screen. It would cost all adoption to buy a credit nobody grants willingly.

## Consequences

- Redistribution must carry `LICENSE` and `NOTICE`. In practice the author's
  name appears on a third-party-licenses screen. It does **not** oblige a line
  in the game's credits, and this is stated plainly in the README rather than
  left as a false expectation.
- `check_license.py` enforces the copies: repository root, every addon that has
  a `plugin.cfg` (because the Asset Library ships one addon at a time), and
  every zip under `dist/`.
