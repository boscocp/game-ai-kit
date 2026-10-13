# T7 — Close the vertical slice

Size: M · Prereqs: T3, T4, T6 · Files: `docs/`, `README.md`, `scripts/release.py`

## Goal

Make the slice something a stranger can use and learn from: one page per
half-life layer for each technique, a README that shows rather than claims, and
a release step that cannot produce an artifact missing its attribution.

## Steps

1. For each of search, planning and learning: a `docs/concepts/` page (why it
   works), a `docs/godot/` page (how to wire it here), and where relevant a
   `docs/local-llm/` page. Each with a `doc-meta` block.
2. A README with a recording of the game and of the search demo.
3. ADRs for the decisions taken along the way that are not yet written down.
4. `make release`: stamp `VERSION`, build one zip per addon, build the Python
   wheel, and verify every artifact carries `LICENSE` and `NOTICE`.

## Acceptance

```bash
make check
make release
python3 scripts/check_license.py
python3 scripts/check_doc_freshness.py
python3 scripts/check_tiers.py
```

The release step proving it can refuse, rather than being trusted:

```bash
python3 scripts/release.py --build --skip-notice --output /tmp/bad-release
! python3 scripts/check_license.py --repo /tmp/bad-release
```

## Manual check

Hand the README to someone who has never opened Godot and watch where they get
stuck. That is the page that needs rewriting, whatever the gates say.

Record the game (`make run`, through one blue turn so its reasons appear) and
the search demo (`make demo-search`, A\* and Dijkstra one after the other), and
put both in the README's "What you will see" section. No command here can do
it: `--headless` uses the dummy rendering driver and nothing is rasterised.
