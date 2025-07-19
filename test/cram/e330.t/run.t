Test bad example - should find redundant module name:
  $ merlint -r E330 bad/process.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (3 total issues)
    [E330] Redundant Module Name
    Avoid prefixing type or function names with the module name. The module
    already provides the namespace, so Message.message_type should just be
    Message.t
    - bad/process.ml:2:0: Function 'process_start' has redundant module prefix from Process
    - bad/process.ml:3:0: Function 'process_stop' has redundant module prefix from Process
    - bad/process.ml:4:0: Type 'process_config' has redundant module prefix from Process
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues (applied 1 rules)
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
  
  Summary: ✓ 0 total issues (applied 1 rules)
  ✓ All checks passed!
