Test bad example - fuzz.ml defines tests inline:
  $ merlint -B -r E700 bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E700] Fuzz Module Convention (1 issue)
    The fuzz runner (fuzz.ml) should collect Fuzz_*.suite from each fuzz module
    rather than defining test_case directly. This keeps fuzz tests organized
    per-module.
    - bad/fuzz/fuzz.ml:1:0: Fuzz runner 'fuzz.ml' defines tests inline - use Fuzz_*.suite to delegate to fuzz modules
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬──────────────────────────────╮
  │ Category     │ Issues                       │
  ├──────────────┼──────────────────────────────┤
  │ Test Quality │ 1 (1 fuzz module convention) │
  ╰──────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E700` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - fuzz.ml delegates to Fuzz_*.run():
  $ merlint -B -r E700 good/
  Running merlint analysis...
  
  Analyzing 3 files
  
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
