# Development Scripts

This directory contains scripts to help with development setup and workflows.

## setup-hooks.sh

Sets up git hooks for the project. Run this after cloning the repository:

```bash
./scripts/setup-hooks.sh
```

This installs hooks that:
1. **pre-commit**: Runs `dune fmt`, `dune build`, and `dune test`
2. **prepare-commit-msg**: Detects special commit prefixes to allow failing tests

### Committing Failing Tests

If you need to commit code with intentionally failing tests (e.g., when adding a test for a bug that hasn't been fixed yet), use one of these commit prefixes:

- `test!:` - For test changes that are expected to fail
- `wip:` - For work-in-progress commits

Examples:
```bash
git commit -m "test!: add failing test for complex history"
git commit -m "wip: partial implementation of topological sort"
```

The hooks will detect these prefixes and allow the commit even if tests fail.