SCHEMAT ?= schemat
# Schemat 0.5.3 cannot parse Steel's "\0" escape.
# The icon catalog is generated; tools/icons/generate.py owns its layout.
SCHEMAT_FLAGS = --ignore src/adapters/git/porcelain.scm \
                --ignore src/domain/path.scm \
                --ignore src/domain/icons/catalog.scm

.PHONY: format lint test icons

format:
	$(SCHEMAT) $(SCHEMAT_FLAGS) '**/*.scm'
	uv run --locked ruff check --fix tests
	uv run --locked ruff format tests

lint:
	$(SCHEMAT) --check $(SCHEMAT_FLAGS) '**/*.scm'
	uv run --locked ruff format --check tests
	uv run --locked ruff check tests

test:
	uv run --locked pytest --import-mode=importlib -n auto tests

# Refresh the pinned eza icon catalog.
icons:
	uv run tools/icons/generate.py
