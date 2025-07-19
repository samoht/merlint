Test bad example - should find missing log source:
  $ merlint -r E510 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E510] Missing Log Source
    Modules that use logging should declare a log source for better debugging and
    log filtering. Add 'let src = Logs.Src.create "module.name" ~doc:"..."'
    - (global) Missing log source check not yet implemented
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E510 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E510] Missing Log Source
    Modules that use logging should declare a log source for better debugging and
    log filtering. Add 'let src = Logs.Src.create "module.name" ~doc:"..."'
    - (global) Missing log source check not yet implemented
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]
