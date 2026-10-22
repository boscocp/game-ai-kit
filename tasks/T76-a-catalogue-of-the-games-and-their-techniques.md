# T76 — A catalogue of the games and the techniques in each

Size: S · Prereqs: T75 · Files: `docs/techniques/`, `scripts/catalogue.py`, `Makefile`, `README.md`, `README.pt-BR.md`, `docs/godot/examples.md`

## Goal

The owner, 2026-10-22: "um sumário com todos jogos/demos e quais técnicas
de IA tem em cada jogo." (the whole request is quoted in T74.)

One table, in both languages: every game and demo, the command that opens
it, and the AI techniques it uses. It must not drift. Today the same
information is written by hand three times -- `README.md`'s "What it
covers", `docs/godot/examples.md`'s list (which stops at six examples of
thirteen), and the `##` help of each `demo-*` target -- and the manifests
already know the true answer: `modules/<example>.json`'s `depends_on`
lists the technique modules each example uses.

## Steps

1. **Generate, do not write**: `scripts/catalogue.py` reads
   `modules/*.json` (examples and the techniques they depend on, directly
   or through another example, such as `demo_behaviour` → `stealth`), the
   `demo-*` targets' help lines in the `Makefile`, T74's
   `non_module_techniques.json`, and a small declared input of its own,
   `docs/techniques/games.json`: for each example, the known game it is
   like (the owner's rule: build on games people already know) in both
   languages, and the keys that show the decision. It writes
   `docs/techniques/catalogue.md` and `catalogue.pt-BR.md`: a table of game
   × technique (a mark per cell linking the technique page), and per game a
   line: the command, the known game, the keys.
2. **The gate**: `scripts/catalogue.py --check` regenerates in memory and
   fails when the committed pages differ. `--self-test` with planted cases:
   a demo added to a manifest without regenerating; a technique column
   with no page; an example missing from `games.json`.
3. **A way in for a Portuguese reader**: `README.pt-BR.md`, short -- what
   the kit is, the tiers, and links to the catalogue and the technique
   pages in pt-BR -- linked from the top of `README.md`, and under T74's
   gate (anchors and code blocks equal to the parts of `README.md` it
   mirrors, declared).
4. **Wire it in**: `README.md` links the catalogue in place of repeating it
   (its own table shortened to the pieces and their pages), and
   `docs/godot/examples.md`'s partial list is replaced by a link. The gate
   gets a `Makefile` target, joins `make check`, and its self-test joins
   `make lint-selftests`.

## Acceptance

```bash
python3 scripts/catalogue.py --check
python3 scripts/catalogue.py --self-test
python3 scripts/check_translations_docs.py
make lint-modules
make lint-tasks lint-status
```

## Manual check

Pick three rows at random and open each demo: does it use exactly the
techniques the row says, and can you see each one deciding?
