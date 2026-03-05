Test E607: Test Stanza Mixes Multiple Libraries

Test stanza with no deps mixing test files from multiple libraries:
  $ merlint -B -r E607 bad/
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
  
  ╭──────────────┬────────────────────────────────────────────╮
  │ Category     │ Issues                                     │
  ├──────────────┼────────────────────────────────────────────┤
  │ Test Quality │ 1 (1 test stanza mixes multiple libraries) │
  ╰──────────────┴────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

