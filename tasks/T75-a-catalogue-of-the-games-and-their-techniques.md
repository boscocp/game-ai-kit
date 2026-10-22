# T75 — A catalogue of the games and the techniques in each

Size: S · Prereqs: T74 · Files: `docs/techniques/`, `scripts/catalogue.py`, `README.md`

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
   or through another example such as `demo_behaviour` → `stealth`), the
   `demo-*` targets' help lines in the `Makefile`, and the technique pages
   of T74, and writes `docs/techniques/catalogue.md` and
   `catalogue.pt-BR.md`: a table of game × technique (a mark per cell, the
   cell linking the technique page), and per game a line: the command, the
   known game it is like, the keys that show the decision.
2. **Techniques that are not modules** (MENACE, the learned checkers
   evaluation, behaviour cloning, the racing driver in `godot/demos/racing/`)
   are declared once, in the generator's input, not discovered. A planted
   case shows an undeclared one is caught by T74's page list.
3. **The gate**: `scripts/catalogue.py --check` regenerates in memory and
   fails when the committed pages differ. Planted cases: a demo added to a
   manifest without regenerating; a technique column with no page.
4. **Wire it in**: `README.md` links the catalogue in place of repeating
   it (its own table shortened to the pieces and their pages), and
   `docs/godot/examples.md`'s partial list is replaced by a link.
5. The gate joins `make check` and a module's `gates` (T58's rules).

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
