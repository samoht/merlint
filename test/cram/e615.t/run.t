
Test bad example - should find test suite not included:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E615 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E615] Test Suite Not Included (2 issues)
    All test modules should be included in the main test runner (test.ml). Add the
    missing test suite to ensure all tests are run.
    - bad/test/test.ml:1:0: Test module test_helpers is not included in bad/test/test.ml
    - bad/test/test.ml:1:0: Test module test_parser is not included in bad/test/test.ml
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬───────────────────────────────╮
  │ Category     │ Issues                        │
  ├──────────────┼───────────────────────────────┤
  │ Test Quality │ 2 (2 test suite not included) │
  ╰──────────────┴───────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E615` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E615 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 3 files
  
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
