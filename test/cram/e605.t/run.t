Test bad example - should find missing test files:
  $ merlint -r E605 bad/
  Running merlint analysis...
  
  Analyzing 5 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E605] Missing Test File (2 issues)
    Each library module should have a corresponding test file to ensure proper
    testing coverage. Create test files following the naming convention
    test_<module>.ml
    - bad/lib/config.ml:1:0: Library module config is missing test file test_config.ml
    - bad/lib/parser.ml:1:0: Library module parser is missing test file test_parser.ml
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E605 good/
  Running merlint analysis...
  
  Analyzing 7 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!

Test multidir - analyzing lib and test together should not report missing tests when they exist:
  $ merlint -r E605 good/lib good/test 2>&1 | grep -c "missing test file"
  0
  [1]
