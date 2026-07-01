.PHONY: help migrate backup restore

help:
	@echo "AI Workspace Site Migration & Backup Toolkit"
	@echo "Usage:"
	@echo "  make migrate   - Execute full site migration (Source -> Target)"
	@echo "  make backup    - Execute cold backup on the target host"
	@echo "  make restore   - Execute offline restore on the target host"

migrate:
	@bash scripts/run_toolkit.sh migrate $(RUN_ARGS)

backup:
	@bash scripts/run_toolkit.sh backup $(RUN_ARGS)

restore:
	@bash scripts/run_toolkit.sh restore $(RUN_ARGS)
