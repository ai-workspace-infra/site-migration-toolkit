.PHONY: help migrate backup restore

help:
	@echo "AI Workspace Site Migration & Backup Toolkit"
	@echo "Usage:"
	@echo "  make migrate   - Execute full site migration (Source -> Target)"
	@echo "  make backup    - Execute cold backup on the target host"
	@echo "  make restore   - Execute offline restore on the target host"

migrate:
	@python3 scripts/run_toolkit.py migrate $(RUN_ARGS)

backup:
	@python3 scripts/run_toolkit.py backup $(RUN_ARGS)

restore:
	@python3 scripts/run_toolkit.py restore $(RUN_ARGS)
