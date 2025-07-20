
Test bad example - should find test without library:
  $ merlint -r E610 bad/
  File "dune", line 2, characters 7-16:
  2 |  (name test_e610))
             ^^^^^^^^^
  Error: Module "Test_e610" doesn't exist.
  merlint: [ERROR] Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E610] Test Without Library
    Every test module should have a corresponding library module. This ensures
    that tests are testing actual library functionality rather than testing code
    that doesn't exist in the library.
    - bad/test/test_old_feature.ml:1:0: Test file exists but corresponding library module 'old_feature.ml' not found
    - bad/test/test_runner.ml:1:0: Test file exists but corresponding library module 'runner.ml' not found
  
  Summary: ✗ 2 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - all test files have corresponding library modules:
  $ merlint -r E610 good/
  File "dune", line 2, characters 7-16:
  2 |  (name test_e610))
             ^^^^^^^^^
  Error: Module "Test_e610" doesn't exist.
  merlint: [ERROR] Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  Running merlint analysis...
  
  Analyzing 6 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rules)
  ✓ All checks passed!
