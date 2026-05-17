Test bad example - package uses src/ instead of lib/:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E520 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E520] Library directory should be lib/, not src/ (1 issue)
    The monorepo convention is lib/ for library code. Rename src/ to lib/ with
    `git mv`; no dune changes are needed because dune auto-discovers modules in
    either directory.
    - pkg/dune-project:1:0: pkg uses src/ for its library; rename to lib/ to match the monorepo convention
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────────────────────────────╮
  │ Category          │ Issues                                           │
  ├───────────────────┼──────────────────────────────────────────────────┤
  │ Project Structure │ 1 (1 library directory should be lib/, not src/) │
  ╰───────────────────┴──────────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E520` for the rule's description, hint, and good/bad examples.
  [1]






Test good example - package uses lib/:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E520 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 0 files
  
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



