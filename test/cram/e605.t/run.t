Test bad example - should find missing test files:
  $ merlint -r E605 bad/
  Entering directory 'bad'
  Leaving directory 'bad'
  Running merlint analysis...
  
  Analyzing 5 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E605] Missing Test File
    Each library module should have a corresponding test file to ensure proper
    testing coverage. Create test files following the naming convention
    test_<module>.ml
    - bad/lib/config.ml:1:0: Library module config is missing test file test_config.ml
    - bad/lib/parser.ml:1:0: Library module parser is missing test file test_parser.ml
  
  Summary: ✗ 2 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E605 good/
  Entering directory 'good'
  Leaving directory 'good'
  Running merlint analysis...
  
  Analyzing 7 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rules)
  ✓ All checks passed!
