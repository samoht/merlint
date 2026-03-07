
Test bad example - should find multiple test stanzas:
  $ merlint -B -r E620 bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E620] Multiple Test Stanzas in Directory (1 issue)
    Each test directory should have exactly one test stanza with a single test
    runner (test.ml). Multiple test stanzas in the same directory cause module
    ownership conflicts and break @check builds.
    - bad/test/dune:1:0: Directory 'bad/test/' has 2 test stanzas (test, test_extra) - use a single test runner per directory
  
  ╭──────────────┬──────────────────────────────────────────╮
  │ Category     │ Issues                                   │
  ├──────────────┼──────────────────────────────────────────┤
  │ Test Quality │ 1 (1 multiple test stanzas in directory) │
  ╰──────────────┴──────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E620 good/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
