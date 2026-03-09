Test bad example - fuzz test name has wrong prefix:
  $ merlint -B -r E725 bad/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E725] Fuzz Test Name Prefix (1 issue)
    Fuzz test names must follow the convention "<module>: <description>" where
    <module> matches the filename (fuzz_<module>.ml with underscores replaced by
    hyphens). This enables automatic grouping in test output.
    - bad/fuzz/fuzz_parser.ml:1:0: Fuzz test name "wrong prefix" should start with "parser: "
  
  ╭──────────────┬─────────────────────────────╮
  │ Category     │ Issues                      │
  ├──────────────┼─────────────────────────────┤
  │ Test Quality │ 1 (1 fuzz test name prefix) │
  ╰──────────────┴─────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - fuzz test name has correct prefix:
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
