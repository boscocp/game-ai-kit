# Review: wave/152-a-publishing-guide-checked-against-the-stores

T147 writes `docs/howto/publish.md`: what the Godot Asset Store, the old
Asset Library and PyPI require, each read at its source on 2026-11-06, the
owner's steps from a clean `main`, TestPyPI first, and what does not fit
yet. ADR 0009 is revisited. No script, gate or manifest changed in the
first head; nothing was published.

A fresh context reviewed PR #102 at head 96978b4. **Verdict: changes
requested, no blocker: eight findings and six nits.**

## What was reviewed

- The PR title and body with its five numbered owner decisions, the task
  file, ADR 0009, `docs/howto/publish.md` in full, and the sources it cites:
  the store's and library's pages, `Utils.php`, the 4.7.2 installer and
  editor settings, PyPI's documentation.
- What the guide's claims touch elsewhere: the modules' `depends_on`, every
  LICENSE copy, `docs/godot/addon-anatomy.md`, both READMEs,
  `docs/techniques/using-the-library.md`, `release.py`'s README text.

## Findings

1. "The library never sees the zips; one repository is one archive" is
   wrong: `Utils.php` has a Custom download provider that returns any
   `https://….zip`, advised for GitHub Releases. Moot on 4.7.2, whose
   `editor_settings.cpp` (line 1281) erases `asset_library/available_urls`.
   The PR body's "the recollection was right" repeats the error.
2. "Every technique needs `ai_core`" is false: by `depends_on`, six of
   fifteen do. The one-asset reasoning and the "parse errors" claim must be
   honest about the other nine.
3. `docs/godot/addon-anatomy.md` still says the zips unzip into
   `addons/<name>/`, now contradicted.
4. README's "Nothing is published to the Asset Library yet" names the
   deprecated store.
5. ADR 0009's "two of its sentences were wrong": the second is not in the
   ADR but in the README `release.py` writes and `using-the-library.md`.
6. The follow-up task the guide and ADR announce is not linked.
7. The LICENSE copyright item names two copies of eighteen and cites L25,
   where byte-equality is L26.
8. `pip install twine` writes `~/.cache/pip` (invariant 8); the toolchain
   path is hard-coded where the Makefile's `TOOLCHAIN` is overridable; no
   `cd` into the checkout before `twine check`.

Nits: 9, the store's page keeps library-era text beside "upload the actual
files" (name the tension, cite the announcement and `using_in_editor.html`);
10, the icon must be a direct link; 11, PyPI documents 2FA and file-name
reuse (cite, not "assumed"), and a verified email; 12, ADR 0009 never
mentions an sdist; 13, the root file list omits NOTICE and VERSION, and two
flat zips collide; 14, gloss T143/T144, invariant 8, L-rules and "a wave"
for a stranger, and link the guide from both READMEs.

## What was done about them

All fourteen applied on this branch:

1. The guide and ADR say the library hosts nothing, normally builds
   `<repo>/archive/<commit>.zip`, and a Custom provider can name any zip;
   moot because 4.7.2 erases the setting (cited). The PR body is corrected.
2. Six of fifteen, named; the other nine stand alone; the one-asset
   reason is now one entry to maintain plus the six.
3. `addon-anatomy.md` gains a "Read again on 2026-11-06" note pointing at
   the guide and T149; `verified_on` bumped, two sources added.
4. README names the Asset Store and PyPI and links the guide; README.pt-BR
   gains the same sentence.
5. ADR 0009 now says "one of its sentences, and the README each zip
   carries", naming `release.py` and `using-the-library.md`.
6. T149 opened (`tasks/T149-addon-zips-laid-out-for-the-store.md`, one
   STATUS row) and linked from the guide, the ADR
   and `addon-anatomy.md`.
7. All 18 copies named, L26, L10 and L4 explained.
8. `pip install --no-cache-dir twine==7.0.0` into `$TOOLCHAIN/publish-venv`,
   and a `cd` into the checkout.
9-14. Applied as asked; PyPI's 2FA, verified email and file-name reuse are
   now cited facts, the sdist is the guide's own decision citing
   `release.py`.

While the findings were applied, the owner decided the PR's five items
(2026-11-06, "pode seguir o recomendado nas 5 decisões"), all as
recommended. The guide, ADR 0009 and T149 now state them as decided: the
`addons/ai_<name>/` layout, one kit asset, and the copyright line in all
18 LICENSE copies are T149's, before any store submission; the AI usage
disclosure is the owner's at submission; PyPI by hand with a token.
