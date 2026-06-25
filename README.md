# Merlint

An opinionated linter for modern OCaml development.

Merlint is a static analysis tool that helps you write clean,
consistent, and robust OCaml code. It enforces modern best practices
and identifies common issues across several categories, from code
complexity and style to naming conventions and testing.

For a complete reference of all rules, visit the official documentation:
**[https://samoht.github.io/merlint/](https://samoht.github.io/merlint/)**

## Features

- **Broad analysis**: Checks for issues in code quality,
    style, naming, documentation, project structure, and testing.
- **Severity ordering**: Sorts issues by severity, so you can fix the
    most serious problems first.
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
  by renaming to snake_case (e.g., myModule to my_module).
  - src/types.ml:12:4: Module 'myModule' should be 'my_module'

Summary: ✗ 5 total issues
```

## Quick Start

### Installation

On macOS or Linux, the quickest way is the Homebrew tap:

<!-- $MDX skip -->
```sh
$ brew install samoht/monopam/merlint
```

That auto-taps `samoht/monopam`; equivalently, `brew tap samoht/monopam`
once and then `brew install merlint`.

Or install with opam:

<!-- $MDX skip -->
```sh
$ opam install merlint
```

If opam cannot find the package, it has not yet landed in the public
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

The file count and rule totals vary by project, so the analysis output
below is not pinned; the commands themselves are exercised by the test
suite.

<!-- $MDX non-deterministic=output -->
```sh
$ # Analyse the entire project
$ merlint

$ # Analyse specific files or directories
$ merlint lib/ bin/

$ # Exclude vendored or generated code (dune (vendored_dirs ...) subtrees
$ # are skipped automatically)
$ merlint --exclude 'vendor/**'

$ # Filter rules (e.g., run all rules except E110)
$ merlint --rules all-E110

$ # Stop at the first issue, in normal report order (fast fail)
$ merlint --bail

$ # Emit a machine-readable JSON report instead of the formatted tables
$ merlint --json
```

`--bail` reports only the first issue it finds and skips the rest,
useful when you only want a quick pass/fail signal and don't need the
full list.

`--json` prints a single JSON object with the file and rule counts, a
`passed` boolean, and the `issues` (each with its location) and
`excluded` arrays. It suppresses the human `Dune root:` banner and the
summary tables. The exit code is unchanged, `1` when any issue is found
and `0` otherwise, so it stays usable as a gate. This is the format to
consume from editors, CI, and git hooks.

Every issue is tagged with an error code (e.g. `E100`). To see what a
rule means and how to fix it, ask `merlint help`:

```sh
$ merlint help E100
[E100] No Obj usage
  Category: Security/Safety

The Obj module bypasses OCaml's type system and is not part of the language. Any use (Obj.magic, Obj.repr, Obj.obj, Obj.tag, ...) can cause segmentation faults, data corruption, and unpredictable behavior. Use proper type definitions, GADTs, or polymorphic variants instead. If an unsafe boundary is truly unavoidable, isolate it in one module and document why.

Examples:
  Bad:
    let coerce x = Obj.magic x
    let erased x = Obj.repr x
    let recovered o : int = Obj.obj o
    let tag_of x = Obj.tag (Obj.repr x)

  Good:
    (* Use proper type conversions *)
    let int_of_string_opt s =
      try Some (int_of_string s) with _ -> None

    (* Or use variant types *)
    type value = Int of int | String of string
    let to_int = function Int i -> Some i | _ -> None
```

`merlint help config` prints the `merlint.toml` reference as a man page,
and `merlint help --all --format=html -o docs/index.html` (or
`--format=md -o STYLE_GUIDE.md`) renders the full rule reference:

<!-- $MDX skip -->
```sh
$ merlint help config
$ merlint help --all --format=html -o docs/index.html
$ merlint help --all --format=md -o STYLE_GUIDE.md
```

## Configuration

Merlint reads `merlint.toml` from your project root. Run
`merlint help config` for the full reference. The man page
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

Merlint sorts rules into categories, and within a run orders the issues
by severity so the most serious appear first:

- **Code Quality**: `Obj.magic`, catch-all exception handlers, high
  cyclomatic complexity, long functions, and deep nesting.
- **Code Style**: modernisation such as `Re` over `Str` and `Fmt` over
  `Printf`.
- **Naming Conventions**: variant, module, and identifier naming.
- **Documentation**: interface documentation standards.
- **Project Structure**: missing interfaces and dune/opam consistency.
- **Test Quality**: test discipline and coverage of each rule's own
  examples.
- **Interop Testing** and **Code Generation**: conventions for interop
  traces and generated code.

For a complete list of rules and error codes, see the **[official
documentation](https://samoht.github.io/merlint/)**.

## Integration

### Git Pre-commit Hook

Prefer `--json` in hooks: the output is stable and machine-readable
(no banner or formatted tables), and the exit code still signals
success or failure, so the `$?` check below works unchanged.

<!-- $MDX skip -->
```sh
$ # Add to .git/hooks/pre-commit
$ #!/bin/bash
$ echo "Running merlint analysis..."
$ if command -v merlint >/dev/null 2>&1; then
$     merlint --json > merlint-report.json
$     if [ $? -ne 0 ]; then
$         echo "merlint found issues. See merlint-report.json before committing."
$         exit 1
$     fi
$ else
$     echo "Warning: merlint not found, skipping analysis."
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

<!-- $MDX skip -->
```sh
$ # Run tests
$ dune runtest

$ # Format code
$ dune fmt

$ # Test on the codebase itself
$ merlint lib/ bin/
```

### Architecture

Merlint analyses the compiler's typed tree rather than re-parsing source:

1.  **Typed tree.** Merlint reads the `.cmt`/`.cmti` artefacts dune emits
    for your project and loads them with `merlin-lib`. Most rules
    (complexity, control flow, naming, documentation) walk this typed
    tree, so they see exactly what the compiler saw. Run `dune build
    @check` first (or pass `--build`) so the artefacts are present and
    current; merlint skips the typed-tree rules for any file whose
    artefact is missing or stale, and reports which.
2.  **Source text.** A few style rules match directly on source text for
    patterns the typed tree does not carry.
3.  **Project index.** Project-structure and test rules inspect the dune
    project layout: libraries, interfaces, and test stanzas.

Working from typed-tree artefacts means merlint never drives `ocamlmerlin`
itself; it only needs a project that `dune build` can type-check.

## Requirements

- OCaml >= 4.14
- Dune. Merlint reads the typed-tree (`.cmt`/`.cmti`) artefacts dune
  emits, so run it from inside a dune project, with `dune build @check`
  run first (or pass `--build`).

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

ISC, see LICENSE.md for details.

## Acknowledgements

Many thanks to the [Merlin](https://github.com/ocaml/merlin)
maintainers for an indispensable API that makes OCaml tooling
possible.
