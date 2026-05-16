
Test bad example - fuzz dir with no fuzz.ml runner:
  $ merlint -B -r E718 bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (3 total issues)
    [E718] Non-Fuzz File in Fuzz Directory (3 issues)
    All .ml files in a fuzz/ directory should follow the fuzz_ naming convention
    (e.g., fuzz_parser.ml) or be the fuzz runner (fuzz.ml). Each fuzz directory
    must use fuzz.exe --gen-corpus in its dune rule.
    - bad/fuzz/dune:1:0: Fuzz directory 'bad/fuzz/' has fuzz_* modules but is missing fuzz.ml runner
    - bad/fuzz/dune:1:0: Fuzz directory 'bad/fuzz/' is missing --gen-corpus in fuzz dune rule
    - bad/fuzz/parser_helpers.ml:1:0: File 'parser_helpers.ml' in fuzz stanza 'fuzz_parser' does not follow the fuzz_ naming convention - rename to fuzz_parser_helpers.ml
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬───────────────────────────────────────╮
  │ Category     │ Issues                                │
  ├──────────────┼───────────────────────────────────────┤
  │ Test Quality │ 3 (3 non-fuzz file in fuzz directory) │
  ╰──────────────┴───────────────────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E718` for the rule's description, hint, and good/bad examples.
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
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
