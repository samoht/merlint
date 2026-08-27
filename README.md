# Merlint

An opinionated linter for modern OCaml development.

Merlint is a static analysis tool that helps you write clean,
consistent, and robust OCaml code. It reads the typed-tree
(`.cmt`/`.cmti`) artefacts dune emits, so most rules see exactly what
the compiler saw, and it enforces current best practices across code
quality, style, naming, documentation, project structure, and testing.
It works out of the box: no configuration is required to get started,
and issues are sorted by severity so the most serious appear first.

For a complete reference of all rules, visit the official documentation:
**[https://samoht.github.io/merlint/](https://samoht.github.io/merlint/)**

## Output

Merlint groups issues by category, tags each with an error code, and
explains how to fix them.

```
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
✗ Naming Conventions (1 total issues)
  [E300] Variant Naming Convention
  This issue means your variant names don't follow OCaml conventions. Fix them
  by using Snake_case (e.g., Some_value, Waiting_for_input).
  - src/types.ml:8:2: Variant 'waitingForInput' should be 'Waiting_for_input'

Summary: ✗ 3 total issues
```

## Installation

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

## Requirements

- OCaml >= 4.14
- Dune. Merlint reads the typed-tree (`.cmt`/`.cmti`) artefacts dune
  emits, so run it from inside a dune project, with `dune build @check`
  run first (or pass `--build`). Any file whose artefact is missing or
  stale has its typed-tree rules skipped, and merlint reports which.

## Usage

The file count and rule totals vary by project, so the analysis output
below is not pinned; the commands themselves are exercised by the test
suite.

<!-- $MDX non-deterministic=output -->
```sh
$ # Analyse the entire project
$ merlint

$ # Analyse specific files or directories
$ merlint lib/ bin/

$ # Filter rules (e.g., run all rules except E110)
$ merlint --rules all-E110

$ # Emit a machine-readable JSON report instead of the formatted tables
$ merlint --json
```

`merlint --help` lists the rest. `--exclude 'vendor/**'` skips vendored
or generated code (dune `(vendored_dirs ...)` subtrees are skipped
automatically), and `--bail` reports only the first issue in normal
report order, for a quick pass/fail signal.

`--json` prints a single JSON object with the file and rule counts, a
`passed` boolean, the `issues` (each with its location) and `excluded`
arrays, and the three sets of paths the run could not look at:
`unclaimed_files` (no dune stanza compiles them, so no rule ran on them),
`unchecked_files` (a rule asked for a typedtree and no artefact
described the source) and `skipped_paths` (named on the command line and
neither `.ml` nor `.mli`, so merlint has no rule that reads one).
`passed` is false while any of the three has a member. All three are
complete, whatever the verbosity, so a repo-wide run can enumerate its
own blind spot in one pass; the human-readable warning samples ten of
the first two and `-v` names them all, while every skipped path is named
under the summary.
`--json` suppresses the human `Dune root:` banner and the summary tables,
leaving the exit status unchanged, so it stays usable as a gate. This is
the format to consume from editors, CI, and git hooks.

## Exit status

Merlint answers two independent questions -- does the code have
findings, and did merlint read all of what it was pointed at -- so the
status is a bit set rather than one number:

| Status | Meaning                                                       |
|--------|---------------------------------------------------------------|
| `0`    | complete run, no findings                                     |
| `1`    | findings: the code merlint read has issues to fix             |
| `2`    | incomplete coverage: merlint could not read part of it        |
| `3`    | both: findings, over a run that read only part of the tree    |

`2` is not a warning. A run that exits `0` having read half of what it
was given is read as "this code is clean", and a source no stanza claims
is a source no rule ever examined. A path merlint has no rule for sets
the same bit: the run never opened it, and the verdict over the other
arguments does not answer for it. `3` is the worst of the three: the
findings are real and the list they came from is also short. A gate that
only wants pass or fail reads any non-zero and needs no change.

To see what a rule means and how to fix it, and to render the rule
reference, ask `merlint help`:

<!-- $MDX skip -->
```sh
$ merlint help E100                                       # one rule, with examples
$ merlint help config                                     # the merlint.toml reference
$ merlint help --all --format=html -o docs/index.html     # the full rule reference
$ merlint help --all --format=md -o STYLE_GUIDE.md
```

## Configuration

Merlint reads `merlint.toml` from your project root. Run
`merlint help config` for the full reference: the settings keys, the
`workspace` declaration a checkout built from a workspace elsewhere
needs, the `[[rules]]` block format (single glob or list of globs), and
the pattern syntax. The same examples it shows are round-tripped through
the parser by the test suite, so the docs can't drift from the
implementation.

```toml
max-complexity = 15
max-function-length = 100

[[rules]]
files = ["lib/color.ml*", "lib/margin.ml*", "lib/padding.ml*"]
exclude = ["E330"]
```

## Rules

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

For the complete list of rules and error codes, see the **[official
documentation](https://samoht.github.io/merlint/)**; for the conventions
behind them, the **[Style Guide](docs/STYLE_GUIDE.md)**.

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
