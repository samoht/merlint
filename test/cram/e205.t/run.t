Test bad example - should find usage of Printf instead of Fmt:
  $ dune build @check
  $ merlint -B -r E205 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (3 total issues)
    [E205] Consider Using Fmt Module (3 issues)
    The Fmt module provides a more modern and composable approach to formatting.
    It offers better type safety and cleaner APIs compared to Printf/Format
    modules.
    - bad.ml:2:2: Consider using Fmt module instead of Printf for better formatting
    - bad.ml:4:2: Consider using Fmt module instead of Printf for better formatting
    - bad.ml:6:2: Consider using Fmt module instead of Format for better formatting
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬─────────────────────────────────╮
  │ Category   │ Issues                          │
  ├────────────┼─────────────────────────────────┤
  │ Code Style │ 3 (3 consider using fmt module) │
  ╰────────────┴─────────────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E205` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E205 good.ml
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

Test shadow example - local Printf/Format are not Stdlib modules:
  $ merlint -B -r E205 shadow.ml
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
