Test bad example - should find test exports module name:
  $ merlint -r E600 bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E600] Test Module Convention (2 issues)
    Test executables (test.ml) should use test suites exported by test modules
    (test_*.ml) rather than defining their own test lists. Test module interfaces
    (test_*.mli) should only export a 'suite' value with the correct type to
    ensure proper test organization.
    - bad/test.ml:1:0: Test file should use test module suites (e.g., Test_user.suite) instead of defining its own test list
    - bad/test_user.mli:1:0: Test module interface should only export 'suite' with type unit Alcotest.test
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E600 good/
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
