Test E606: Test File in Wrong Directory

Good tests in correct test stanza:
  $ merlint -r E606 good/ 2>&1 | grep -A10 "merlint analysis" | head -10
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)

Bad test files in wrong test stanza:
  $ merlint -r E606 bad/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E606] Test File in Wrong Directory (1 issue)
    Test files for different libraries should not be mixed in the same test
    directory. Organize test files so that each test directory contains tests for
    only one library to maintain clear test organization.
    - bad/test_utils.ml:1:0: Test file 'test_utils.ml' tests library 'utils_lib' which is not explicitly declared in the test's dune file
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test files with declared libraries (should pass):
  $ merlint -r E606 bad2/
  Running merlint analysis...
  
  Analyzing 5 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!

Test files with incomplete library declarations:
  $ merlint -r E606 bad3/
  merlint: [ERROR] Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  Running merlint analysis...
  
  Analyzing 5 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E606] Test File in Wrong Directory (1 issue)
    Test files for different libraries should not be mixed in the same test
    directory. Organize test files so that each test directory contains tests for
    only one library to maintain clear test organization.
    - bad3/test/test_feed.ml:1:0: Test file 'test_feed.ml' tests library 'views_lib' which is not explicitly declared in the test's dune file
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]
