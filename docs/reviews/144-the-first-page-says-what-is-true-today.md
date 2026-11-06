# Review: wave/144-the-first-page-says-what-is-true-today

T142 acts on finding 2 of `docs/reviews/open-the-repository.md`. It
rewrites the README's status line and its `ai_llm` paragraph. It ends
"What you will see" by naming the other eleven demos and linking the
catalogue. Tier 1 becomes "Python 3.12 or later" in both READMEs. The task
ids leave the first page, and both READMEs now link `CONTRIBUTING.md` and
the Windows how-to. In `ai_llm.md` and its pt-BR twin, "Where to watch
it" now names `make demo-talk`.

A fresh context reviewed PR #95 at head e87e8e5 (base origin/main), in a
throwaway detached worktree that was removed afterwards. It made no
commit, push or PR comment.

**Verdict: approve once two should-fix findings are addressed; no
blocker, four nits.** Every claim the wave added holds in the
repository. One older sentence it left in place still contradicts the
new status line. The new tier 1 note warns about macOS but not about the
Linux releases that are just as old.

## What was reviewed

- `CLAUDE.md` (invariants 1, 11 and 12), the task file, finding 2 of
  `docs/reviews/open-the-repository.md`, the PR body with its six
  decisions, and the commit message.
- The diff against `origin/main`: `README.md`, `README.pt-BR.md`,
  `docs/techniques/ai_llm.md`, `docs/techniques/ai_llm.pt-BR.md` and
  `tasks/STATUS.md`.
- The claims, checked against the tree at e87e8e5:
  - every one of the 19 techniques in the table has a `.pt-BR.md` page
    (none missing);
  - every technique row has at least one ● demo;
  - `godot/menu/catalogue.json` has 16 examples, and they are the
    table's 16 demos, so "`make menu` opens them all" holds;
  - the eleven named "other demos" are exactly the 16 minus the five
    described;
  - every demo in `catalogue.md#by-demo` has a `keys:` line;
  - `python/pyproject.toml:19` says `requires-python = ">=3.12"`;
  - the talk demo's keys, in `godot/game/talk/talk.gd:131-144`, are
    1-9, V, R and Tab;
  - recordings ship in `data/talk/recordings/*.en.json`, so the claim
    that recorded lines need no GPU holds for a fresh clone;
  - no `T<n>` is left in either README.
- Decision 3: `scripts/check_links.py` resolves GitHub-style heading
  slugs and `<a id>` anchors, not `{#...}`. That makes `#by-demo` a dead
  anchor, so leaving the anchor off the link is correct.

## What was run (green at e87e8e5)

- `make lint-translations-docs`, `lint-links`, `lint-tiers`,
  `lint-glossary`, `lint-catalogue`, `lint-tasks`, `lint-status`: each 0.
  `lint-translations-docs` accepts the new `translation_of`, so the hash
  is that of the English page without its doc-meta.

## Answers to the brief

1. **Claims on the first page.** They hold, except finding 1, an older
   sentence the wave left in place, and finding 2, the tier 1 note. All
   links resolve.
2. **Scope.** All three steps are done, and no file outside the task's
   four (plus the STATUS row) is touched.
3. **pt-BR.** It is in step with en. "nível" matches the pt-BR README's
   tier table, *addon* and *fallback* stay italicised, and the new
   paragraph says the Windows how-to is in English. The hash is right.
   One title mismatch is listed as finding 3.
4. **The implementer's decisions.**
   - 1 (five paragraphs and a pointer), 2 (no count in the status line)
     and 3 (no anchor) are sound.
   - 4 is right in spirit, but too narrow (finding 2).
   - 5 is sound.
   - 6, leaving `invalidated_if` for later, is acceptable. The same
     follow-up should take the page's other task ids (finding 6).
5. **Invariant 11.** The one commit is authored by Adalberto Pereira and
   carries no trailer. The PR title and body have no tooling byline.

## Findings

1. **The opening paragraph still says "a small turn-based strategy game"
   (should fix).** `README.md:7-8` says the addons come with "a small
   turn-based strategy game where each of them actually decides
   something". Five lines later, the new status line and the tables say
   there are 16 demos, among them real-time racing, a 3D racer, a
   fighting game, a bot match and an RTS. That is exactly what the
   task's manual check asks to remove: a sentence the rest of the page
   contradicts. The pt-BR opening (`README.pt-BR.md:8-9`, "pequenos
   jogos") already differs from en on this. Fix: "plus small games,
   most of them versions of games you know, where each of them actually
   decides something". Keep the pt-BR as it is.

2. **Tier 1 warns about macOS only, but common Linux LTS releases are
   older too (should fix).** `README.md:92` and `README.pt-BR.md:90`
   say "(`python3 --version` says; macOS's own is older)". Ubuntu 22.04
   ships 3.10 and Debian 12 ships 3.11. Both are still common, and a
   stranger on either reads this row as "Linux is fine". The old text
   said "already on Linux and macOS", so that reading is what they bring
   to it. "`python3 --version` says" is also hard to parse in a table
   cell. Fix: "Python 3.12 or later -- check with `python3 --version`;
   macOS's own and some Linux LTS releases (Ubuntu 22.04, Debian 12) are
   older". In pt-BR: "Python 3.12 ou mais novo -- confira com
   `python3 --version`; o do macOS e o de algumas versões LTS do Linux
   (Ubuntu 22.04, Debian 12) são mais antigos".

3. **The pt-BR page names the demo by a title the pt-BR menu does not
   use (nit).** `docs/techniques/ai_llm.pt-BR.md:52` says *convença o
   guarda a deixar você passar*, but `catalogue.pt-BR.md:89` and the
   pt-BR README's table (`README.pt-BR.md:64`) call it "Convença o
   guarda a abrir a porta". The old sentence only described a game to
   come. Now it names the card a reader will look for. Fix: use
   *Convença o guarda a abrir a porta*.

4. **"None has a recording yet" reads as if only the eleven lack one
   (nit).** `README.md:180` closes the paragraph about the other demos.
   The five described above have no recording either, and the old line
   ("Recordings of all five are still to be made") said so. Fix: "No
   demo has a recording yet."

5. **Two lines left unwrapped, and one parenthesis reads oddly (nit).**
   `README.md:103` is now about 95 columns, and "(a local
   OpenAI-compatible server, the tier 3 row above)" reads as if the
   server were the row. `README.md:127` kept its old length after "Until
   T27 this was `make run`." was cut. Fix: reflow both to the file's
   width, and write "(a local OpenAI-compatible server; see tier 3
   above)".

6. **`ai_llm`'s body still carries task ids a stranger cannot resolve
   (nit, follow-up).** `docs/techniques/ai_llm.md:43-44` ("T93's to
   measure"), `:65-66` ("T93 pins and measures one") and
   `ai_llm.pt-BR.md:46`, `:72`. This is outside the task, which bans ids
   from the first page only, and outside finding 2. But this page is one
   click from the README, and decision 6 already defers its
   `invalidated_if` to T139. Fix: in the owner's item 3, have the same
   edit say "the local-LLM bake-off (`docs/local-llm/bakeoff.md`)" in
   place of T93, in both languages.

## What was done about them

1. Fixed: the opening paragraph now says "plus small games, most of them
   versions of games you know"; the pt-BR one is unchanged.
2. Fixed: tier 1 names macOS and Ubuntu 22.04 and Debian 12 as older, in
   both READMEs, worded as suggested.
3. Fixed: the pt-BR page names *Convença o guarda a abrir a porta*.
   `lint-glossary` refused it (G3, and G4 for the old entry), so the
   allowlist entry in `scripts/check_glossary.py` was replaced, capital
   included because the check is case-sensitive, with one comment line.
4. Fixed: "No demo has a recording yet."
5. Fixed: both lines reflowed, and "(a local OpenAI-compatible server;
   see tier 3 above)".
6. Left as a follow-up: on the owner's list, beside the `invalidated_if`
   note, to replace T93 with the local-LLM bake-off in both languages.
