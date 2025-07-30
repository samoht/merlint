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
    Organize test files to match your library structure. Create separate test
    directories for each library (e.g., test/core/ for core library, test/views/
    for views library) and move test files to their corresponding directories.
    - bad/test_parser.ml:1:0: Test file 'test_parser.ml' should be moved to a 'parser_lib' test directory since it tests the 'parser_lib' library
    - bad/test_utils.ml:1:0: Test file 'test_utils.ml' should be moved to a 'utils_lib' test directory since it tests the 'utils_lib' library
  
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
    Organize test files to match your library structure. Create separate test
    directories for each library (e.g., test/core/ for core library, test/views/
    for views library) and move test files to their corresponding directories.
    - bad2/test/test_feed.ml:1:0: Test file 'test_feed.ml' should be moved to a 'views_lib' test directory since it tests the 'views_lib' library
    - bad2/test/test_page.ml:1:0: Test file 'test_page.ml' should be moved to a 'core_lib' test directory since it tests the 'core_lib' library
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]
