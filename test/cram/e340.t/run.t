Build fixture project:
  $ dune build @check

Test bad example - should find error pattern usage:
  $ merlint --build -r E340 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    [E340] Error Pattern Detection (4 issues)
    Using raw Error constructors with Fmt.str (including polymorphic variants like
    `Msg) can lead to inconsistent error messages. Consider creating error helper
    functions (prefixed with 'err_') that encapsulate common error patterns and
    provide consistent formatting. Place these error helpers at the top of the
    file to make it easier to see all the different error cases in one place.
    - bad.ml:3:9: Found 'Error applied to Fmt.str' pattern - consider using 'err_*' helper functions for consistent error handling
    - bad.ml:6:8: Found 'Error applied to Fmt.str' pattern - consider using 'err_*' helper functions for consistent error handling
    - bad.ml:11:4: Found 'Error (`Msg ...) applied to Fmt.str' pattern - consider using 'err_*' helper functions for consistent error handling
    - bad.ml:13:4: Found 'Error (`Msg ...) applied to Fmt.str' pattern - consider using 'err_*' helper functions for consistent error handling
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬───────────────────────────────╮
  │ Category   │ Issues                        │
  ├────────────┼───────────────────────────────┤
  │ Code Style │ 4 (4 error pattern detection) │
  ╰────────────┴───────────────────────────────╯
  
  
  Summary: ✗ 4 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E340` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint --build -r E340 good.ml
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
