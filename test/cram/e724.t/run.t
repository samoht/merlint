
Test bad example - fuzz directory missing build rules:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E724 bad/
  Dune root: $TESTCASE_ROOT/bad/
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
    testing during dune test, and (rule (alias fuzz) ...) using fuzz.exe
    --gen-corpus for AFL fuzzing campaigns.
    - bad/fuzz/dune:1:0: Fuzz directory 'bad/fuzz/' is missing both (rule (alias runtest) ...) and (rule (alias fuzz) ...) build rules
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────╮
  │ Category     │ Issues                         │
  ├──────────────┼────────────────────────────────┤
  │ Test Quality │ 1 (1 missing fuzz build rules) │
  ╰──────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E724` for the rule's description, hint, and good/bad examples.
  [1]






Test good example - fuzz directory with all required build rules:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E724 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 2 files
  
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



