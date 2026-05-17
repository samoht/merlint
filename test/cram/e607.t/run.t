Test E607: Test Stanza Mixes Multiple Libraries

Test stanza with no deps mixing test files from multiple libraries:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E607 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 5 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E607] Test Stanza Mixes Multiple Libraries (1 issue)
    Test stanzas without declared library dependencies should not contain test
    files for multiple different libraries. Split tests into separate test
    stanzas, one per library.
    - bad/test/test_feed.ml:1:0: Test file 'test_feed.ml' tests library 'views_lib' but test stanza has no declared dependencies and mixes multiple libraries
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────────────────╮
  │ Category     │ Issues                                     │
  ├──────────────┼────────────────────────────────────────────┤
  │ Test Quality │ 1 (1 test stanza mixes multiple libraries) │
  ╰──────────────┴────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E607` for the rule's description, hint, and good/bad examples.
  [1]

Test stanza with files from only one library (no issue):
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E607 good/
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



