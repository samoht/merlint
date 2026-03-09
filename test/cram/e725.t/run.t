Test bad example - fuzz suite name mismatch:
  $ merlint -B -r E725 bad/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E725] Fuzz Test Suite Mismatch (1 issue)
    Fuzz tests must declare let suite = ("<module>", [...]) where <module> matches
    the filename: fuzz_<module>.ml should use suite:"<module>".
    - bad/fuzz/fuzz_parser.ml:1:0: Fuzz suite "wrong_name" should be "parser"
  
  ╭──────────────┬────────────────────────────────╮
  │ Category     │ Issues                         │
  ├──────────────┼────────────────────────────────┤
  │ Test Quality │ 1 (1 fuzz test suite mismatch) │
  ╰──────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]






Test good example - fuzz suite name matches filename:
  $ merlint -B -r E725 good/
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



