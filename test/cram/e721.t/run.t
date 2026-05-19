
Test bad example - fuzz/ nested inside test/:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E721 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E721] Misplaced Fuzz Directory (1 issue)
    Fuzz directories should be at the same level as test directories (siblings),
    not nested inside them. Move fuzz/ to be a sibling of test/.
    - bad/test/fuzz/dune:1:0: Fuzz directory 'bad/test/fuzz/' is nested inside a test directory - fuzz/ should be a sibling of test/, not nested inside it
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────╮
  │ Category     │ Issues                         │
  ├──────────────┼────────────────────────────────┤
  │ Test Quality │ 1 (1 misplaced fuzz directory) │
  ╰──────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E721` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - fuzz/ as sibling of test/:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E721 good/
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
