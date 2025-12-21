SHELL := /usr/bin/bash
.SHELLFLAGS := -euo pipefail -c

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Available targets:"
	@echo
	@echo "  sanity            Check system assumptions (read-only)"
	@echo "  generate-secrets  Generate .env files from templates (in repo folder)"
	@echo "  deploy-secrets    Deploy .env files to /etc/n8n-n150 (requires root)"
	@echo

.PHONY: sanity
sanity:
	@bash ./scripts/sanity.sh

.PHONY: generate-secrets
generate-secrets:
	@bash ./scripts/generate-secrets.sh

.PHONY: deploy-secrets
deploy-secrets:
	@bash ./scripts/deploy-secrets.sh
