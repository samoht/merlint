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
  ✗ Test Quality (2 total issues)
    [E606] Test File in Wrong Directory (2 issues)
    Test files for different libraries should not be mixed in the same test
    directory. Organize test files so that each test directory contains tests for
    only one library to maintain clear test organization.
    - bad/test_parser.ml:1:0: Test file 'test_parser.ml' tests library 'parser_lib' but is mixed with tests for library 'utils_lib'
    - bad/test_utils.ml:1:0: Test file 'test_utils.ml' tests library 'utils_lib' but is mixed with tests for library 'parser_lib'
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test files in wrong directory (should be in subdirectories):
  $ merlint -r E606 bad2/
  Running merlint analysis...
  
  Analyzing 5 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E606] Test File in Wrong Directory (2 issues)
    Test files for different libraries should not be mixed in the same test
    directory. Organize test files so that each test directory contains tests for
    only one library to maintain clear test organization.
    - bad2/test/test_feed.ml:1:0: Test file 'test_feed.ml' tests library 'views_lib' but is mixed with tests for library 'core_lib'
    - bad2/test/test_page.ml:1:0: Test file 'test_page.ml' tests library 'core_lib' but is mixed with tests for library 'views_lib'
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]
