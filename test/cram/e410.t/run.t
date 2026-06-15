Build fixture project:
  $ dune build @check

Test bad example - should find bad documentation style:
  $ merlint --build -r E410 bad.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (5 total issues)
    [E410] Bad Documentation Style (5 issues)
    Follow OCaml documentation conventions: when documentation starts with [name
    ...], [name] should be the function or value being documented. Operators
    should use infix notation like '[x op y] description.' All documentation
    should end with a period. Avoid redundant phrases like 'This function...'.
    - bad.mli:3:0: Documentation for '@>' should use '[x op y] description.' format for operators
    - bad.mli:6:0: Documentation for '<@' should end with a period
    - bad.mli:12:0: Documentation for 'create' has 1 args in doc but function takes at least 2 mandatory args
    - bad.mli:15:0: Documentation for 'trim' has 2 args in doc but function takes at most 1 args
    - bad.mli:18:0: Documentation for 'combine' has 3 args in doc but function takes at most 1 args
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬───────────────────────────────╮
  │ Category      │ Issues                        │
  ├───────────────┼───────────────────────────────┤
  │ Documentation │ 5 (5 bad documentation style) │
  ╰───────────────┴───────────────────────────────╯
  
  
  Summary: ✗ 5 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E410` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint --build -r E410 good.mli
  Dune root: $TESTCASE_ROOT/
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
