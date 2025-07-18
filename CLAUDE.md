# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Merlint is an opinionated OCaml linter that integrates with Merlin to analyze OCaml source code. It checks for code quality issues including cyclomatic complexity, naming conventions, style issues, and documentation problems.

## Development Commands

### Build and Test
```bash
# Build the project
dune build

# Run tests
dune test

# Format code (required before commits)
dune fmt

# Build and install locally
dune install

# Clean build artifacts
dune clean
```

### Running the Tool
```bash
# Analyze files with visual output (default)
dune exec merlint -- lib/

# Quiet mode for CI/CD
dune exec merlint -- --quiet src/

# Exclude directories
dune exec merlint -- --exclude test/ --exclude _build/

# After installation
merlint lib/ src/
```

### Running Individual Cram Tests
```bash
# Run a specific cram test (omit the .t extension!)
dune build @test/cram/e200
dune build @test/cram/e001
```

### Development Setup
```bash
# Install dependencies
opam install . --deps-only

# Set up git hooks (runs tests/formatting on commit)
./scripts/setup-hooks.sh
```

## Architecture

The codebase follows a clean separation between library and executable:

1. **`lib/` - Core Library**

2. **`lib/rules` - Rules**

3. **`bin/` - CLI Application**
   - `main.ml`: Command-line interface using Cmdliner, handles file arguments and configuration

## Testing Approach

- Uses Dune's cram test framework in `test/cram/`
- Each rule has its own test directory (e.g., `e001.t/`) with good.ml and bad.ml examples
- Test examples are the source of truth - `lib/examples.ml` is auto-generated from test files
- Tests verify both detection accuracy and proper exit codes
- Test integrity is automatically checked during `dune test`

## Documentation

- **Style Guide**: `docs/STYLE_GUIDE.md` - Generated style guide based on the rules implemented in Merlint
- **Error Codes Reference**: docs/index.html - Comprehensive list of all error codes with examples
- Documentation is auto-generated from the rule definitions using `dune build docs/`

## Important Notes

- Never run `dune`, `ocamlmerlin`, or `prune` commands in `*.t` (cram) directories
- The tool exits with code 1 when issues are found (useful for CI/CD)
- Git hooks enforce formatting and passing tests (use `test!:` or `wip:` prefixes to bypass)

## Debugging Tips

To debug cram test failures with verbose output:
```bash
MERLINT_VERBOSE=debug dune build @test/cram/e100
```

This will show detailed AST parsing and processing information in the test output.