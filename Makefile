.PHONY: help migrate backup restore

DOMAIN ?= ai-workspace

help:
	@echo "AI Workspace Site Migration & Backup Toolkit (Domain-Driven Playbooks)"
	@echo "Usage:"
	@echo "  make migrate DOMAIN=domain1,domain2 - Execute full site migration (Source -> Target)"
	@echo "  make backup  DOMAIN=domain1,domain2 - Execute cold backup on the target host"
	@echo "  make restore DOMAIN=domain1,domain2 - Execute offline restore on the target host"
	@echo ""
	@echo "  Supported Domains: ai-workspace, web-saas, infra-platform"

migrate:
	@python3 scripts/run_toolkit.py migrate --domain $(DOMAIN) $(RUN_ARGS)

backup:
	@python3 scripts/run_toolkit.py backup --domain $(DOMAIN) $(RUN_ARGS)

restore:
	@python3 scripts/run_toolkit.py restore --domain $(DOMAIN) $(RUN_ARGS)
