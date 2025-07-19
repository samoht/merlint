Test bad example - should find missing test file:
  $ merlint -r E605 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (3 total issues)
    [E605] Missing Test File
    Each library module should have a corresponding test file to ensure proper
    testing coverage. Create test files following the naming convention
    test_<module>.ml
    - bad.ml:1:0: Library module Bad is missing test file test_Bad.ml
    - dune:1:0: Library module Test_e605 is missing test file test_Test_e605.ml
    - dune:1:0: Library module Good is missing test file test_Good.ml
  
  Summary: ✗ 3 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E605 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (3 total issues)
    [E605] Missing Test File
    Each library module should have a corresponding test file to ensure proper
    testing coverage. Create test files following the naming convention
    test_<module>.ml
    - dune:1:0: Library module Test_e605 is missing test file test_Test_e605.ml
    - dune:1:0: Library module Bad is missing test file test_Bad.ml
    - good.ml:1:0: Library module Good is missing test file test_Good.ml
  
  Summary: ✗ 3 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]
