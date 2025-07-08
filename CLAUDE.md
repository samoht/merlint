# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cyclomatic is an OCaml cyclomatic complexity analyzer that integrates with Merlin to analyze OCaml source code. It identifies functions with high cyclomatic complexity and excessive length.

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
# Analyze files with default thresholds (complexity: 10, length: 50)
dune exec cyclomatic -- lib/*.ml

# With custom thresholds
dune exec cyclomatic -- --max-complexity 15 --max-length 100 src/*.ml

# After installation
cyclomatic file1.ml file2.ml
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
   - `cyclomatic_complexity.ml/mli`: Core analysis logic that processes Merlin's AST JSON and calculates complexity
   - `merlin_interface.ml/mli`: Interface layer that invokes Merlin to get AST for OCaml files

2. **`bin/` - CLI Application**
   - `main.ml`: Command-line interface using Cmdliner, handles file arguments and configuration

3. **Key Data Flow**:
   ```
   OCaml files → Merlin (via ocamlmerlin) → JSON AST → 
   Cyclomatic_complexity.analyze_structure → Violations → Exit code
   ```

## Testing Approach

- Uses Dune's cram test framework in `test/cyclomatic.t`
- Test samples in `test/samples/` demonstrate various complexity scenarios
- Tests verify both detection accuracy and proper exit codes

## Important Notes

- Never run `dune`, `ocamlmerlin`, or `prune` commands in `*.t` (cram) directories
- The tool exits with code 1 when violations are found (useful for CI/CD)
- Git hooks enforce formatting and passing tests (use `test!:` or `wip:` prefixes to bypass)