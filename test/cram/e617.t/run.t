Test bad examples - should find naming issues:
  $ merlint -r E617 test_bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E617] Test Suite Naming Convention (1 issue)
    Test suite names should follow these conventions: (1) Use lowercase snake_case
    for the suite name. (2) The suite name should match the test file name - for
    example, test_foo.ml should have suite name 'foo'. This makes it easier to
    identify which test file contains which suite.
    - test_bad.ml:3:0: Test suite name 'BadName' should be lowercase - use 'badname' instead
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

  $ merlint -r E617 test_config.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E617] Test Suite Naming Convention (1 issue)
    Test suite names should follow these conventions: (1) Use lowercase snake_case
    for the suite name. (2) The suite name should match the test file name - for
    example, test_foo.ml should have suite name 'foo'. This makes it easier to
    identify which test file contains which suite.
    - test_config.ml:5:0: Test suite name 'Config' should be lowercase - use 'config' instead
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

  $ merlint -r E617 test_parser.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E617] Test Suite Naming Convention (1 issue)
    Test suite names should follow these conventions: (1) Use lowercase snake_case
    for the suite name. (2) The suite name should match the test file name - for
    example, test_foo.ml should have suite name 'foo'. This makes it easier to
    identify which test file contains which suite.
    - test_parser.ml:5:0: Test suite name 'parser-tests' should use snake_case naming convention
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

  $ merlint -r E617 test_user_auth.ml  
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E617] Test Suite Naming Convention (1 issue)
    Test suite names should follow these conventions: (1) Use lowercase snake_case
    for the suite name. (2) The suite name should match the test file name - for
    example, test_foo.ml should have suite name 'foo'. This makes it easier to
    identify which test file contains which suite.
    - test_user_auth.ml:5:0: Test suite name 'auth' should match the filename - expected 'user_auth'
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good examples - should find no issues:
  $ merlint -r E617 good/test_config.ml good/test_parser.ml good/test_user_auth.ml
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
