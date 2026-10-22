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
	@# The toolchain just installed, not the default path: CI installs under
	@# its temp directory, and the first CI run failed here looking at the
	@# author's /mnt/games instead.
	@GAK_TOOLCHAIN="$(TOOLCHAIN)" $(MAKE) --no-print-directory lint-disk-layout

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
	@echo "  1. make check-affected BASE=origin/main"
	@echo "  2. push, and open the pull request (gh pr create)"
	@echo "  3. have the diff reviewed by something that did not write it,"
	@echo "     and apply what it found on this branch"
	@echo "  4. write docs/reviews/$(notdir $(BRANCH)).md"
	@echo "  5. make wave-merge, which waits for CI to go green"

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
wave-merge: ## Squash-merge the wave's pull request once it is reviewed and CI is green
	@# Since wave 63 a wave lands by pull request, as desk-panel does: the
	@# check is CI's on the pull request (`make check-affected`), not a second
	@# local run of all of `make check`, and the full check runs on main
	@# after the merge. The review record is still refused if missing. The
	@# wait is for GitHub to register the checks of the commit just pushed;
	@# without it `gh pr checks` can report none, and that is a refusal. And
	@# the merge names the commit that was reviewed and checked: a push from
	@# somewhere else in between makes GitHub refuse it. The subject is said
	@# outright, the title `lint-pr-message` held to 72 plus " (#NN)": for a
	@# one-commit pull request GitHub would otherwise use the commit's own
	@# subject, which the hook allows up to 80, and add the number past it.
	@$(PYTHON) scripts/check_branch_base.py --check-review
	@branch=$$(git rev-parse --abbrev-ref HEAD); \
	head=$$(git rev-parse HEAD); \
	git push --quiet origin "$$branch" && sleep 15 && \
	gh pr checks "$$branch" --watch --fail-fast && \
	subject=$$(gh pr view "$$branch" --json title,number --jq '.title + " (#" + (.number|tostring) + ")"') && \
	gh pr merge "$$branch" --squash --delete-branch --match-head-commit "$$head" --subject "$$subject" && \
	git switch main && git pull --ff-only --quiet && \
	echo "merged $$branch into main"

.PHONY: lint-review
lint-review: ## This branch has a review record and may be merged
	@$(PYTHON) scripts/check_branch_base.py --check-review

# --- the gate --------------------------------------------------------------

.PHONY: check
check: check-no-engine lint-disk-layout test-godot test-vectors \
       test-search-properties test-planner-properties test-planner-benchmark test-perception-properties \
       test-decisions test-demo-overlays test-menu-walk test-replay test-opponent-levels test-opponent-properties \
       test-clone-rows test-inference-budget test-clone-report test-difficulty-knobs \
       test-rts-budget test-rts-simulation test-rts-match test-steering-properties \
       test-racing-ladder test-racing-does-not-cheat test-game3d-floor test-botmatch-effects \
       test-racing3d-car test-racing3d-effects test-racing3d-ladder test-racing3d-does-not-cheat test-racing3d-you-drive ## Run every gate

.PHONY: check-no-engine
check-no-engine: lint-tasks lint-status lint-commits lint-renderer lint-no-assets lint-readability lint-demos \
       lint-addon-deps lint-modules lint-tiers lint-links lint-workflow lint-license \
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

.PHONY: lint-no-assets
lint-no-assets: ## ADR 0018: nothing from a 3D pack is tracked, and every manifest row has a sha256
	@$(PYTHON) scripts/check_no_assets.py

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
	@# two apart. It retrains everything it checks, about two minutes,
	@# nearly all of it checkers self-play and matches (N7).
	@$(PYTHON) scripts/check_no_training.py

.PHONY: lint-addon-deps
lint-addon-deps: ## Invariant 2: no addon reaches into another
	@$(PYTHON) scripts/check_addon_deps.py

.PHONY: lint-modules
lint-modules: ## Every file owned by one module, every dependency declared (T58)
	@# What a wave tests is chosen from these manifests, so a dependency the
	@# code has and the manifest lacks is a test that silently stops running.
	@$(PYTHON) scripts/check_modules.py

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
	@PYTHONPATH=python $(PYTHON) -m gameaikit.tactical.report --check
	@PYTHONPATH=python $(PYTHON) -m gameaikit.tactical.evaluate \
		--assert-beats-majority-baseline
	@PYTHONPATH=python $(PYTHON) -m gameaikit.tactical.evaluate \
		--shuffled-labels --assert-no-better-than-baseline
	@PYTHONPATH=python $(PYTHON) -m gameaikit.tactical.evaluate --assert-no-leak
	@PYTHONPATH=python $(PYTHON) -m gameaikit.tactical.evaluate \
		--assert-runs-under-seconds 30

.PHONY: train
train: ## Fit both models and publish weights.json to dist/ and to the tactical game
	@# Two destinations out of one fit. dist/ is the gitignored staging copy;
	@# godot/game/tactical/ is the one the game loads and the one that is
	@# committed, which is why .gitignore exempts it by name.
	@#
	@# Running this does not usually change the committed file: the pipeline is
	@# deterministic, and `make lint-no-training` fails if the two have come
	@# apart. A diff here after a run is therefore news rather than noise.
	@PYTHONPATH=python $(PYTHON) -m gameaikit.tactical.report \
		--write $(CURDIR)/dist --write $(CURDIR)/godot/game/tactical

.PHONY: train-checkers
train-checkers: ## Self-play, fit the checkers evaluation, play the match, and publish all three to the game
	@# About two minutes. N7 in lint-no-training runs the same pipeline and
	@# fails if the published file is not what it produces.
	@PYTHONPATH=python $(PYTHON) -m gameaikit.checkers.report --write $(CURDIR)/godot/game/checkers

.PHONY: train-menace
train-menace: ## Train MENACE from its seed and publish its beads to the tic-tac-toe game
	@# Deterministic: `make lint-no-training` trains again and fails if the
	@# committed file has come apart from what this writes.
	@PYTHONPATH=python $(PYTHON) -m gameaikit.menace.report --write $(CURDIR)/godot/game/tictactoe

.PHONY: test-vectors
test-vectors: test-search-vectors test-planning-vectors test-learning-vectors test-fuzzy-vectors test-menace-vectors test-checkers-vectors test-ngram-vectors test-cloning-vectors test-combat-vectors test-steering-vectors test-teamwork-vectors test-racing3d-vectors ## Every conformance vector in spec/
	@# One target per family, so a failure names which one rather than which
	@# line of a two-command recipe. CI runs this one; `check_workflow.py`
	@# follows the prerequisites.

.PHONY: test-search-vectors
test-search-vectors: import ## The search vectors, against ai_search
	@# The vectors live outside the Godot project so the Python side can be
	@# held to the same answers. Godot reads an absolute path in a
	@# non-exported build, so the directory goes in after `--`.
	@$(GODOT) --headless --path godot -s res://test/ai_search/vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/search

.PHONY: test-planning-vectors
test-planning-vectors: import ## The planning vectors, against ai_planning
	@# Only half of each planning vector is checked here: this side plans over
	@# the domain the JSON spells out. The other half -- that the PDDL files
	@# beside it describe the same domain -- is `make test-python`, because the
	@# reader is Python and a game does not parse a domain file in a frame.
	@$(GODOT) --headless --path godot -s res://test/ai_planning/planning_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/planning
	@# The tactical board's own domain (T11) is a vector too, beside its PDDL.
	@$(GODOT) --headless --path godot -s res://test/ai_planning/planning_vectors_runner.gd \
		-- $(CURDIR)/spec/pddl

.PHONY: test-learning-vectors
test-learning-vectors: import ## The learning vectors, against ai_learning
	@# Half of each learning vector is checked here -- the board produces this
	@# row, and the model turns it into this number. The other half is the
	@# same two claims on the Python side, in `make test-python`, because a
	@# split between training and inference is worth what the agreement
	@# between the two halves is worth.
	@$(GODOT) --headless --path godot -s res://test/tactical/learning_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/learning

.PHONY: test-ngram-vectors
test-ngram-vectors: import ## The n-gram vectors, against ai_opponent
	@# The same files are read by `make test-python` through gameaikit.ngram.
	@$(GODOT) --headless --path godot -s res://test/ai_opponent/ngram_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/ngram

.PHONY: test-cloning-vectors
test-cloning-vectors: import ## The cloning vectors, against ai_learning's softmax model and case table
	@# The same files are read by `make test-python` through gameaikit.cloning.
	@$(GODOT) --headless --path godot -s res://test/ai_learning/cloning_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/cloning

.PHONY: test-combat-vectors
test-combat-vectors: import ## The combat vectors, against the tactical board's fight
	@# The same files are read by `make test-python` through gameaikit.dataset.combat.
	@$(GODOT) --headless --path godot -s res://test/tactical/combat_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/combat

.PHONY: test-fuzzy-vectors
test-fuzzy-vectors: import ## The fuzzy vectors, against ai_fuzzy
	@# The same file, read twice: here through the addon, and in
	@# `make test-python` through gameaikit.fuzzy, which also checks that the
	@# text controller beside a vector describes the same thing as its JSON.
	@$(GODOT) --headless --path godot -s res://test/ai_fuzzy/fuzzy_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/fuzzy

.PHONY: test-checkers-vectors
test-checkers-vectors: import ## The checkers rules and evaluation vectors, against the game
	@# The other half is `make test-python`: the same two files read through
	@# gameaikit.checkers, the Python that self-plays and fits (T32).
	@$(GODOT) --headless --path godot -s res://test/checkers/checkers_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/checkers

.PHONY: test-menace-vectors
test-menace-vectors: import ## The MENACE vectors, against the game's bead player
	@# The other half is `make test-python`. Each case carries the uniform draw
	@# itself, because Python's generator and Godot's differ.
	@$(GODOT) --headless --path godot -s res://test/tictactoe/menace_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/menace

.PHONY: test-teamwork-vectors
test-teamwork-vectors: import ## Positions, influence, commander and confidence, against ai_teamwork (T51)
	@# The other half is `make test-python`.
	@$(GODOT) --headless --path godot -s res://test/ai_teamwork/teamwork_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/teamwork

.PHONY: test-racing3d-vectors
test-racing3d-vectors: import ## The 3D driver's decisions from stated snapshots, against RaceDriver3D (T54)
	@# The other half is `make test-python`.
	@$(GODOT) --headless --path godot -s res://test/racing3d/racing3d_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/racing3d

.PHONY: test-steering-vectors
test-steering-vectors: import ## The steering trajectories, against ai_steering
	@# The other half is `make test-python`. The tolerance is sized for
	@# Vector2's 32-bit floats: docs/godot/vector2-is-single-precision.md.
	@$(GODOT) --headless --path godot -s res://test/ai_steering/steering_vectors_runner.gd \
		-- $(CURDIR)/spec/vectors/steering

.PHONY: test-steering-properties
test-steering-properties: import ## Arrive comes to rest, seek never does, no force breaks its limit (T22)
	@$(GODOT) --headless --path godot -s res://test/ai_steering/steering_properties.gd

.PHONY: test-racing-ladder
test-racing-ladder: import ## Every racing level finishes, in order, a second a lap apart (T23)
	@$(GODOT) --headless --path godot -s res://test/demo_racing/racing_ladder.gd

.PHONY: test-racing-does-not-cheat
test-racing-does-not-cheat: import ## One physics for every car, no limit broken, no knob moved mid-race (T23)
	@$(GODOT) --headless --path godot -s res://test/demo_racing/racing_does_not_cheat.gd

.PHONY: test-botmatch-effects
test-botmatch-effects: import ## What claims, the commander, retreat and the rest each do, over 187 bot matches in parallel shards (T51, T72)
	@# The matches are independent: scripts/godot_shards.py plays them in one
	@# Godot process a core and merges the counts, the serial run's numbers bit
	@# for bit. The serial run is still `./scripts/godot --headless --path
	@# godot -s res://test/botmatch/botmatch_effects.gd`.
	@$(PYTHON) scripts/godot_shards.py res://test/botmatch/botmatch_effects.gd

.PHONY: test-search-properties
test-search-properties: import ## A* agrees with Dijkstra, over a few hundred boards
	@$(GODOT) --headless --path godot -s res://test/ai_search/search_properties.gd

.PHONY: test-planner-properties
test-planner-properties: import ## A plan can be run, and an unsolvable domain says so
	@$(GODOT) --headless --path godot -s res://test/tactical/planner_properties.gd

.PHONY: test-behaviour-benchmark
test-behaviour-benchmark: import ## GOAP against the HTN on the guard: worlds and microseconds a plan (T15), printed
	@# A measurement, not a gate: the worlds are held by behaviour_test.gd,
	@# and the microseconds are one machine's.
	@$(GODOT) --headless --path godot -s res://test/demo_behaviour/behaviour_benchmark.gd

.PHONY: test-planner-benchmark
test-planner-benchmark: import ## Every search over the tactical domain: h_max stays shortest, the guesses visit fewer worlds, a budget holds (T11)
	@$(GODOT) --headless --path godot -s res://test/tactical/planner_benchmark.gd

.PHONY: test-rts-budget
test-rts-budget: import ## The real-time core holds its frame share at 200 units, and ai_core does not (T19)
	@# A measurement with a pass mark, like test-inference-budget: the old
	@# core's ~50 ms a step is printed beside the new core's layers.
	@$(GODOT) --headless --path godot -s res://test/ai_rts_core/rts_core_budget.gd

.PHONY: test-rts-match
test-rts-match: import ## A whole RTS match ends the same way twice, inside its frame budget, and the commander beats the queues alone (T20)
	@$(GODOT) --headless --path godot -s res://test/rts/rts_match.gd

.PHONY: rts-measure
rts-measure: import ## Slow (minutes): the commander vs the queues, STRIPS vs HTN, each level vs the next, the seat's bias (T20)
	@$(GODOT) --headless --path godot -s res://test/rts/rts_measure.gd

.PHONY: test-rts-simulation
test-rts-simulation: import ## The RTS match replays from its seed, only commands change it, fog holds, counters add up (T19)
	@$(GODOT) --headless --path godot -s res://test/ai_rts_core/rts_simulation.gd

.PHONY: test-perception-properties
test-perception-properties: import ## Sight is symmetric, walls block both ways, suspicion holds in sight
	@# T14's acceptance, as a target so CI runs the same command. Four
	@# properties over three hundred generated maps, from a fixed seed.
	@$(GODOT) --headless --path godot -s res://test/stealth/perception_properties.gd

.PHONY: import
import: ## Import the art, which a fresh checkout cannot load without
	@# Measured on 4.7.2: a project with no .godot/ folder answers
	@# load("res://assets/....png") with "No loader found", because a run imports
	@# nothing -- only the editor does, and `--import` is the editor doing it
	@# headless. Cheap when nothing changed. See docs/godot/importing-art.md.
	@#
	@# `--import` exits 0 on a picture it could not read, prints an ERROR, and
	@# rewrites that picture's committed .import to `valid=false` -- which then
	@# survives fixing the picture. So an ERROR is a failure here, and a
	@# sidecar marked invalid is too.
	@out=$$($(GODOT) --headless --path godot --import 2>&1) || \
		{ echo "$$out" >&2; echo "import: the engine refused to import the project" >&2; exit 2; }; \
	if echo "$$out" | grep -q "ERROR"; then \
		echo "$$out" | grep -A2 "ERROR" >&2; echo "import: the engine reported an error" >&2; exit 2; fi; \
	if grep -rl "^valid=false" godot/assets --include='*.import' >&2; then \
		echo "import: the sidecars above are marked invalid; restore them with" >&2; \
		echo "  git checkout -- <sidecar>, fix the picture, and import again" >&2; exit 2; fi

.PHONY: test-menu-walk
test-menu-walk: import ## The menu, walked: every card plays its example, Escape frees it and comes back
	@# T24. `lint-demos` holds the catalogue to the Makefile; this holds the
	@# menu to the catalogue, in the engine.
	@$(GODOT) --headless --path godot -s res://test/menu/menu_walk.gd

.PHONY: test-demo-overlays
test-demo-overlays: import ## Every example, stepped headless: its overlay holds the AI's reasoning
	@# The engine half of invariant 13; `lint-demos` is the half without it.
	@# Neither can see the screen, and the seeing is each example's manual check.
	@$(GODOT) --headless --path godot -s res://test/menu/demo_overlays.gd

.PHONY: test-decisions
test-decisions: import ## The two fights the learned opponent has to get right, and a node
	@# T6's acceptance, as a target so that CI runs the same command. It plays
	@# against the *published* weights rather than a hand-made model, so a
	@# retrained opponent that stops taking a fight it should take fails here.
	@$(GODOT) --headless --path godot -s res://test/tactical/decision_scenarios.gd

.PHONY: test-godot
test-godot: import ## Godot tests, headless (gdUnit4)
	@# --ignoreHeadlessMode is required: gdUnit4 refuses headless by default
	@# because Godot does not deliver InputEvents there. Tests in this repo
	@# must therefore never depend on simulated input -- they assert logic.
	@$(GODOT) --headless --path godot \
		-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a test

# --- only what a change touches (T58) --------------------------------------
#
# `make check` runs every gate; a wave runs `make check-affected`, which asks
# scripts/affected.py which modules the change touches and which modules use
# them, and runs the lints plus those modules' gates. The three `-some`
# targets are the pieces it calls, each the whole-repository target narrowed
# to a list.

.PHONY: affected
affected: ## Print what a change selects and why: make affected BASE=origin/main
	@test -n "$(BASE)" || { echo "usage: make affected BASE=<ref>" >&2; exit 2; }
	@$(PYTHON) scripts/affected.py --base "$(BASE)" --explain
	@$(PYTHON) scripts/affected.py --base "$(BASE)" --targets

.PHONY: check-affected
check-affected: ## Every lint, and the gates of the modules a change touches: make check-affected BASE=origin/main
	@test -n "$(BASE)" || { echo "usage: make check-affected BASE=<ref>" >&2; exit 2; }
	@$(PYTHON) scripts/affected.py --base "$(BASE)" --run

.PHONY: lint-no-training-some
lint-no-training-some: ## Invariant 6's shape rules, and only the refits named: RETRAIN=N4,N7
	@$(PYTHON) scripts/check_no_training.py --retrain "$(RETRAIN)"

.PHONY: test-python-some
test-python-some: ## Only these Python test modules: PYTESTS="test_steering test_fuzzy"
	@test -n "$(PYTESTS)" || { echo "usage: make test-python-some PYTESTS=..." >&2; exit 2; }
	@cd python && $(PYTHON) -m unittest -q $(addprefix tests.,$(PYTESTS))

.PHONY: test-godot-some
test-godot-some: import ## Only these gdUnit4 suites or folders: SUITES="test/ai_search test/menu"
	@# Measured on gdUnit4 v6.2.2: a folder that does not exist, or holds no
	@# suite, prints "No test cases found, abort test run!" and exits 0. So
	@# both are refused here, or a typo in SUITES would be a green that ran
	@# nothing.
	@test -n "$(SUITES)" || { echo "usage: make test-godot-some SUITES=..." >&2; exit 2; }
	@for suite in $(SUITES); do test -e "godot/$$suite" || \
		{ echo "test-godot-some: there is no godot/$$suite" >&2; exit 2; }; done
	@out=$$($(GODOT) --headless --path godot \
		-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode $(addprefix -a ,$(SUITES)) 2>&1); \
	status=$$?; echo "$$out"; \
	if echo "$$out" | grep -q "No test cases found"; then \
		echo "test-godot-some: gdUnit4 found no test in $(SUITES)" >&2; exit 1; fi; \
	exit $$status

# --- looking at it ---------------------------------------------------------
#
# These open a window, so they are the two targets `make check` must never
# depend on: a gate that waits for somebody to close a window is a gate that
# hangs CI. Everything automated here runs --headless.

.PHONY: run
run: import ## Checkers against minimax: click a piece, click a green square; space plays white's move, 1-6 sets its depth
	@# T27: the first thing a person opens is a game nobody needs explained.
	@# T24 made the menu the project's main scene, so this names the board.
	@$(GODOT) --path godot res://game/checkers/checkers.tscn

.PHONY: menu
menu: import ## Every example on one menu: up and down choose, enter plays, Esc comes back (T24)
	@# The project's main scene, and what the exported executable opens on.
	@$(GODOT) --path godot

.PHONY: demo-skirmish
demo-skirmish: import ## The learned policy plays blue: click a unit, click a neighbouring cell, space ends the turn
	@# Until T27 this was `make run`. Where the policy finally plays is T30's
	@# question: blue on the tactical board, one controller among several.
	@$(GODOT) --path godot res://game/main.tscn

.PHONY: demo-tictactoe
demo-tictactoe: import ## MENACE, the matchbox machine, moves first: space draws its bead, click a square, 1-4 its age, M perfect play
	@$(GODOT) --path godot res://game/tictactoe/tictactoe.tscn

.PHONY: demo-search
demo-search: import ## The four searches on a board you can paint: drag to edit, 1-4 choose, space steps, B boards
	@$(GODOT) --path godot res://demos/search/search_demo.tscn

.PHONY: demo-stealth
demo-stealth: import ## Cross the hall unseen: arrows walk, shift sprints, space waits, D shows danger
	@$(GODOT) --path godot res://game/stealth/stealth.tscn

.PHONY: demo-steering
demo-steering: import ## Four vehicles: seek, arrive, pursue, seek with avoid, each force drawn; click moves a target, space pauses, . one step, R again
	@$(GODOT) --path godot res://demos/steering/steering_demo.tscn

.PHONY: demo-racing
demo-racing: import ## Race an AI in the same car: arrows/WASD drive, 1-3 the AI, R again, P pause, Tab watch the three AIs
	@$(GODOT) --path godot res://demos/racing/racing_demo.tscn

.PHONY: demo-racing3d
demo-racing3d: import ## A 3D race, you and three AI levels: arrows/WASD drive, 1 PID, 2 heat line, 3 measured grip, Tab watch, C camera, T track, R again, Space pause
	@$(GODOT) --path godot res://game3d/racing/racing3d.tscn

.PHONY: demo-botmatch
demo-botmatch: import ## A 3D bot match, six against six: 1-3 blue's claims/commander/retreat (Shift: red's), Tab a bot, T take it over, M map, C camera, P pause, N new, L the other arena
	@$(GODOT) --path godot res://game3d/botmatch/botmatch.tscn

.PHONY: demo-behaviour
demo-behaviour: import ## One guard, four ways to decide: 1-4 swap state machine, tree, GOAP, HTN mid-round; space a turn, enter ten
	@$(GODOT) --path godot res://demos/behaviour/behaviour_demo.tscn

.PHONY: demo-rts
demo-rts: import ## Real-time strategy against a commander that plans: drag selects, right click orders, B D L T E build, W 1 2 3 train, V watches, C level, H planner, I influence, F fog
	@$(GODOT) --path godot res://game/rts/rts.tscn

.PHONY: demo-tactical
demo-tactical: import ## Advance Wars style tactics against the computer: click to move, W waits, 1-5 build, Z undo, space ends the turn, C changes the computer (rules, planner, learned, easy, normal, hard, state machine, behaviour tree, GOAP, HTN), S swaps sides
	@$(GODOT) --path godot res://game/tactical/tactical.tscn

.PHONY: tactical-win-rates
tactical-win-rates: import ## Seeded games between the tactical board's controllers: wins, rounds, stuck pieces (~1 min)
	@# A measurement: the tuning tasks' acceptance passes it --at-most limits.
	@$(GODOT) --headless --path godot -s res://test/tactical/tactical_win_rates.gd -- $(or $(GAMES),20) $(LIMITS)

.PHONY: league
league: import ## T25's league: every team against every other from both seats, rated with intervals, each decision's cost (~10 min)
	@# T25's acceptance. Not in `check`: 280 games, played twice to hold the
	@# table to its seeds, take about ten minutes. SEEDS sets seeds a seat.
	@$(GODOT) --headless --path godot -s res://test/league/league_runner.gd -- $(or $(SEEDS),5)

.PHONY: record-tactical
record-tactical: import ## Play the tactical board and keep every game you finish in data/tactical/, T25's human reference
	@$(GODOT) --path godot res://game/tactical/tactical.tscn -- --record

.PHONY: demo-fighting
demo-fighting: import ## Training mode, you against a dummy: A/D walk, W jump, S crouch, U/I punch, J/K kick, L throw, O evade, hold away to guard, M dummy mode, P pause, space one frame
	@$(GODOT) --path godot res://game/fighting/fighting.tscn

.PHONY: record-replay
record-replay: import ## Record the recorded fight's per-frame digests again, after a deliberate change to the rules
	@$(GODOT) --headless --path godot -s res://test/fighting/replay_determinism.gd -- --record

.PHONY: test-replay
test-replay: import ## Replay the recorded fight twice; the two runs must agree on every frame
	@$(GODOT) --headless --path godot -s res://test/fighting/replay_determinism.gd

.PHONY: test-opponent-properties
test-opponent-properties: import ## The opponent model learns a habit within 40 actions, and follows a change of it
	@# T17's acceptance, with two planted models -- one that never forgets,
	@# one with no context -- that must fail the same claims.
	@$(GODOT) --headless --path godot -s res://test/fighting/opponent_properties.gd

.PHONY: test-difficulty-knobs
test-difficulty-knobs: import ## The tactical levels never cheat: only the documented knobs, the same board, dice and orders
	@# T12's allowlist, with three planted cheats it must catch. A few seconds.
	@$(GODOT) --headless --path godot -s res://test/tactical/difficulty_knobs.gd

.PHONY: test-difficulty-matches
test-difficulty-matches: import ## The tactical levels are a ladder, and each beats the rules from both seats (~15 min)
	@# T12's acceptance. Not in `check`: 575 games of up to 40 rounds take
	@# about fifteen minutes, so CI does not hold the ladder -- run it after any
	@# change to a level, `LeveledBlue`, `FightOdds` or the tactical rules.
	@$(GODOT) --headless --path godot -s res://test/tactical/difficulty_matches.gd

.PHONY: test-opponent-levels
test-opponent-levels: import ## The fixed opponent's levels are ordered: each beats the one below it 60 times in 100
	@# T37's acceptance. About 45 seconds: 600 fights of up to 99 seconds.
	@$(GODOT) --headless --path godot -s res://test/fighting/opponent_levels.gd

# --- behaviour cloning (T18) -------------------------------------------------
#
# Recordings (data/fights/) -> rows, cut by Godot (data/cloning/rows.json) ->
# the model and the ghost, fitted in Python (game/fighting/clone_weights.json)
# -> the win rates, fought by Godot (data/cloning/win_rates.json). Each step
# is a target; `train-clone` runs the last three in order.

CLONE_PLAYER ?= person

.PHONY: record-fights
record-fights: import ## Play the training mode and keep every fight you play in data/fights/, for T18 to learn from
	@$(GODOT) --path godot res://game/fighting/fighting.tscn -- --record

.PHONY: record-stand-ins
record-stand-ins: import ## Record the scripted stand-in players' fights again (deterministic)
	@$(GODOT) --headless --path godot -s res://test/fighting/record_stand_ins.gd -- $(CURDIR)/data/fights

.PHONY: clone-rows
clone-rows: import ## Replay every recording and cut the rows behaviour cloning learns from
	@$(GODOT) --headless --path godot -s res://test/fighting/export_clone_rows.gd \
		-- $(CURDIR)/data/fights $(CURDIR)/data/cloning/rows.json

.PHONY: train-clone
train-clone: clone-rows ## Cut the rows, fit the clone of CLONE_PLAYER, publish it and fight it for the win rates
	@# CLONE_PLAYER="stand-in: rushdown" (or turtle, jumper) fits a scripted stand-in instead.
	@PYTHONPATH=python $(PYTHON) -m gameaikit.cloning.publish --player "$(CLONE_PLAYER)" \
		--write $(CURDIR)/godot/game/fighting
	@$(MAKE) --no-print-directory test-clone-fights

.PHONY: test-clone-fights
test-clone-fights: import ## Fight the fixed opponent with the ghosts, the clone and the learner; write the win rates (~45 s)
	@$(GODOT) --headless --path godot -s res://test/fighting/clone_fights.gd -- $(CURDIR)/data/cloning/win_rates.json

.PHONY: test-clone-rows
test-clone-rows: import ## The committed rows are what the recordings cut into, today
	@$(GODOT) --headless --path godot -s res://test/fighting/export_clone_rows.gd \
		-- $(CURDIR)/data/fights $(CURDIR)/data/cloning/rows.json --check

.PHONY: test-inference-budget
test-inference-budget: import ## A cloned player's decision stays under its millisecond budget
	@$(GODOT) --headless --path godot -s res://test/fighting/inference_budget.gd

.PHONY: test-clone-report
test-clone-report: ## T18's comparison: held out, and measured on the published file
	@$(PYTHON) python/gameaikit/cloning/compare.py --report

# --- the fighters' pictures (T35, ADR 0015) ---------------------------------
#
# The template's sheets stay out of the repository; only the strips cut from
# them are committed. These two targets repeat the cut, for anyone who wants
# to check it or choose other cels.

FIGHTER_SHEETS := build/fighter-sheets

.PHONY: fighter-sheets
fighter-sheets: ## Download the fighters' CC0 template sheets into build/fighter-sheets/ (gitignored)
	@mkdir -p $(FIGHTER_SHEETS)
	@$(PYTHON) -c 'import json; t = json.load(open("godot/game/fighting/sprites.json")); print("\n".join(n + " " + s["url"] for n, s in t["sheets"].items()))' | \
		while read name url; do curl -sSfL -o "$(FIGHTER_SHEETS)/$$name" "$$url" || exit 1; echo "downloaded $$name"; done

.PHONY: fighter-strips
fighter-strips: ## Cut the fighters' strips from the downloaded sheets, after checking their sha256
	@$(GODOT) --headless --path godot -s $(CURDIR)/tools/fighters/crop.gd -- $(CURDIR)/$(FIGHTER_SHEETS)
	@$(MAKE) --no-print-directory import

# --- the RTS's pictures (T20, ADR 0020) ------------------------------------
#
# Referenced, never committed, not even crops: Bos Wars is GPL, and nothing of
# it is redistributed here. The game draws plain shapes without them.

.PHONY: assets-3d
assets-3d: ## Download the 3D packs into build/assets-3d/ and the files used into godot/game3d/downloaded/ (gitignored), sha256 checked
	@$(PYTHON) scripts/fetch_assets_3d.py

.PHONY: test-game3d-floor
test-game3d-floor: import ## Headless 3D physics, rays, a baked path, a replay, and the arena with its models missing (T50)
	@$(GODOT) --headless --path godot -s res://test/game3d/game3d_floor.gd

.PHONY: test-racing3d-car
test-racing3d-car: import ## The 3D car on a test pad: it rests on its springs, braking moves its weight forward, its tyres slide past their peak (T54)
	@# --fixed-fps 60: the physics step is the same 1/60 s either way, but
	@# without it Godot paces the frames in real time and this takes minutes.
	@$(GODOT) --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_car.gd

.PHONY: test-racing3d-ladder
test-racing3d-ladder: import ## The 3D racer's three levels finish, in order, a second a lap apart, on two tracks (T54)
	@$(GODOT) --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_ladder.gd

.PHONY: test-racing3d-does-not-cheat
test-racing3d-does-not-cheat: import ## One physics for every 3D car, no limit broken, no knob moved, and an honest twin race matched bit for bit (T54)
	@$(GODOT) --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_does_not_cheat.gd

.PHONY: test-racing3d-you-drive
test-racing3d-you-drive: import ## The racer's scene starts on your car, says the keys wait for the grid, and a held Up drives it (wave 75)
	@$(GODOT) --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_you_drive.gd

.PHONY: test-racing3d-effects
test-racing3d-effects: import ## Slow (~75 s): what the PID, the measured grip and the heat line each do to a 3D race, measured (T54)
	@$(GODOT) --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_effects.gd

.PHONY: measure-3d
measure-3d: import ## Windowed: the 3D test arena's frame rate, with models and without (T50); not a gate
	@$(GODOT) --path godot -s res://test/game3d/arena_fps.gd
	@$(GODOT) --path godot -s res://test/game3d/arena_fps.gd -- --primitives

.PHONY: rts-art
rts-art: ## Download the RTS's Bos Wars sheets into build/rts-art/ (gitignored), refusing any whose sha256 differs
	@$(PYTHON) scripts/fetch_rts_art.py

# --- your own art (T31: optional, tier 3, needs a GPU) ----------------------
#
# Fenced off from everything above: `make check` never reaches it, and nothing
# in python/ or godot/ names it. Without a GPU, keep the CC0 art -- the game
# loses nothing. See docs/howto/generate-art.md.

.PHONY: artgen-bootstrap
artgen-bootstrap: ## Create the art generator's environment and fetch its default model (about 40 GB, large disk)
	@scripts/artgen bootstrap
	@$(MAKE) --no-print-directory lint-disk-layout

.PHONY: artgen
artgen: ## Generate your own art into godot/assets/generated/ (gitignored): STYLE=toy, MODEL=klein, ONLY="units/red/ram.png ..."
	@scripts/artgen make $(if $(MODEL),--model $(MODEL)) $(if $(STYLE),--style $(STYLE)) $(if $(ONLY),--only $(ONLY))
	@$(MAKE) --no-print-directory import
	@$(MAKE) --no-print-directory lint-disk-layout

.PHONY: artgen-clean
artgen-clean: ## Delete your generated art; the game is back on the CC0 set
	@rm -rf godot/assets/generated
	@$(MAKE) --no-print-directory import

# --- shipping --------------------------------------------------------------

.PHONY: export
export: import ## The menu as a Linux x86_64 executable in dist/game-ai-kit-linux/, started headless before it counts (T24)
	@# Needs the export templates `make bootstrap` installs and pins. The
	@# script refuses a template that does not match, a pack holding the tests
	@# or a person's generated art, and a binary that does not start.
	@$(PYTHON) scripts/export.py

.PHONY: release
release: export ## One zip per addon, the Python wheel and the executable into dist/, attribution checked
	@# The build does not get to say it attributed anything: the same gate
	@# that reads the repository opens every archive it wrote and looks.
	@# `release.py --skip-notice` builds a release that must fail it. The
	@# executable ships only when `export` stamped it from a clean HEAD (T24).
	@$(PYTHON) scripts/release.py --build --executable dist/game-ai-kit-linux
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
