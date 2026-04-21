.PHONY: setup test lint automate

setup:
	./scripts/dev-setup.sh --node

test:
	pytest -q TSH

lint:
	flake8 TSH

automate:
	python3 TSH/automate_workflow.py --once
