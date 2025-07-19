# Merlint

An opinionated OCaml linter that enforces modern OCaml coding conventions and best practices.

## Features

Merlint analyzes your OCaml code and reports issues across multiple categories, with intelligent **priority-based sorting** to help you focus on the most important problems first.

### Code Quality (High Priority)
- **Cyclomatic complexity**: Functions should have complexity ≤ 10
- **Function length**: Functions should be ≤ 50 lines (with automatic adjustments for pattern matching and data structures)
- **Nesting depth**: Code should not nest deeper than 3 levels

### Code Style (High Priority)
- **No Obj.magic**: Never use `Obj.magic` (highest priority)
- **No catch-all**: Avoid `try ... with _ -> ...` patterns
- **Use Re not Str**: Use `Re` module instead of `Str` for regular expressions
- **Use Fmt not Printf**: Use `Fmt` module instead of `Printf` for formatting
- **No silenced warnings**: Avoid `[@warning "-..."]` attributes

### Naming Conventions (Medium Priority)
- **Modules**: Must use Snake_case (e.g., `User_profile`)
- **Variants**: Must use Snake_case (e.g., `Waiting_for_input`)
- **Values/Functions**: Must use snake_case
- **Types**: Must use snake_case (primary type should be `t`)
- **Long identifiers**: Avoid names with too many underscores (>3)
- **Function naming**: Use `get_*` for direct access, `find_*` for optional returns
- **Redundant names**: Avoid repeating module name in functions/types

### Documentation (Lower Priority)
- **MLI files**: Must have module-level documentation comments
- **Module interface files**: Every `.ml` file should have a corresponding `.mli`
- **Value documentation**: Public values should be documented
- **Standard functions**: Types should implement standard functions (pp, equal, compare)

### Project Structure
- **OCamlformat**: Projects should include `.ocamlformat` file
- **Interface files**: Missing `.mli` files for modules

### Test Quality
- **Test conventions**: Test files should export `suite` value for test runners
- **Test coverage**: Library modules should have corresponding test files
- **Test organization**: Tests should be included in the test runner

## Installation

```bash
opam install . --deps-only
dune build
dune install
```

## Usage

### Basic Usage
```bash
# Analyze entire project (visual mode)
merlint

# Analyze specific files or directories
merlint src/ lib/
merlint src/parser.ml

# Quiet mode (one issue per line)
merlint --quiet

# Exclude directories or files
merlint --exclude test/ --exclude _build/
merlint --exclude "test/**" --exclude "*.temp.ml"

# Filter rules (disable specific checks)
merlint --rules A-E110          # All rules except E110 (silenced warnings)
merlint --rules A-E205-E320     # All except Printf and long identifiers
merlint -r A-E005              # All except long functions
```

### Output Modes

**Visual Mode (default)**: Shows categorized results with priority-based sorting
```
Running merlint analysis...

Analyzing 15 files

✓ Code Quality (0 total issues)
✗ Code Style (2 total issues)
  [E100] Unsafe Type Casting
  This issue means you're using unsafe type casting that can crash your program.
  Fix it by replacing Obj.magic with proper type definitions.
  - src/utils.ml:33:8: Never use Obj.magic
  [E200] Deprecated Str Module
  This issue means you're using the outdated Str module. Fix it by using the
  modern Re module which is more powerful and has better performance.
  - src/parser.ml:45:2: Use Re module instead of Str
✗ Naming Conventions (3 total issues)
  [E300] Variant Naming Convention
  This issue means your variant names don't follow OCaml conventions. Fix them
  by using Snake_case (e.g., Some_value, Waiting_for_input).
  - src/types.ml:8:2: Variant 'waitingForInput' should be 'Waiting_for_input'
  [E320] Long Identifier Names
  This issue means your identifier has too many underscores making it hard to
  read. Fix it by removing redundant prefixes and suffixes.
  - src/api.ml:12:4: 'very_long_function_name_with_many_underscores' has too many underscores (6)
  [E305] Module Naming Convention
  This issue means your module names don't follow OCaml conventions. Fix them
  by renaming to snake_case (e.g., myModule → my_module).
  - src/types.ml:12:4: Module 'myModule' should be 'my_module'

Summary: ✗ 5 total issues
```

**Quiet Mode**: Simple line-by-line output sorted by priority
```bash
merlint --quiet
```
```
[E100] src/utils.ml:33:8: Never use Obj.magic
[E200] src/parser.ml:45:2: Use Re module instead of Str
[E300] src/types.ml:8:2: Variant 'waitingForInput' should be 'Waiting_for_input'
[E320] src/api.ml:12:4: 'very_long_function_name_with_many_underscores' has too many underscores (6)
[E305] src/types.ml:12:4: Module 'myModule' should be 'my_module'
```

## Priority System

Issues are automatically sorted by priority to help you focus on the most important problems:

1. **Critical** (Priority 1-2): `Obj.magic` usage, catch-all exception handlers
2. **High** (Priority 3-5): Complexity, nesting, function length
3. **Medium** (Priority 6-12): Style issues, naming conventions, missing interfaces
4. **Low** (Priority 13-17): Documentation, project structure

## Error Codes

For a complete reference of all error codes with detailed explanations and examples, visit:
**https://samoht.github.io/merlint/**

Error codes can be used with the `--rules` flag to filter specific checks.

## Integration

### Git Pre-commit Hook
Merlint can be integrated into your git workflow:

```bash
# Add to .git/hooks/pre-commit
#!/bin/bash
echo "Running merlint analysis..."
if command -v merlint >/dev/null 2>&1; then
    merlint --exclude test/
    if [ $? -ne 0 ]; then
        echo "❌ Merlint found issues. Please fix them before committing."
        exit 1
    fi
else
    echo "⚠️  Warning: merlint not found. Skipping analysis."
fi
```

### CI/CD
Use merlint in your continuous integration:
```yaml
- name: Lint OCaml code
  run: merlint --quiet
```

## Style Guide

For detailed guidelines on OCaml coding conventions and best practices enforced by Merlint, see:
**[docs/STYLE_GUIDE.md](docs/STYLE_GUIDE.md)**

## Development

```bash
# Run tests
dune runtest

# Run tests excluding samples
dune exec -- merlint test --exclude test/samples

# Format code
dune fmt

# Test on the codebase itself
merlint lib/ bin/
```

## Requirements

- OCaml ≥ 4.14 with dune
- Merlin (`ocamlmerlin` in your `$PATH`)

## AI Transparency

**This project was developed with significant AI assistance** ([Claude
  Code](https://www.anthropic.com/claude-code) by Anthropic). While
  the tool has been tested extensively and works well in practice,
  users should be aware that:

1. **Technical implications**: AI-generated code may have unique
   patterns or subtle bugs. We've used `merlint` on itself and other
   projects successfully, but thorough testing is always recommended.

2. **Legal uncertainty**: The copyright status, license implications,
   and liability for AI-generated code remain legally untested. We cannot
   trace which training data influenced specific code patterns.

3. **Our Commitment**: Despite these unknowns, we believe `merlint`
   provides real value to the OCaml community. We are committed to
   maintaining it, using it ourselves, and being transparent about its AI
   origins.

For deeper context on these issues, see the [Software Freedom
Conservancy](https://sfconservancy.org/blog/2022/feb/03/github-copilot-copyleft-gpl/)
and [FSF
positions](https://www.fsf.org/blogs/licensing/fsf-funded-call-for-white-papers-on-questions-around-copilot/)
on AI-generated code.

**By using this tool, you acknowledge these uncertainties.** As with
  any code modification tool: use version control, review all changes,
  and test thoroughly.

## License

MIT — see LICENSE.md for details.

## Acknowledgements

Many thanks to the [Merlin](https://github.com/ocaml/merlin)
maintainers for an indispensable API that makes OCaml tooling
possible.
