Bad: README.md skips OCaml/ML fences and lib/foo.mli skips an odoc example.
Shell skips remain allowed.

Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E923 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (3 total issues)
    [E923] Skipped OCaml documentation example (3 issues)
    Do not use [$MDX skip] on OCaml or ML examples in README.md, .mld, or .mli
    files. These snippets are user-facing copy/paste material. Fix the setup,
    split hidden support code into earlier MDX blocks, or make the example
    smaller, but keep it type-checked.
    - bad/README.md:8:0: bad/README.md:8: MDX skip disables an OCaml documentation example; make the snippet compile instead
    - bad/README.md:13:0: bad/README.md:13: MDX skip disables an OCaml documentation example; make the snippet compile instead
    - bad/lib/foo.mli:3:0: bad/lib/foo.mli:3: MDX skip disables an OCaml documentation example; make the snippet compile instead
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬───────────────────────────────────────────╮
  │ Category      │ Issues                                    │
  ├───────────────┼───────────────────────────────────────────┤
  │ Documentation │ 3 (3 skipped ocaml documentation example) │
  ╰───────────────┴───────────────────────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E923` for the rule's description, hint, and good/bad examples.
  [1]

Good: shell skips are allowed, and OCaml examples are checked.

Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E923 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
