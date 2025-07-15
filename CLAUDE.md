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
   - `cyclomatic_complexity.ml/mli`: Analyzes complexity, function length, and nesting depth
   - `naming_rules.ml/mli`: Checks naming conventions for modules, values, variants, types
   - `style_rules.ml/mli`: Detects style issues like Obj.magic, catch-all handlers, Str usage
   - `doc_rules.ml/mli`: Validates documentation requirements for modules and values
   - `format_rules.ml/mli`: Checks for .ocamlformat files and missing .mli files
   - `merlin_interface.ml/mli`: Interface layer that invokes Merlin to get AST for OCaml files
   - `issue.ml/mli`: Defines issue types and priority-based sorting
   - `report.ml/mli`: Handles output formatting for visual and quiet modes

2. **`bin/` - CLI Application**
   - `main.ml`: Command-line interface using Cmdliner, handles file arguments and configuration

3. **Key Data Flow**:
   ```
   OCaml files → Merlin (via ocamlmerlin) → JSON AST →
   Various rule modules → Issues → Priority sorting → Report → Exit code
   ```

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