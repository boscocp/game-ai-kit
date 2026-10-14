# Review: wave/31-generate-your-own-art

One fresh context reviewed it, in its own git worktree, detached at the
feature commit. It read the task, the ADR, the how-to and the diff; ran
`make check`, `make lint-selftests` and the fence acceptance; exercised the
image helpers on synthetic pictures with system Pillow; checked the model
licences and hashes against the Hugging Face API; read the measurement files
under the toolchain; and ran 28 mutations and 5 gate-hole probes. It did not
run the generator, the GPU or any download, by instruction.

## What was reviewed

Commits 2b9cb7a and fdb106a on this branch:
- `tools/artgen/` -- the generator, its fetch, bootstrap and lock, the
  manifest and `model.json` -- and `scripts/artgen`, the wrapper;
- the fallback in `godot/game/art.gd` and its tests in `art_test.gd`;
- the new rules in `check_license.py` (L18-L23), `check_disk_layout.py`
  (model caches) and `check_doc_freshness.py` (`docs/howto/`);
- the three committed examples, `NOTICE`, ADR 0013, the how-to, T33, and the
  Makefile targets.

## Findings

Of 28 mutations, 17 were killed and 11 survived; all 5 gate-hole probes
passed the gates when they should not have.

### Must fix

- **`scripts/artgen --self-test` never ran, and could not fail.** The runner
  looked only at `.py` and `.sh`; and the test compared each cache with the
  toolchain the script had just built them from, so a toolchain under
  `$HOME` passed. No planted case.
- **L22 was a substring test.** A NOTICE naming the model only to deny it
  ("not Tongyi-MAI/Z-Image-Turbo, and not Apache-2.0") passed; checking only
  the model, or only the licence, both survived.
- **An example's model was taken on its word.** A wrong revision passed, and
  an unknown model passed as a prefix of the one in NOTICE.
- **ADR 0013 claimed the rules held more than they do**: a generated picture
  copied over a CC0 one, with its sha256 entered in `LICENCES.md` under the
  pack's name, passes, and nothing mechanical can tell.
- **An orphan `.import` in the examples folder passed**: L16 no longer looked
  there.
- **`reduce()` gave a palette slot to black**, the colour transparent cells
  became: four colours asked for four came out three.
- **`enclosed_background` was a global colour key**, the thing its docstring
  said the code avoided: it emptied a lime tunic, and a green object on green
  became a fully transparent picture, saved without a word.

### Should fix

- The lock installs only on CPython 3.14, x86_64 Linux, and bootstrap did not
  check; a distribution upgrade would break the environment silently.
- Sizes left from when klein was the default ("about 24 GB", "a model of
  about 17 GB").
- The size table in the ADR quoted four of seven pictures; the seventh moved
  24%.
- The ADR's numbers came from probe scripts not in the repository.
- Task step 2: nothing recorded what made a person's generated set.
- Smaller: `--style` unknown was a traceback; an unused parameter; a
  missing docstring and type; an unexplained 24.
- `Art.texture` asked the resource loader on every call (12.6 µs, measured);
  pointing it at the raw path, and swapping the loader for `file_exists`,
  both survived.
- `check_disk_layout.py`: torch's and Triton's paths had no planted case,
  and are shared with other projects.
- Wording: the fence ("no gate reaches it") is stricter than true, since
  `make check` reads the manifest; Z-Image's licence URL was not pinned; the
  tokenizer had no hash; the LoRA's CC0 data claim was not marked as a claim.

### Notes

- Checked and true: 63 packages, 7 GB; 54-55 GB of weights; Z-Image 13.5 s a
  picture and 8.26 GB; klein 8.38 GB and 3.4-3.7 s; the LoRA really is
  rsLoRA 64/128; the examples' sha256s; nothing new under `$HOME`; all three
  pinned revisions exist and are Apache-2.0.
- With a person's generated art present, all 599 tests stayed green.

## What was done about them

- **`scripts/artgen --self-test`** checks that the toolchain is not under
  `$HOME`, every cache is inside it, and Hugging Face is offline, with a
  planted case for the first and last, each matched on its own message; the
  wrapper refuses to run on any of them. `run_selftests.py` now runs scripts
  with no suffix, with a planted case. Both mutations of the new checks go
  red.
- **L22** wants `repo (licence` on one line, with planted cases for a denial,
  the model alone and the licence alone. **L24** is new: an example's model
  must be one `model.json` pins at that revision, its licence is taken from
  there and must be allowed (Apache-2.0), with five planted cases. **L16**
  runs in the examples folder. All six mutations of these go red.
- **The ADR and the gate's docstring** say what the rules hold and what they
  cannot.
- **The generator**: the palette is taken from opaque pixels; enclosed
  background must be a patch at least half a percent of the picture; a
  sprite left almost empty is an error, not a file; a green subject names its
  own background (the trees ask for magenta); `--style` unknown is exit 2;
  `made-by.json` records what made each generated picture. Checked on
  synthetic pictures: an O's inside cleared, a small lime button kept, four
  colours kept as four, green on green refused.
- **Bootstrap** refuses a Python other than 3.14 and rebuilds an environment
  that no longer runs. Sizes, the full size table, the probes' provenance,
  the LoRA's claim, the fence's exact statement and the pinned licence URL
  are corrected or added.
- **`Art.texture`** caches by folder and path; two new tests catch the two
  surviving mutations, and both were planted again and went red.
- **`check_disk_layout.py`**: planted cases for torch and Triton, and a
  comment on why shared caches are reported anyway.
- **Left, on purpose:** the `before_test` pin only matters where a person has
  generated art, so it cannot fail in CI; and the CC0-row lie stays review's
  to catch.

The full set was regenerated with the fixed generator to check it end to
end. The fixes were not reviewed by a second fresh context.
