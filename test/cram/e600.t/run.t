Test bad example - should find test exports module name:
  $ merlint -B -r E600 bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E600] Test Module Convention (2 issues)
    Enforces proper test organization: (1) Test executables (test.ml) should use
    test suites from test modules (e.g., Test_user.suite) rather than defining
    their own test lists directly. (2) Test module interfaces (test_*.mli) should
    only export a 'suite' value with type 'string * unit Alcotest.test_case list'
    and no other values. (3) Alcotest.run should only appear in test.ml, not in
    individual test_*.ml modules.
    - bad/test.ml:1:0: Test file should use test module suites (e.g., Test_user.suite) instead of defining its own test list
    - bad/test_user.mli:1:0: Test module interface should only export 'suite' with type string * unit Alcotest.test_case list
  
  ╭──────────────┬──────────────────────────────╮
  │ Category     │ Issues                       │
  ├──────────────┼──────────────────────────────┤
  │ Test Quality │ 2 (2 test module convention) │
  ╰──────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E600 good/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E600] Test Module Convention (1 issue)
    Enforces proper test organization: (1) Test executables (test.ml) should use
    test suites from test modules (e.g., Test_user.suite) rather than defining
    their own test lists directly. (2) Test module interfaces (test_*.mli) should
    only export a 'suite' value with type 'string * unit Alcotest.test_case list'
    and no other values. (3) Alcotest.run should only appear in test.ml, not in
    individual test_*.ml modules.
    - good/test_user.mli:1:0: Test module interface should only export 'suite' with type string * unit Alcotest.test_case list
  
  ╭──────────────┬──────────────────────────────╮
  │ Category     │ Issues                       │
  ├──────────────┼──────────────────────────────┤
  │ Test Quality │ 1 (1 test module convention) │
  ╰──────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]
