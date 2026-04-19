Test bad example - should find bad variant naming:
  $ merlint -B -r E300 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (3 total issues)
    [E300] Variant Naming Convention (3 issues)
    Variant constructors should use Snake_case (e.g., Waiting_for_input,
    Processing_data), not CamelCase. This matches the project's naming
    conventions.
    - bad.ml:2:2: Variant 'WaitingForInput' should use Snake_case: 'Waiting_for_input'
    - bad.ml:3:2: Variant 'ProcessingData' should use Snake_case: 'Processing_data'
    - bad.ml:4:2: Variant 'ErrorOccurred' should use Snake_case: 'Error_occurred'
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬─────────────────────────────────╮
  │ Category           │ Issues                          │
  ├────────────────────┼─────────────────────────────────┤
  │ Naming Conventions │ 3 (3 variant naming convention) │
  ╰────────────────────┴─────────────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues (including compound terms like MacOS):
  $ merlint -B -r E300 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
