
Test bad example - fuzz dir with no fuzz.ml runner:
  $ merlint -B -r E718 bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E718] Non-Fuzz File in Fuzz Directory (1 issue)
    All .ml files in a fuzz/ directory should follow the fuzz_ naming convention
    (e.g., fuzz_parser.ml) or be the fuzz runner (fuzz.ml). Each fuzz/ directory
    must have a fuzz.ml runner.
    - bad/fuzz/dune:1:0: Fuzz directory 'bad/fuzz/' (stanza 'fuzz_parser') has no fuzz.ml runner
  
  ╭──────────────┬───────────────────────────────────────╮
  │ Category     │ Issues                                │
  ├──────────────┼───────────────────────────────────────┤
  │ Test Quality │ 1 (1 non-fuzz file in fuzz directory) │
  ╰──────────────┴───────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - fuzz dir with proper fuzz.ml runner:
  $ merlint -B -r E718 good/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
