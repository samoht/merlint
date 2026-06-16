Test bad example - single bare project missing its .ocamlformat:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E500 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E500] Missing OCamlformat File (1 issue)
    Every package needs its own .ocamlformat so each standalone subtree formats
    consistently, not just the umbrella root. Create one in each directory the
    linter flags.
    - bad/.ocamlformat:1:0: Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────╮
  │ Category          │ Issues                         │
  ├───────────────────┼────────────────────────────────┤
  │ Project Structure │ 1 (1 missing ocamlformat file) │
  ╰───────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E500` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - root has a .ocamlformat, so no issues:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E500 good/
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

Test multi-package project - the root has a .ocamlformat but the [liba]
sub-package directory does not, so E500 flags the package missing its own
file instead of passing because the umbrella root has one:
Build multi fixture project:
  $ (cd multi && dune build @check)

  $ merlint --build -r E500 multi/
  Dune root: $TESTCASE_ROOT/multi/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E500] Missing OCamlformat File (1 issue)
    Every package needs its own .ocamlformat so each standalone subtree formats
    consistently, not just the umbrella root. Create one in each directory the
    linter flags.
    - multi/liba/.ocamlformat:1:0: Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────╮
  │ Category          │ Issues                         │
  ├───────────────────┼────────────────────────────────┤
  │ Project Structure │ 1 (1 missing ocamlformat file) │
  ╰───────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E500` for the rule's description, hint, and good/bad examples.
  [1]
