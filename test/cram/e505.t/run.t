Test bad example - should find missing interface file:
  $ merlint -r E505 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E505] Missing MLI File (1 issue)
    Library modules should have corresponding .mli files for proper encapsulation
    and API documentation. Create interface files to hide implementation details
    and provide a clean API.
    - bad.ml:1:0: Library module bad.ml is missing interface file bad.mli
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E505 good.ml good.mli
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!

Test interface definition file - should not require .mli:
  $ merlint -r E505 test_intf.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
