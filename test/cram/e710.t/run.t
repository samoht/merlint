Test bad example - fuzz_missing.ml has no corresponding library module:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E710 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E710] Fuzz Without Library (1 issue)
    Every fuzz module (fuzz_<module>.ml) should have a corresponding library
    module (<module>.ml). This ensures fuzz tests are testing actual library
    functionality.
    - bad/fuzz/fuzz_missing.ml:1:0: Fuzz file exists but corresponding library module 'missing' not found
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────╮
  │ Category     │ Issues                     │
  ├──────────────┼────────────────────────────┤
  │ Test Quality │ 1 (1 fuzz without library) │
  ╰──────────────┴────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E710` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - fuzz_parser.ml has corresponding parser.ml:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E710 good/
  Dune root: $TESTCASE_ROOT/good/
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
