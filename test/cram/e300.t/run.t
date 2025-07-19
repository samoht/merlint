Test bad example - should find bad variant naming:
  $ merlint -r E300 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (3 total issues)
    [E300] Variant Naming Convention
    Variant constructors should use Snake_case (e.g., Waiting_for_input,
    Processing_data), not CamelCase. This matches the project's naming
    conventions.
    - bad.ml:2:2: Variant 'WaitingForInput' should use Snake_case: 'waiting_for_input'
    - bad.ml:3:2: Variant 'ProcessingData' should use Snake_case: 'processing_data'
    - bad.ml:4:2: Variant 'ErrorOccurred' should use Snake_case: 'error_occurred'
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]
TODO: Variant naming detection not working - Merlin may not provide variant info from type definitions
 
 Test good example - should find no issues:
  $ merlint -r E300 good.ml
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

