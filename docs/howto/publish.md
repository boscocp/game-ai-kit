# Publish a release: PyPI and the Godot Asset Store

<!-- doc-meta
half_life: tool
verified_on: 2026-11-06
tier: 1
source: https://docs.godotengine.org/en/stable/community/asset_store/submitting_to_asset_store.html ; https://docs.godotengine.org/en/stable/community/asset_store/what_is_asset_store.html ; https://docs.godotengine.org/en/stable/community/asset_store/faq.html ; https://docs.godotengine.org/en/stable/community/asset_store/using_in_editor.html ; https://godotengine.org/article/introducing-the-godot-asset-store/ ; https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html ; https://github.com/godotengine/godot-asset-library/blob/master/src/Helpers/Utils.php ; https://github.com/godotengine/godot-asset-library/blob/master/src/constants.php ; https://github.com/godotengine/godot/blob/4.7.2-stable/editor/asset_library/editor_asset_installer.cpp ; https://github.com/godotengine/godot/blob/4.7.2-stable/editor/asset_library/asset_library_editor_plugin.cpp ; https://github.com/godotengine/godot/blob/4.7.2-stable/editor/settings/editor_settings.cpp ; https://docs.pypi.org/project-management/choosing-a-name/ ; https://docs.pypi.org/publishing/publishing-to-pypi/ ; https://docs.pypi.org/publishing/troubleshooting/ ; https://docs.pypi.org/your-account/two-factor-authentication/ ; https://docs.pypi.org/your-account/managing-your-account/ ; https://docs.pypi.org/trusted-publishers/creating-a-project-through-oidc/ ; https://packaging.python.org/en/latest/guides/using-testpypi/ ; https://packaging.python.org/en/latest/specifications/core-metadata/
invalidated_if: the Asset Store documents its upload format or a dependency between assets, the Asset Library goes read-only or away, Godot's installer changes how it treats an archive's top folder, PyPI changes how a first upload or a token works, or the name gameaikit is taken
teaches: none
-->

> How the owner publishes what `make release` builds: the wheel `gameaikit`
> to PyPI, and the Godot addons to Godot's store. The upload is the owner's,
> by hand, from a clean `main` ([ADR 0009](../adr/0009-the-release-is-built-by-hand.md));
> no wave (one unit of work, one branch, one reviewed pull request) publishes,
> and no workflow holds a token. Every fact below was read on 2026-11-06 at
> the source named beside it; what was not read there is marked **assumed**.

## What the stores were found to require

### Godot: the Asset Store replaced the Asset Library

| Fact | Source |
|---|---|
| The Asset Store (`store.godotengine.org`) is the Asset Library's successor; the library "should be considered deprecated, and will be set as a read-only repository in the near future". Assets were not moved; authors re-upload. | announcement of 22 May 2026; `what_is_asset_store.html`; `faq.html` |
| The store "will be fully integrated in Godot 4.7". The pinned engine, 4.7.2, talks to it: its default `asset_store/available_urls` is `https://store.godotengine.org/api/v1`, and it erases the old `asset_library/available_urls` setting on start (`editor_settings.cpp`, line 1281 at the tag). | announcement; `editor_settings.cpp` at `4.7.2-stable` |
| The documentation still calls the store "currently in beta". | `what_is_asset_store.html` |
| An asset is uploaded: "This is where you upload the actual asset files", per version, at most 1 GB a version. Several versions per asset, each with a changelog and a minimum (and maximum) Godot version. | `submitting_to_asset_store.html`; `faq.html` |
| The editor installs a download by unpacking it: Install will "unzip all the files in the archive". | `using_in_editor.html` |
| The form asks for: a publisher (name, URL slug), asset name and URL, summary, description in "proper English", tags, type (Full Project or Addon), license, a link to the source, an **AI usage disclosure ("mandatory if you use AI")**, a thumbnail and screenshots. An icon link must be a direct one, starting with `raw.githubusercontent.com` for a file on GitHub. | `submitting_to_asset_store.html` |
| The repository "must have a license file, called either 'LICENSE' or 'LICENSE.md'", holding "the license text itself and a copyright statement that includes the year(s) and copyright holder"; the store's license must match the repository's. | `submitting_to_asset_store.html` |
| Recommended, not required: files inside `addons/<asset_name>/`, a folder that "will **not** be automatically generated when a user installs your asset"; a copy of the license and readme inside the plugin folder. Required: a proper `.gitignore`, no essential submodules, it works on the stated Godot version. | `submitting_to_asset_store.html` |
| A submission enters a review queue; a rejection says why and may be resubmitted. Paid assets: not yet. | `submitting_to_asset_store.html`; `faq.html` |

The store's submission page still carries text written for the old library
beside "upload the actual asset files": "GitHub does not include submodules
in the downloaded ZIP file", and a `.gitattributes` with `export-ignore` to
remove files "from the resulting ZIP file". Those sentences describe a
download built from a repository, which the store's own upload is not. This
guide reads the upload as what the store takes, and the repository advice as
left over; the test install in [the store steps](#the-godot-asset-store) is
what settles it.

**Not documented, so assumed:** that the uploaded file is a zip (inferred:
the editor's installer opens only ZIP, "not in ZIP format" is its error);
which licenses the store's list holds (the old library's list has
`Apache-2.0`, `constants.php`); whether one asset can declare that it needs
another. The guide assumes it cannot.

### The old Asset Library, for the record

The library hosts nothing: "the Asset Library doesn't actually host any of
the assets it distributes" (the announcement). An entry names a repository
host, a URL and a **download commit**, and "The site computes the actual
download URL from this" -- on GitHub, `<repo_url>/archive/<commit>.zip`,
filtered by the repository's `.gitattributes` `export-ignore`. A **Custom**
provider names any `https://….zip` instead, and the site suggests it "for
GitHub Releases downloads" (`Utils.php`). So an entry could have pointed at
a zip `make release` built and the owner attached to a GitHub release. The
question is moot for this kit: the library is deprecated, and the pinned
editor no longer reads it (it erases the setting that named it, above).
Nothing here adds a `.gitattributes` (it would also strip GitHub's own
source archive of everything but the addons).

### How Godot 4.7.2 installs a zip, read in its source

`editor_asset_installer.cpp` at `4.7.2-stable`:

- A download from the store is opened with `open_asset(file, true)`: when
  every entry shares one top folder, that folder is **skipped**, unless it
  is `addons/`. The default target is `res://`.
- A zip opened with the AssetLib tab's **Import...** keeps its top folder.
- The dialog lets the person untick files, untick *Ignore Asset Root*, and
  *Change Install Folder*.

So `ai_search-0.1.0.zip`, whose single top folder is `ai_search/`, installs
from the store as `res://astar.gd`, `res://LICENSE`, `res://NOTICE`,
`res://README.md`, `res://VERSION`... at the project's root, unless the
person changes both settings. The classes still register (`class_name` works
anywhere), but the layout is wrong, the attribution lands on top of the
project's own files, and two addons installed this way collide on
`res://LICENSE`, `NOTICE`, `README.md` and `VERSION`. A zip whose top folder
is `addons/` installs as `res://addons/ai_search/...` with no change. This
is the one rule found that does not fit what `make release` builds; see
[what does not fit yet](#what-does-not-fit-yet).

### PyPI

| Fact | Source |
|---|---|
| `https://pypi.org/pypi/gameaikit/json` answered **404** on 2026-11-06, as did `game-ai-kit`, and both on TestPyPI. | measured with `curl` |
| A 404 is not a promise: a name may still be refused as "too similar to an existing project", prohibited, a standard-library module, or registered with no release. Only the first upload settles it. | `choosing-a-name/` |
| Every account must have two-factor authentication: "mandatory two-factor authentication (2FA) for all accounts". | `two-factor-authentication/` |
| A verified email address is required to register a new project and to upload a file. | `managing-your-account/` |
| Upload with an API token: username `__token__`, the token with its `pypi-` prefix as the password; tokens cover an account or one project. | `publishing-to-pypi/` |
| "PyPI does not allow for a filename to be reused, even once a project has been deleted and recreated." The fix is a new version. | `publishing/troubleshooting/` |
| Trusted publishing (OIDC) is for CI: a workflow exchanges an identity token. A *pending* publisher "does **not** create a project or reserve a project's name until it is actually used". | `trusted-publishers/`; `creating-a-project-through-oidc/` |
| TestPyPI is a separate site with a separate account: `twine upload --repository testpypi dist/*`, install with `--index-url https://test.pypi.org/simple/`. | `using-testpypi/` |
| The wheel's metadata is valid as written: `Metadata-Version: 2.4` is current-legal (2.6 is the newest), `License-Expression` and `License-File` exist since 2.4, `Description-Content-Type: text/markdown` with the README as the message body is the documented form. `python/README.md` has no relative links to break on PyPI. | `core-metadata/`; `scripts/release.py` `wheel_metadata` |

**Assumed, not read:** that a project-scoped token cannot exist before the
project does, so the first upload needs an account-wide token, replaced by a
project-scoped one after; that `twine check` renders the README as PyPI
will.

Trusted publishing is a workflow that publishes, which ADR 0009 rules out.
The guide uses a token, typed by hand, kept out of the repository.

## Before either store

1. The repository is public: the owner makes it so, after the two tasks
   that prepare it for strangers,
   [T143](../../tasks/T143-a-stranger-s-toolchain-goes-where-they-say.md)
   and [T144](../../tasks/T144-contributing-for-someone-outside-the-waves.md).
   The wheel's `Project-URL` and each zip's README point at
   `https://github.com/boscocp/game-ai-kit`.
2. On a clean, current `main`:

   ```bash
   git switch main && git pull --ff-only && git status --short   # prints nothing
   make check
   make release
   make library-check
   ```

   `make release` writes `dist/` from the commit at `HEAD`, never the
   working tree; `make library-check` installs the wheel and two addons
   outside the repository and runs them.
3. Tag the commit you are about to publish, so a release names its source:
   `git tag v$(cat VERSION) && git push origin v$(cat VERSION)`.

## PyPI, TestPyPI first

The uploader lives outside the repository and outside `$HOME`: invariant 8
in [CLAUDE.md](../../CLAUDE.md) keeps the whole toolchain on the large disk,
in the folder the Makefile calls `TOOLCHAIN` (override it as you would for
`make`). `--no-cache-dir` keeps pip from writing `~/.cache/pip`.

```bash
TOOLCHAIN=/mnt/games/gamedev/toolchain        # the Makefile's default
python3 -m venv "$TOOLCHAIN/publish-venv"
. "$TOOLCHAIN/publish-venv/bin/activate"
pip install --no-cache-dir twine==7.0.0
cd /path/to/game-ai-kit                         # the clean checkout make release ran in
twine check dist/gameaikit-*.whl                # the README renders, the metadata parses
```

1. **TestPyPI.** Create an account at `https://test.pypi.org/account/register/`,
   verify its email, turn on two-factor authentication, and make an
   account-wide token. Then, from the checkout,
   `twine upload --repository testpypi dist/gameaikit-*.whl` (user
   `__token__`). In a fresh environment,
   `pip install --no-cache-dir --index-url https://test.pypi.org/simple/ gameaikit`
   and run the README's first example. Look at the project page: the README,
   the licence, the source link.
2. **PyPI.** The same on `https://pypi.org`: account, verified email,
   two-factor authentication, an account-wide token for the first upload,
   `twine upload dist/gameaikit-*.whl`. Then delete that token and make one
   scoped to `gameaikit` for the next release.
3. A file name once uploaded cannot be uploaded again, so a mistake is a new
   version (bump `VERSION`, in a wave), or a yank.

Only the wheel goes up. No sdist: `scripts/release.py` builds none, and this
guide keeps it so; `pip install ./python` from a checkout is the source
route.

## The Godot Asset Store

1. Sign in at `https://store.godotengine.org` and choose **Upload Asset**;
   create the publisher.
2. Per asset: the name and summary in English; type **Addon**; license
   Apache 2.0; source link, the repository; the AI usage disclosure,
   answered by the owner; tags; a thumbnail and screenshots (the repository
   has no icon yet -- one is the owner's to make or pick).
3. **Versions:** upload the zip, name the version `$(cat VERSION)`, minimum
   Godot `4.7`, the changelog.
4. Before submitting, install the uploaded version into a blank project
   from the editor's store tab, on 4.7.2, and look where the files land.
5. Submit. It enters the review queue.

Until the layout below changes, step 4 shows the files at `res://`; do not
submit before it is fixed, or tell the person in the description to untick
*Ignore Asset Root* and set the folder to `res://addons/`.

## What does not fit yet

1. **The zip's top folder.** The store's installer skips a single top
   folder unless it is `addons/`, so the addon zips should be laid out
   `addons/ai_<name>/...`. That changes `scripts/release.py`, the
   archive rules in `scripts/check_license.py` (which look for LICENSE and
   NOTICE at the root or in the one top folder), `make library-check`, the
   README each zip carries and their planted cases: larger than this wave,
   so a task of its own before publishing,
   [T149](../../tasks/T149-addon-zips-laid-out-for-the-store.md).
2. **LICENSE carries no copyright line.** The store asks for one in the
   LICENSE file; this repository keeps `Copyright 2026 Adalberto Pereira` in
   NOTICE, as Apache-2.0 does, and LICENSE is the licence's own text, ending
   in its `Copyright [yyyy] [name of copyright owner]` template. There are
   18 copies, byte-identical today: the root's, `python/LICENSE`, and one in
   each of the 16 `godot/addons/ai_*/` folders. `check_license.py`'s rule
   L26 holds `python/LICENSE` to the root's bytes, and every zip ships the
   root's (rule L10); the addon copies are only required to exist (L4).
   Filling the line in means changing all 18 together. It is the owner's: it
   edits a licence file.
3. **One asset, or one per addon.** Six of the fifteen techniques need
   `ai_core` (`ai_adversarial`, `ai_bandit`, `ai_constraints`,
   `ai_perception`, `ai_rts_core`, `ai_search`, by their manifests'
   `depends_on`); the other nine stand alone. Nothing documented lets one
   store asset declare another. One asset for the kit --
   `addons/ai_core/` and every technique, one review, one version --
   installs complete, and the installer's checkboxes let a person leave out
   the techniques they do not want. Sixteen assets (fifteen techniques and
   `ai_core`) give each technique its own page and search hit, and sixteen
   reviews; a person who installs one of the six without `ai_core` gets a
   script that does not parse, and a README that said so. Recommended: one
   asset for the kit, built as one more zip by T149. The owner decides.

## Manual check

The owner follows this page on TestPyPI and on a store test version, and
says where it was unclear.
