Test bad example - missing fuzz .mli file:
  $ merlint -B -r E705 bad/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E705] Missing Fuzz MLI File (1 issue)
    Fuzz modules (fuzz_*.ml) should have corresponding .mli files that export only
    'suite : string * Crowbar.test_case list'. This enforces proper encapsulation
    of fuzz test internals.
    - bad/fuzz/fuzz_parser.ml:1:0: Fuzz module bad/fuzz/fuzz_parser.ml is missing interface file bad/fuzz/fuzz_parser.mli
  
  ╭──────────────┬─────────────────────────────╮
  │ Category     │ Issues                      │
  ├──────────────┼─────────────────────────────┤
  │ Test Quality │ 1 (1 missing fuzz mli file) │
  ╰──────────────┴─────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - fuzz .mli file present with correct type:
  $ merlint -B -r E705 good/
  Running merlint analysis...
  
  Analyzing 5 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
