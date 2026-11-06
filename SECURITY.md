# Security

## Reporting

Report privately: use GitHub's **Report a vulnerability** on this
repository's Security tab (once the repository is public and private
vulnerability reporting is enabled on it), or email
**adalbertobosco@gmail.com**. Please do
not open a public issue for anything in the first list below. This is a
one-person project, so expect an answer within a week, not within a day.

## What is in scope

The kit's code: the Godot addons under `godot/addons/`, the examples under
`godot/game/` and `godot/game3d/`, the Python package under `python/`, the
scripts under `scripts/`, and what `make release` builds from them. The
things worth reporting are the ways that code reaches further than it says
it does:

- **A download that is not checked.** Every target that downloads -- such
  as `make bootstrap`, `make llm-bootstrap`, `make assets-3d`,
  `make rts-art`, `make fighter-sheets` and `make artgen-bootstrap` --
  fetches files from the internet and is meant to refuse any whose SHA-512
  or sha256 differs from the pinned one. A way to
  make one of them install or unpack a file it did not verify, or write
  outside the folder it names, is in scope.
- **The local LLM reaching past the machine.** `ai_llm`'s `HttpRuntime`
  talks to a llama.cpp server on `127.0.0.1`. Anything that exposes that
  server, or the game's side of the conversation, to the network by
  default is in scope.
- **A model's reply becoming an action unchecked.** Nothing an LLM returns
  may become an action in a game without passing that game's validator. A
  reply that gets an action past it -- a move that is not legal, a command
  outside the list the game offers -- is a vulnerability, not a balance
  problem.
- **A release that carries more than it should**: a file from outside the
  addon or package it is meant to ship, a secret, or a file without its
  `LICENSE` and `NOTICE`.
- **Reading a file the kit loads** -- a weights or data file, a recording,
  a scenario -- running code or writing outside the project.

## What is not

- **The games' balance.** An AI that is too strong, too weak or easy to
  exploit in play is a bug report or an idea, filed as an issue; that is
  what the examples are for.
- A machine that is already compromised, or a Godot or Python build that
  is not the pinned one.
- The engine itself, gdUnit4 or llama.cpp: report those to their own
  projects. If the kit uses one of them in a way that makes a flaw in it
  reachable, that use is in scope here.
