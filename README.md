# Merlint

An opinionated OCaml linter that enforces modern OCaml coding conventions and best practices.

## Features

Merlint analyzes your OCaml code and reports issues across multiple categories, with intelligent **priority-based sorting** to help you focus on the most important problems first.

### Code Quality (High Priority)
- **Cyclomatic complexity**: Functions should have complexity ≤ 10
- **Function length**: Functions should be ≤ 50 lines  
- **Nesting depth**: Code should not nest deeper than 3 levels

### Code Style (High Priority)
- **No Obj.magic**: Never use `Obj.magic` (highest priority)
- **No catch-all**: Avoid `try ... with _ -> ...` patterns
- **Use Re not Str**: Use `Re` module instead of `Str` for regular expressions

### Naming Conventions (Medium Priority)
- **Modules**: Must use snake_case (e.g., `user_profile`)
- **Variants**: Must use Snake_case (e.g., `Waiting_for_input`)
- **Values/Functions**: Must use snake_case
- **Types**: Must use snake_case (primary type should be `t`)
- **Long identifiers**: Avoid names with too many underscores (>3)

### Documentation (Lower Priority)
- **MLI files**: Must have module-level documentation comments
- **Module interface files**: Every `.ml` file should have a corresponding `.mli`
- **Value documentation**: Public values should be documented

### Project Structure
- **OCamlformat**: Projects should include `.ocamlformat` file
- **Interface files**: Missing `.mli` files for modules

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
```

### Output Modes

**Visual Mode (default)**: Shows categorized results with priority-based sorting
```
Running merlint analysis...

Analyzing 15 files

✓ Code Quality (0 total issues)
✗ Code Style (2 total issues)
  ✗ Style rules (no Obj.magic, no Str, no catch-all) (2 issues)
    src/utils.ml:33:8: Never use Obj.magic
    src/parser.ml:45:2: Use Re module instead of Str
✗ Naming Conventions (3 total issues)
  ✗ Naming conventions (snake_case) (3 issues)
    src/types.ml:8:2: Variant 'waitingForInput' should be 'Waiting_for_input'
    src/api.ml:12:4: 'very_long_function_name_with_many_underscores' has too many underscores (6)
    src/types.ml:12:4: Module 'myModule' should be 'my_module'

Summary: ✗ 5 total issues
```

**Quiet Mode**: Simple line-by-line output sorted by priority
```bash
merlint --quiet
```
```
src/utils.ml:33:8: Never use Obj.magic
src/parser.ml:45:2: Use Re module instead of Str
src/types.ml:8:2: Variant 'waitingForInput' should be 'Waiting_for_input'
src/api.ml:12:4: 'very_long_function_name_with_many_underscores' has too many underscores (6)
src/types.ml:12:4: Module 'myModule' should be 'my_module'
```

## Priority System

Issues are automatically sorted by priority to help you focus on the most important problems:

1. **Critical** (Priority 1-2): `Obj.magic` usage, catch-all exception handlers
2. **High** (Priority 3-5): Complexity, nesting, function length
3. **Medium** (Priority 6-12): Style issues, naming conventions, missing interfaces
4. **Low** (Priority 13-17): Documentation, project structure

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

## Configuration

Merlint uses sensible defaults but can be configured:

- **Complexity threshold**: 10 (functions with higher complexity are flagged)
- **Function length threshold**: 50 lines
- **Nesting depth threshold**: 3 levels
- **Identifier underscore threshold**: 3 underscores

## Philosophy

Merlint enforces best practices for OCaml development, focusing on:
- **Safety first**: Critical issues like `Obj.magic` get highest priority
- **Code clarity**: Consistent naming and reasonable complexity
- **Maintainability**: Proper documentation and interface files
- **Modern OCaml**: Encourages contemporary OCaml practices

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

**This project was developed with significant AI assistance** ([Claude Code](https://www.anthropic.com/claude-code) by Anthropic). While the tool has been tested extensively and works well in practice, users should be aware that:

1. **Technical implications**: AI-generated code may have unique patterns or subtle bugs. We've used `merlint` on itself and other projects successfully, but thorough testing is always recommended.

2. **Legal uncertainty**: The copyright status, license implications, and liability for AI-generated code remain legally untested. We cannot trace which training data influenced specific code patterns.

3. **Our Commitment**: Despite these unknowns, we believe `merlint` provides real value to the OCaml community. We are committed to maintaining it, using it ourselves, and being transparent about its AI origins.

For deeper context on these issues, see the [Software Freedom Conservancy](https://sfconservancy.org/blog/2022/feb/03/github-copilot-copyleft-gpl/) and [FSF positions](https://www.fsf.org/blogs/licensing/fsf-funded-call-for-white-papers-on-questions-around-copilot/) on AI-generated code.

**By using this tool, you acknowledge these uncertainties.** As with any code modification tool: use version control, review all changes, and test thoroughly.

## License

MIT — see LICENSE.md for details.

## Acknowledgements

Many thanks to the [Merlin](https://github.com/ocaml/merlin) maintainers for an indispensable API that makes OCaml tooling possible.