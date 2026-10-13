# Entry point for humans, CI and agents alike.
# Every target exits non-zero on failure. If a check cannot fail, it is not a
# check -- see scripts/check_*.py, each of which carries a --self-test with a
# planted case it must reject.

SHELL := /bin/bash
TOOLCHAIN ?= /mnt/games/gamedev/toolchain
GODOT_VERSION := $(shell tr -d '[:space:]' < .godot-version)
GODOT := ./scripts/godot
PYTHON ?= python3

.DEFAULT_GOAL := help

# Gates run one at a time. Interleaved output from a parallel run makes a
# failure hard to attribute, and reading the failure is the whole point.
.NOTPARALLEL:

.PHONY: help
help: ## Show this list
	@grep -hE '^[a-z][a-zA-Z0-9_-]*:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  %-22s %s\n", $$1, $$2}'

# --- bootstrap -------------------------------------------------------------

.PHONY: bootstrap
bootstrap: ## Install the pinned Godot on the large disk (SHA-verified)
	@bash scripts/bootstrap.sh "$(TOOLCHAIN)" "$(GODOT_VERSION)"
	@$(MAKE) --no-print-directory lint-disk-layout

# --- the wave ---------------------------------------------------------------
#
# One branch per wave, and the review lands before the merge. The pre-commit
# hook refuses a commit on main, because the rule written as prose did not hold.

.PHONY: wave-start
wave-start: ## Cut a wave branch from a current main: make wave-start BRANCH=wave/NN-slug
	@test -n "$(BRANCH)" || { echo "usage: make wave-start BRANCH=wave/NN-slug" >&2; exit 2; }
	@$(PYTHON) scripts/check_branch_base.py --check-base
	@git switch -c "$(BRANCH)"
	@echo
	@echo "On $(BRANCH). When the work is done:"
	@echo "  1. make check"
	@echo "  2. have the diff reviewed by something that did not write it"
	@echo "  3. write docs/reviews/$(notdir $(BRANCH)).md"
	@echo "  4. make wave-merge"

.PHONY: wave
wave: ## Cut the branch for the next unblocked task and print its prompt
	@# Does not do the work -- there is no command that writes a wave. It puts
	@# you at the start of one: the branch cut, the task file named, and the
	@# resuming section printed, which is what a fresh session reads first.
	@$(PYTHON) scripts/next_wave.py

.PHONY: wave-next
wave-next: ## Which task and branch come next, without cutting anything
	@$(PYTHON) scripts/next_wave.py --dry-run

.PHONY: wave-merge
wave-merge: ## Merge the current wave into main, once it has been reviewed
	@$(PYTHON) scripts/check_branch_base.py --check-review
	@$(MAKE) --no-print-directory check
	@branch=$$(git rev-parse --abbrev-ref HEAD); \
	git switch main && git merge --no-ff --no-edit "$$branch" && \
	echo "merged $$branch into main"

.PHONY: lint-review
lint-review: ## This branch has a review record and may be merged
	@$(PYTHON) scripts/check_branch_base.py --check-review

# --- the gate --------------------------------------------------------------

.PHONY: check
check: check-no-engine lint-disk-layout test-godot test-vectors \
       test-search-properties test-planner-properties test-perception-properties \
       test-decisions test-demo-overlays ## Run every gate

.PHONY: check-no-engine
check-no-engine: lint-tasks lint-status lint-commits lint-renderer lint-readability lint-demos \
       lint-addon-deps lint-tiers lint-links lint-workflow lint-license \
       lint-employer-refs lint-docs-freshness lint-no-training lint-selftests \
       test-python test-models ## Every gate that does not need the engine installed
	@# CI's gate job runs exactly this. It used to hand-list the targets,
	@# because `check` includes lint-disk-layout, which cannot run where the
	@# toolchain is not installed -- two lists that drift the first time one of
	@# them gains a target.

.PHONY: lint-commits
lint-commits: ## Recent commit subjects obey the message rules
	@# The script's own docstring claimed CI ran it over the history. Nothing
	@# did: it was reachable only from the hook and from lint-selftests, so the
	@# stdin mode and the published-exceptions table served a caller that did
	@# not exist. Now it has one.
	@git log --format=%s -30 | $(PYTHON) scripts/check_commit_msg.py -

.PHONY: lint-pr-message
lint-pr-message: ## Check a PR title and body held in PR_TITLE and PR_BODY
	@# CI used to inline this, while the workflow's own header said every job
	@# runs a Makefile target and nothing else.
	@$(PYTHON) scripts/check_pr_message.py

.PHONY: lint-tasks
lint-tasks: ## Invariant 3: every acceptance criterion is a command
	@$(PYTHON) scripts/check_acceptance.py

.PHONY: lint-status
lint-status: ## The index and the task files agree
	@$(PYTHON) scripts/check_status.py

.PHONY: lint-disk-layout
lint-disk-layout: ## Nothing of the toolchain may land on the small disk
	@$(PYTHON) scripts/check_disk_layout.py

.PHONY: lint-renderer
lint-renderer: ## Renderer stays Compatibility; no 3D nodes in game/ or demos/
	@$(PYTHON) scripts/check_renderer.py

.PHONY: lint-demos
lint-demos: ## Invariant 13: every example has a target, a scene, a legend and its decision
	@$(PYTHON) scripts/check_demos.py

.PHONY: lint-readability
lint-readability: ## Invariant 1: the code is teaching material before a library
	@$(PYTHON) scripts/check_readability.py

.PHONY: lint-employer-refs
lint-employer-refs: ## Nothing of the author's day job, in the tree or the history
	@# Exit 3 means the term is in git history, which deleting a file does not
	@# fix. make flattens that to 2, so read the script's own code if it fails.
	@$(PYTHON) scripts/check_no_employer_refs.py

.PHONY: lint-docs-freshness
lint-docs-freshness: ## Every doc page declares its half-life, and is inside it
	@$(PYTHON) scripts/check_doc_freshness.py

.PHONY: lint-no-training
lint-no-training: ## Invariant 6: Python trains, GDScript only infers
	@# Exit 3 means the Python pipeline could not be run, so the one claim
	@# with teeth -- that the committed weights are its own output -- checked
	@# nothing. make flattens that to 2; call the script directly to tell the
	@# two apart. It retrains, which costs about four seconds.
	@$(PYTHON) scripts/check_no_training.py

.PHONY: lint-addon-deps
lint-addon-deps: ## Invariant 2: no addon reaches into another
	@$(PYTHON) scripts/check_addon_deps.py

.PHONY: lint-tiers
lint-tiers: ## Invariant 5: no lesson lives only above tier 1
	@$(PYTHON) scripts/check_tiers.py

.PHONY: lint-links
lint-links: ## Local markdown links resolve
	@$(PYTHON) scripts/check_links.py

.PHONY: lint-links-remote
lint-links-remote: ## Every URL answers; CI runs this, a laptop on a train does not
	@$(PYTHON) scripts/check_links.py --remote

.PHONY: lint-workflow
lint-workflow: ## CI runs Makefile targets, and reaches every gate
	@$(PYTHON) scripts/check_workflow.py

.PHONY: lint-license
lint-license: ## LICENSE and NOTICE present, and in every release artifact
	@$(PYTHON) scripts/check_license.py

.PHONY: lint-selftests
lint-selftests: ## Run every gate's own --self-test
	@$(PYTHON) scripts/run_selftests.py

.PHONY: test-python
test-python: ## Python unit tests (stdlib only, no install step)
	@$(PYTHON) -m unittest discover -s python/tests -t python -q

.PHONY: test-models
test-models: ## The properties T5 asks of the two fitted models
	@# Five commands rather than one, because each is a different claim and a
	@# failure should name which. They cost about twenty seconds between them:
	@# the pipeline is simulated, fitted and scored from scratch every time,
	@# which is the price of never having a stale number in a gate.
	@PYTHONPATH=python $(PYTHON) -m gameaikit.training.report --check
	@PYTHONPATH=python $(PYTHON) -m gameaikit.training.evaluate \
		--assert-beats-majority-baseline
	@PYTHONPATH=python $(PYTHON) -m gameaikit.training.evaluate \
		--shuffled-labels --assert-no-better-than-baseline
	@PYTHONPATH=python $(PYTHON) -m gameaikit.training.evaluate --assert-no-leak
	@PYTHONPATH=python $(PYTHON) -m gameaikit.training.evaluate \
		--assert-runs-under-seconds 30

.PHONY: train
train: ## Fit both models and publish weights.json to dist/ and to the addon
	@# Two destinations out of one fit. dist/ is the gitignored staging copy;
	@# godot/addons/ai_learning/ is the one the game loads and the one that is
	@# committed, which is why .gitignore exempts it by name.
	@#
	@# Running this does not usually change the committed file: the pipeline is
	@# deterministic, and `make lint-no-training` fails if the two have come
	@# apart. A diff here after a run is therefore news rather than noise.
	@PYTHONPATH=python $(PYTHON) -m gameaikit.training.report \
		--write $(CURDIR)/dist --write $(CURDIR)/godot/addons/ai_learning

.PHONY: test-vectors
test-vectors: test-search-vectors test-planning-vectors test-learning-vectors test-fuzzy-vectors ## Every conformance vector in spec/
	@# One target per family, so a failure names which one rather than which
	@# line of a two-command recipe. CI runs this one; `check_workflow.py`
	@# follows the prerequisites.

.PHONY: test-search-vectors
test-search-vectors: ## The search vectors, against ai_search
	@# The vectors live outside the Godot project so the Python side can be
	@# held to the same answers. Godot reads an absolute path in a
	@# non-exported build, so the directory goes in after `--`.
	@$(GODOT) --headless --path godot -s res://test/vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/search

.PHONY: test-planning-vectors
test-planning-vectors: ## The planning vectors, against ai_planning
	@# Only half of each planning vector is checked here: this side plans over
	@# the domain the JSON spells out. The other half -- that the PDDL files
	@# beside it describe the same domain -- is `make test-python`, because the
	@# reader is Python and a game does not parse a domain file in a frame.
	@$(GODOT) --headless --path godot -s res://test/planning_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/planning

.PHONY: test-learning-vectors
test-learning-vectors: ## The learning vectors, against ai_learning
	@# Half of each learning vector is checked here -- the board produces this
	@# row, and the model turns it into this number. The other half is the
	@# same two claims on the Python side, in `make test-python`, because a
	@# split between training and inference is worth what the agreement
	@# between the two halves is worth.
	@$(GODOT) --headless --path godot -s res://test/learning_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/learning

.PHONY: test-fuzzy-vectors
test-fuzzy-vectors: ## The fuzzy vectors, against ai_fuzzy
	@# The same file, read twice: here through the addon, and in
	@# `make test-python` through gameaikit.fuzzy, which also checks that the
	@# text controller beside a vector describes the same thing as its JSON.
	@$(GODOT) --headless --path godot -s res://test/fuzzy_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/fuzzy

.PHONY: test-search-properties
test-search-properties: ## A* agrees with Dijkstra, over a few hundred boards
	@$(GODOT) --headless --path godot -s res://test/search_properties.gd

.PHONY: test-planner-properties
test-planner-properties: ## A plan can be run, and an unsolvable domain says so
	@$(GODOT) --headless --path godot -s res://test/planner_properties.gd

.PHONY: test-perception-properties
test-perception-properties: ## Sight is symmetric, walls block both ways, suspicion holds in sight
	@# T14's acceptance, as a target so CI runs the same command. Four
	@# properties over three hundred generated maps, from a fixed seed.
	@$(GODOT) --headless --path godot -s res://test/perception_properties.gd

.PHONY: test-demo-overlays
test-demo-overlays: ## Every example, stepped headless: its overlay holds the AI's reasoning
	@# The engine half of invariant 13; `lint-demos` is the half without it.
	@# Neither can see the screen, and the seeing is each example's manual check.
	@$(GODOT) --headless --path godot -s res://test/demo_overlays.gd

.PHONY: test-decisions
test-decisions: ## The two fights the learned opponent has to get right, and a node
	@# T6's acceptance, as a target so that CI runs the same command. It plays
	@# against the *published* weights rather than a hand-made model, so a
	@# retrained opponent that stops taking a fight it should take fails here.
	@$(GODOT) --headless --path godot -s res://test/decision_scenarios.gd

.PHONY: test-godot
test-godot: ## Godot tests, headless (gdUnit4)
	@# --ignoreHeadlessMode is required: gdUnit4 refuses headless by default
	@# because Godot does not deliver InputEvents there. Tests in this repo
	@# must therefore never depend on simulated input -- they assert logic.
	@$(GODOT) --headless --path godot \
		-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a test

# --- looking at it ---------------------------------------------------------
#
# These open a window, so they are the two targets `make check` must never
# depend on: a gate that waits for somebody to close a window is a gate that
# hangs CI. Everything automated here runs --headless.

.PHONY: run
run: ## Play the board: click a unit, click a neighbouring cell, space ends the turn
	@$(GODOT) --path godot

.PHONY: demo-search
demo-search: ## The four searches on one board: 1-4 choose, space steps, enter finishes
	@$(GODOT) --path godot res://demos/search/search_demo.tscn

.PHONY: demo-stealth
demo-stealth: ## Cross the hall unseen: arrows walk, shift sprints, space waits, D shows danger
	@$(GODOT) --path godot res://game/stealth/stealth.tscn

# --- shipping --------------------------------------------------------------

.PHONY: release
release: ## One zip per addon and the Python wheel into dist/, attribution checked
	@# The build does not get to say it attributed anything: the same gate
	@# that reads the repository opens every archive it wrote and looks.
	@# `release.py --skip-notice` builds a release that must fail it.
	@$(PYTHON) scripts/release.py --build
	@$(PYTHON) scripts/check_license.py

# --- housekeeping ----------------------------------------------------------

.PHONY: godot-version
godot-version: ## Print the Godot the repo is pinned to, and what is installed
	@echo "pinned:    $(GODOT_VERSION)"
	@echo -n "installed: "; $(GODOT) --headless --version

.PHONY: hooks
hooks: ## Opt in to the repo's git hooks
	@git config core.hooksPath .githooks
	@echo "hooks enabled: .githooks"
