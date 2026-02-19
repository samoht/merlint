Test bad example - library and test in same directory:
  $ merlint -B -r E515 bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E515] Tests and Libraries in Same Directory (1 issue)
    Libraries and tests should be in separate directories for clear project
    structure. Put library code in lib/ and tests in test/. Using explicit
    (modules ...) to co-locate them in the same directory is discouraged.
    - bad/lib/test_data.ml:1:0: Test 'test_data' and library 'data' are in the same directory 'bad/lib/' - move tests to a separate test/ directory
  ✓ Test Quality (0 total issues)
  
  ╭───────────────────┬─────────────────────────────────────────────╮
  │ Category          │ Issues                                      │
  ├───────────────────┼─────────────────────────────────────────────┤
  │ Project Structure │ 1 (1 tests and libraries in same directory) │
  ╰───────────────────┴─────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]






Test good example - library and test in separate directories:
  $ merlint -B -r E515 good/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!



