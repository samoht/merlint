Test bad example - should find redundant module name:
  $ merlint -r E330 bad/process.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (3 total issues)
    [E330] Redundant Module Names
    This issue means your function or type name redundantly includes the module
    name. Fix it by removing the redundant prefix since the module context is
    already clear from usage.
    - bad/process.ml:2:0: 'process_start' has redundant module prefix 'Process'
    - bad/process.ml:3:0: 'process_stop' has redundant module prefix 'Process'
    - bad/process.ml:4:0: 'process_config' has redundant module prefix 'Process'
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E330 good/process.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues
  ✓ All checks passed!
