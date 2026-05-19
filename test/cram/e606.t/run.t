Test E606: Test File in Wrong Directory

Good tests in correct test stanza:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E606 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 2 files
  
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

Bad test files in wrong test stanza:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E606 bad/
  Dune root: $TESTCASE_ROOT/bad/
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
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────────╮
  │ Category     │ Issues                             │
  ├──────────────┼────────────────────────────────────┤
  │ Test Quality │ 1 (1 test file in wrong directory) │
  ╰──────────────┴────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E606` for the rule's description, hint, and good/bad examples.
  [1]

Test files with declared libraries (should pass):
Build bad2 fixture project:
  $ (cd bad2 && dune build @check)

  $ merlint --build -r E606 bad2/
  Dune root: $TESTCASE_ROOT/bad2/
  Running merlint analysis...
  
  Analyzing 5 files
  
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

Test files with incomplete library declarations:
Build bad3 fixture project:
  $ (cd bad3 && dune build @check)

  $ merlint --build -r E606 bad3/
  Dune root: $TESTCASE_ROOT/bad3/
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
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────────╮
  │ Category     │ Issues                             │
  ├──────────────┼────────────────────────────────────┤
  │ Test Quality │ 1 (1 test file in wrong directory) │
  ╰──────────────┴────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E606` for the rule's description, hint, and good/bad examples.
  [1]
