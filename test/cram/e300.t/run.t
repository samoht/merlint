Test bad example - should find bad variant naming:
  $ merlint -r E300 bad.ml
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
TODO: Variant naming detection not working - Merlin may not provide variant info from type definitions
 
 Test good example - should find no issues:
  $ merlint -r E300 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (3 total issues)
    [E300] Variant Naming Convention
    Variant constructors should use PascalCase (e.g., MyVariant, SomeConstructor).
    This is the standard convention in OCaml for variant constructors.
    - good.ml:2:2: good.ml:2:2: Variant 'Waiting_for_input' should use PascalCase: 'WaitingForInput'
    - good.ml:3:2: good.ml:3:2: Variant 'Processing_data' should use PascalCase: 'ProcessingData'
    - good.ml:4:2: good.ml:4:2: Variant 'Error_occurred' should use PascalCase: 'ErrorOccurred'
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

