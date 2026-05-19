Test bad example - fuzz_parser not included in fuzz.ml:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E715 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E715] Fuzz Module Not Included (1 issue)
    All fuzz modules should be included in the fuzz runner (fuzz.ml) via
    Fuzz_*.suite references. This ensures all fuzz tests are actually executed.
    - bad/fuzz/fuzz.ml:1:0: Fuzz module fuzz_parser is not included in bad/fuzz/fuzz.ml
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────╮
  │ Category     │ Issues                         │
  ├──────────────┼────────────────────────────────┤
  │ Test Quality │ 1 (1 fuzz module not included) │
  ╰──────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E715` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - all fuzz modules included:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E715 good/
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
