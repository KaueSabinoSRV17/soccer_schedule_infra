SHELL := /usr/bin/bash

TERRAGRUNT ?= terragrunt
LIVE_DIR := live
MODULE ?=
ARGS ?=

UNITS := $(sort $(notdir $(patsubst %/,%,$(dir $(wildcard $(LIVE_DIR)/*/terragrunt.hcl)))))

.DEFAULT_GOAL := help

.PHONY: help units init plan apply destroy state-list validate fmt set-secret check-project

help: ## Show available commands and usage
	@printf '%s\n' \
		'Usage: make <target> [MODULE=<unit>] [ARGS="<tofu arguments>"]' \
		'' \
		'Without MODULE, the target runs across every live unit.' \
		'Example: make plan MODULE=core' \
		'Example: make init ARGS=-upgrade' \
		'' \
		'Available units: $(UNITS)' \
		'' \
		'Targets:'
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

units: ## List live units
	@printf '%s\n' $(UNITS)

check-project:
	@if [[ -z "$${GCP_PROJECT_ID:-}" ]]; then \
		echo 'GCP_PROJECT_ID is required.' >&2; \
		echo "Run: export GCP_PROJECT_ID='your-project-id'" >&2; \
		exit 1; \
	fi
	@if [[ -n "$(strip $(MODULE))" && ! -f "$(LIVE_DIR)/$(strip $(MODULE))/terragrunt.hcl" ]]; then \
		echo "Unknown module: $(strip $(MODULE))" >&2; \
		echo "Available units: $(UNITS)" >&2; \
		exit 1; \
	fi

init: check-project ## Initialize one unit or all units
	$(call run_tg,init,)

plan: check-project ## Plan one unit or all units
	$(call run_tg,plan,)

apply: check-project ## Apply one unit or all units with auto-approval
	$(call run_tg,apply -auto-approve,)

destroy: check-project ## Destroy one unit or all units interactively
	$(call run_tg,destroy,--no-auto-approve)

state-list: check-project ## List state for one unit or all units
	$(call run_tg,state list,)

validate: check-project ## Validate one unit or all units
	$(call run_tg,validate,)

fmt: ## Format Terraform and Terragrunt files
	terraform fmt -recursive
	$(TERRAGRUNT) hcl fmt

set-secret: check-project ## Add a secret version from stdin; requires SECRET=<id>
	@if [[ -z "$(strip $(SECRET))" ]]; then \
		echo 'SECRET is required.' >&2; \
		echo 'Example: printf %s "$$VALUE" | make set-secret SECRET=youtube-api-key' >&2; \
		exit 1; \
	fi
	@./scripts/set-secret.sh "$(strip $(SECRET))"

define run_tg
	@if [[ -n "$(strip $(MODULE))" ]]; then \
		$(TERRAGRUNT) --working-dir "$(LIVE_DIR)/$(strip $(MODULE))" run -- $(1) $(ARGS); \
	else \
		$(TERRAGRUNT) --working-dir "$(LIVE_DIR)" run --all $(2) -- $(1) $(ARGS); \
	fi
endef
