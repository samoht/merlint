Test bad example - should find bad function naming:
  $ merlint -r E315 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (1 total issues)
    [E315] Type Naming Convention
    Type names should use snake_case, except for the conventional names 't' and
    'id'. This convention helps maintain consistency across the codebase.
    - bad.ml:1:0: bad.ml:1:0: Type name 'type_declaration userProfile/278 (bad.ml[1,0+0]..bad.ml[1,0+36])' should use snake_case: 'type_declaration user_profile/278 (bad.ml[1,0+0]..bad.ml[1,0+36])'
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E315 good.ml
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
