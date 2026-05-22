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

Merlint provides clear, colour-coded output that groups issues by
category and explains how to fix them.

```
Running merlint analysis...

Analysing 15 files

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

Install with opam:

<!-- $MDX skip -->
```sh
$ opam install merlint
```

If opam cannot find the package, it may not yet be released in the public
`opam-repository`. Add the overlay repository, then install it:

<!-- $MDX skip -->
```sh
$ opam repo add samoht https://tangled.org/gazagnaire.org/opam-overlay.git
$ opam update
$ opam install merlint
```

To build from source instead:

<!-- $MDX skip -->
```sh
$ opam install . --deps-only
$ dune build
$ dune install
```

### Usage
<!-- $MDX non-deterministic=command -->
```sh
$ # Analyse the entire project
$ merlint

$ # Analyse specific files or directories
$ merlint src/ lib/

$ # Dune (vendored_dirs ...) subtrees are skipped automatically

$ # Exclude vendored or generated code
$ merlint --exclude 'vendor/**'

$ # Filter rules (e.g., run all rules except E110)
$ merlint --rules A-E110

$ # Stop at the first issue, in normal report order (fast fail)
$ merlint --bail

$ # Emit a machine-readable JSON report instead of the formatted tables
$ merlint --json
```

`--bail` reports only the first issue it finds and skips the rest --
useful when you only want a quick pass/fail signal and don't need the
full list.

`--json` prints a single JSON object -- file/rule counts, a `passed`
boolean, and the `issues` (each with its location) and `excluded`
arrays -- and suppresses the human `Dune root:` banner and summary
tables. The exit code is unchanged -- `1` when any issue is found, `0`
otherwise -- so it stays usable as a gate. This is the format to
consume from editors, CI, and git hooks.

Every issue is tagged with an error code (e.g. `E100`). To see what a
rule means and how to fix it, ask `merlint help`:

<!-- $MDX non-deterministic=command -->
```sh
$ # Describe a single rule on the terminal
$ merlint help E100

$ # Describe the configuration file format
$ merlint help config

$ # Render the full reference as HTML or Markdown
$ merlint help --all --format=html -o docs/index.html
$ merlint help --all --format=md -o STYLE_GUIDE.md
```

## Configuration

Merlint reads `merlint.toml` from your project root. Run
`merlint help config` for the full reference -- the man page
covers the settings keys, the `[[rules]]` block format (single glob
or list of globs), and the pattern syntax. The same examples it
shows are round-tripped through the parser by the test suite, so
the docs can't drift from the implementation.

Quick example:

```toml
max-complexity = 15
max-function-length = 100

[[rules]]
files = ["lib/color.ml*", "lib/margin.ml*", "lib/padding.ml*"]
exclude = ["E330"]
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

Prefer `--json` in hooks: the output is stable and machine-readable
(no banner or formatted tables), and the exit code still signals
success or failure, so the `$?` check below works unchanged.

<!-- $MDX non-deterministic=command -->
```sh
$ # Add to .git/hooks/pre-commit
$ #!/bin/bash
$ echo "Running merlint analysis..."
$ if command -v merlint >/dev/null 2>&1; then
$     merlint --json > merlint-report.json
$     if [ $? -ne 0 ]; then
$         echo "❌ Merlint found issues. See merlint-report.json before committing."
$         exit 1
$     fi
$ else
$     echo "⚠️  Warning: merlint not found. Skipping analysis."
$ fi
```

### CI/CD
```yaml
- name: Lint OCaml code
  run: |
    merlint --json
    # Exit code 1 if issues found, 0 if clean
```

## Style Guide

For detailed guidelines on the OCaml coding conventions enforced by
Merlint, see the official **[Style Guide](docs/STYLE_GUIDE.md)**.

## Development

<!-- $MDX non-deterministic=command -->
```sh
$ # Run tests
$ dune runtest

$ # Format code
$ dune fmt

$ # Test on the codebase itself
$ merlint lib/ bin/
```

### Architecture

Merlint uses a multi-strategy approach to analyse OCaml code:

1.  **Merlin outline** for function boundaries and line counts.
2.  **Merlin AST dump** for name extraction and **compiler-libs parsetree** for cyclomatic complexity and control flow.
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

## Licence

ISC — see LICENSE.md for details.

## Acknowledgements

Many thanks to the [Merlin](https://github.com/ocaml/merlin)
maintainers for an indispensable API that makes OCaml tooling
possible.
