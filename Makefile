PREFIX ?= /usr/local
VERSION := $(shell grep '^VERSION=' bin/bx | cut -d'"' -f2)

.PHONY: install uninstall test lint clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install bx to PREFIX (default: /usr/local)
	@mkdir -p $(PREFIX)/bin $(PREFIX)/lib/bx $(PREFIX)/share/bx/completions
	@install -m 755 bin/bx $(PREFIX)/bin/bx
	@install -m 644 lib/*.sh $(PREFIX)/lib/bx/
	@install -m 644 completions/* $(PREFIX)/share/bx/completions/
	@echo "Installed bx v$(VERSION) to $(PREFIX)/bin/bx"

uninstall: ## Remove bx from PREFIX
	@rm -f $(PREFIX)/bin/bx
	@rm -rf $(PREFIX)/lib/bx
	@rm -rf $(PREFIX)/share/bx
	@echo "Uninstalled bx from $(PREFIX)"

test: ## Run all tests
	@bash test/test_runner.sh

lint: ## Run shellcheck on all scripts
	@shellcheck bin/bx lib/*.sh completions/bx.bash
	@echo "Lint passed"

clean: ## Remove test artifacts
	@rm -rf test/tmp/

release-check: ## Verify release readiness
	@echo "Version: $(VERSION)"
	@grep -q "## \[$(VERSION)\]" CHANGELOG.md || (echo "ERROR: CHANGELOG.md missing entry for $(VERSION)" && exit 1)
	@echo "Release check passed"
