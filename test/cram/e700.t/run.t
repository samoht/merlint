Test bad example - fuzz.ml defines tests inline:
  $ merlint -B -r E700 bad/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E700] Fuzz Module Convention (1 issue)
    The fuzz runner (fuzz.ml) should call Fuzz_*.run() for each fuzz module rather
    than defining tests with add_test directly. This keeps fuzz tests organized
    per-module.
    - bad/fuzz/fuzz.ml:1:0: Fuzz runner 'fuzz.ml' defines tests inline - use Fuzz_*.run() to delegate to fuzz modules
  
  ╭──────────────┬──────────────────────────────╮
  │ Category     │ Issues                       │
  ├──────────────┼──────────────────────────────┤
  │ Test Quality │ 1 (1 fuzz module convention) │
  ╰──────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - fuzz.ml delegates to Fuzz_*.run():
  $ merlint -B -r E700 good/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
