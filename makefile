SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

# Only help should print descriptive text.
help:
	@printf "%s\n" \
		"Usage:" \
		"  make <component>-<verb>" \
		"" \
		"Components:" \
		"  net, app, monitoring, proxy, backup" \
		"" \
		"Verbs:" \
		"  install, secrets, secrets-deploy, start, stop, restart, status, check, run" \
		"" \
		"Examples:" \
		"  make net-install" \
		"  make app-start" \
		"  make monitoring-status" \
		"  make backup-run"

.PHONY: help

# Generic noun-verb dispatcher.
# Matches targets like "app-start", "proxy-install", "backup-run".
%-%:
	@./scripts/bin/ctl $(firstword $(subst -, ,$@)) $(word 2,$(subst -, ,$@))
