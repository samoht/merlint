Test bad example - empty test suite:
  $ merlint -B -r E621 bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E621] Empty Test Suite (1 issue)
    An empty test suite provides no value. Tests should: (1) cover the module's
    public API with representative inputs, (2) exercise boundary conditions and
    edge cases, (3) verify error handling and invalid inputs, (4) document
    expected behaviour through concrete examples. A suite with no test cases will
    never catch regressions.
    - bad/test_parser.ml:1:0: Test suite 'parser' is empty — add meaningful tests covering the public API, edge cases, and error paths
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────╮
  │ Category     │ Issues                 │
  ├──────────────┼────────────────────────┤
  │ Test Quality │ 1 (1 empty test suite) │
  ╰──────────────┴────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - non-empty test suite:
  $ merlint -B -r E621 good/
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
