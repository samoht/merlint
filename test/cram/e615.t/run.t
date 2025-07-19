
Test bad example - should find test suite not included:
  $ merlint -r E615 bad/
  merlint: [ERROR] Failed to analyze bad/test/test.ml: Merlint.Dump.Wrong_ast_type
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E615] Test Suite Not Included
    All test modules should be included in the main test runner (test.ml). Add the
    missing test suite to ensure all tests are run.
    - bad/test/test.ml:1:0: Test module test_parser is not included in bad/test/test.ml
  
  Summary: ✗ 1 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E615 good/
  merlint: [ERROR] Failed to analyze good/test/test.ml: Merlint.Dump.Wrong_ast_type
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rules)
  ✓ All checks passed!
