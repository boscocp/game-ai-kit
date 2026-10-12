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

# --- the gate --------------------------------------------------------------

.PHONY: check
check: lint-disk-layout lint-renderer lint-license lint-selftests test-python ## Run every gate

.PHONY: lint-disk-layout
lint-disk-layout: ## Nothing of the toolchain may land on the small disk
	@$(PYTHON) scripts/check_disk_layout.py

.PHONY: lint-renderer
lint-renderer: ## Renderer stays Compatibility; no 3D nodes in game/ or demos/
	@$(PYTHON) scripts/check_renderer.py

.PHONY: lint-license
lint-license: ## LICENSE and NOTICE present, and in every release artifact
	@$(PYTHON) scripts/check_license.py

.PHONY: lint-selftests
lint-selftests: ## Run every gate's own --self-test
	@# Discovered by glob, never by a list: a gate left out of a list is a gate
	@# that silently stops running. Keep going after the first failure so one
	@# broken script does not hide the others.
	@failed=0; \
	for script in $$(grep -l -- '--self-test' scripts/*.py scripts/*.sh 2>/dev/null); do \
		printf '%-40s ' "$$script"; \
		if $(PYTHON) "$$script" --self-test >/dev/null 2>&1 || bash "$$script" --self-test >/dev/null 2>&1; then \
			echo ok; \
		else \
			echo FAIL; failed=1; \
		fi; \
	done; \
	exit $$failed

.PHONY: test-python
test-python: ## Python unit tests (stdlib only, no install step)
	@$(PYTHON) -m unittest discover -s python/tests -t python -q

.PHONY: test-godot
test-godot: ## Godot tests, headless
	@$(GODOT) --headless --path godot --quit

# --- housekeeping ----------------------------------------------------------

.PHONY: godot-version
godot-version: ## Print the Godot the repo is pinned to, and what is installed
	@echo "pinned:    $(GODOT_VERSION)"
	@echo -n "installed: "; $(GODOT) --headless --version

.PHONY: hooks
hooks: ## Opt in to the repo's git hooks
	@git config core.hooksPath .githooks
	@echo "hooks enabled: .githooks"
