# Merlint

An opinionated linter for modern OCaml development.

Merlint is a static analysis tool that helps you write clean,
consistent, and robust OCaml code. It enforces modern best practices
and identifies common issues across several categories, from code
complexity and style to naming conventions and testing.

For a complete reference of all rules, visit the official documentation:
**[https://samoht.github.io/merlint/](https://samoht.github.io/merlint/)**

## Features

- **Comprehensive Analysis**: Checks for issues in code quality,
    style, naming, documentation, project structure, and testing.
- **Intelligent Prioritization**: Automatically sorts issues by
    severity, so you can focus on the most critical problems first.
- **Modern & Opinionated**: Enforces current best practices, such as
    using `Fmt` over `Printf` and `Re` over `Str`.
- **Zero Configuration**: Works out of the box with sensible defaults,
    requiring no setup to get started.

## Output Example

Merlint provides clear, color-coded output that groups issues by
category and explains how to fix them.

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

## Quick Start

### Installation
```bash
opam install . --deps-only
dune build
dune install
```

### Usage
```bash
# Analyze the entire project
merlint

# Analyze specific files or directories
merlint src/ lib/

# Exclude directories
merlint --exclude test/

# Filter rules (e.g., run all rules except E110)
merlint --rules A-E110
```

## Configuration

Merlint can be configured using a `.merlint` file in your project root. See [MERLINT_CONFIG.md](docs/MERLINT_CONFIG.md) for details.

Example `.merlint`:
```yaml
settings:
  max-complexity: 15
  max-function-length: 100

rules:
  - files: lib/prose*.ml
    exclude: [E330]
  - files: test/**/*.ml
    exclude: [E400, E410]
```

## Rules Overview

Merlint groups rules by category and priority:

1.  **Critical (Priority 1-2)**: `Obj.magic` usage, catch-all
exception handlers.
2.  **High (Priority 3-5)**: High cyclomatic complexity, long
functions, and deep nesting.
3.  **Medium (Priority 6-12)**: Modernization (e.g., `Re` vs. `Str`),
naming conventions, and missing interface files.
4.  **Low (Priority 13-17)**: Documentation standards and project
structure.

For a complete list of rules and error codes, see the **[official
documentation](https://samoht.github.io/merlint/)**.

## Integration

### Git Pre-commit Hook
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
```yaml
- name: Lint OCaml code
  run: |
    merlint --exclude test/
    # Exit code 1 if issues found, 0 if clean
```

## Style Guide

For detailed guidelines on the OCaml coding conventions enforced by
Merlint, see the official **[Style Guide](docs/STYLE_GUIDE.md)**.

## Development

```bash
# Run tests
dune runtest

# Format code
dune fmt

# Test on the codebase itself
merlint lib/ bin/
```

### Architecture

Merlint uses a multi-strategy approach to analyze OCaml code:

1.  **Merlin outline** for function boundaries and line counts.
2.  **`ppxlib` on `parsetree`** for cyclomatic complexity, control flow, and name extraction.
3.  **Pattern matching and regex on source text** for detecting specific code patterns.

This hybrid approach ensures accurate analysis while maintaining simplicity and performance.

## Requirements

- OCaml ≥ 4.14 with dune
- Merlin (`ocamlmerlin` in your `$PATH`)

## AI Transparency

**This project was developed with significant AI assistance** ([Claude
  Code](https://www.anthropic.com/claude-code) by Anthropic). While
  the tool has been tested extensively and works well in practice,
  users should be aware that:

1.  **Technical implications**: AI-generated code may have unique
    patterns or subtle bugs. We've used `merlint` on itself and other
    projects successfully, but thorough testing is always recommended.

2.  **Legal uncertainty**: The copyright status, license implications,
    and liability for AI-generated code remain legally untested. We cannot
    trace which training data influenced specific code patterns.

3.  **Practical use**: Despite these unknowns, `merlint` has been tested
    on real OCaml projects and provides useful results. The tool is actively
    maintained and used in practice.

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
