INSTALL_DIR ?= $(HOME)/.local/bin

.PHONY: compile test install

compile:
	@true

test:
	@true

install:
	@mkdir -p $(INSTALL_DIR)
	@for f in hydrate-envrc infisical-populate-secrets infisical-bootstrap infisical-fetch-secrets infisical-rebuild export-infisical-secrets; do \
		install -m 755 "bin/$$f" "$(INSTALL_DIR)/$$f"; \
		echo "✓ Installed $$f"; \
	done
