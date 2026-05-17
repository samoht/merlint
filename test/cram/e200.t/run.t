Test bad example - should find usage of outdated Str module:
  $ dune build @check
  $ merlint -B -r E200 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (2 total issues)
    [E200] Outdated Str Module (2 issues)
    The Str module is outdated and has a problematic API. Use the Re module
    instead for regular expressions. Re provides a better API, is more performant,
    and doesn't have global state issues.
    - bad.ml:2:2: Usage of deprecated Str module detected - use Re module instead
    - bad.ml:2:20: Usage of deprecated Str module detected - use Re module instead
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬───────────────────────────╮
  │ Category   │ Issues                    │
  ├────────────┼───────────────────────────┤
  │ Code Style │ 2 (2 outdated str module) │
  ╰────────────┴───────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E200` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E200 good.ml
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

Test shadow example - local Str is not the Str library:
  $ merlint -B -r E200 shadow.ml
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
