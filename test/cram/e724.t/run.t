
Test bad example - fuzz directory missing build rules:
  $ merlint -B -r E724 bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E724] Missing Fuzz Build Rules (1 issue)
    Each fuzz directory should have (rule (alias runtest) ...) for property-based
    testing during dune test, and (rule (alias fuzz) ...) for AFL fuzzing
    campaigns with corpus generation.
    - bad/fuzz/dune:1:0: Fuzz directory 'bad/fuzz/' is missing both (rule (alias runtest) ...) and (rule (alias fuzz) ...) build rules
  
  ╭──────────────┬────────────────────────────────╮
  │ Category     │ Issues                         │
  ├──────────────┼────────────────────────────────┤
  │ Test Quality │ 1 (1 missing fuzz build rules) │
  ╰──────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - fuzz directory with all required build rules:
  $ merlint -B -r E724 good/
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
