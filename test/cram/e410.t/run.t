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
  ✗ Documentation (3 total issues)
    [E410] Bad Documentation Style (3 issues)
    Follow OCaml documentation conventions: Functions should use '[name args]
    description.' format. Values should use '[name] description.' format.
    Operators should use infix notation like '[x op y] description.' All
    documentation should end with a period. Avoid redundant phrases like 'This
    function...'.
    - bad.mli:3:0: Documentation for '@>' should use '[x op y] description.' format for operators
    - bad.mli:6:0: Documentation for '<@' should end with a period
    - bad.mli:12:0: Documentation for 'create' has 1 args in doc but function takes 2 required args
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬───────────────────────────────╮
  │ Category      │ Issues                        │
  ├───────────────┼───────────────────────────────┤
  │ Documentation │ 3 (3 bad documentation style) │
  ╰───────────────┴───────────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
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
