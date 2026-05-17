Build fixture project:
  $ dune build @check

Test bad example - should find bad function naming convention:
  $ merlint -B -r E325 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (2 total issues)
    [E325] Function Naming Convention (2 issues)
    Functions that return option types should be prefixed with 'find_', while
    functions that return non-option types should be prefixed with 'get_'. This
    convention helps communicate the function's behavior to callers.
    - bad.ml:1:0: Function 'get_user' naming convention: consider 'find_user'
    - bad.ml:2:0: Function 'find_name' naming convention: consider 'get_name'
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬──────────────────────────────────╮
  │ Category           │ Issues                           │
  ├────────────────────┼──────────────────────────────────┤
  │ Naming Conventions │ 2 (2 function naming convention) │
  ╰────────────────────┴──────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E325` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E325 good.ml
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
