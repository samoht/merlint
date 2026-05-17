Build fixture project:
  $ dune build @check

Test bad example - should find deep nesting issues:
  $ merlint -B -r E010 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (2 total issues)
    [E010] Deep Nesting (2 issues)
    This issue means your code has too many nested conditions making it hard to
    follow. Fix it by extracting nested logic into helper functions, using early
    returns to reduce nesting, or combining conditions when appropriate. Aim for
    maximum nesting depth of 4.
    - bad.ml:1:0: Function 'process' has nesting depth of 5 (threshold: 4)
    - bad.ml:36:0: Function 'collect' has nesting depth of 5 (threshold: 4)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────╮
  │ Category     │ Issues             │
  ├──────────────┼────────────────────┤
  │ Code Quality │ 2 (2 deep nesting) │
  ╰──────────────┴────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E010` for the rule's description, hint, and good/bad examples.
  [1]






Test good example - should find no issues:
  $ merlint -B -r E010 good.ml
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
