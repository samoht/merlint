
Test bad example - multiple fuzz stanzas in same directory:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E720 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E720] Multiple Fuzz Stanzas in Directory (1 issue)
    Each fuzz directory should have exactly one executable stanza with a single
    fuzz runner (fuzz.ml). Use (modules ...) to list all fuzz modules in a single
    stanza.
    - bad/fuzz/dune:1:0: Directory 'bad/fuzz/' has 2 fuzz stanzas (fuzz, fuzz_extra) - use a single fuzz runner per directory
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬──────────────────────────────────────────╮
  │ Category     │ Issues                                   │
  ├──────────────┼──────────────────────────────────────────┤
  │ Test Quality │ 1 (1 multiple fuzz stanzas in directory) │
  ╰──────────────┴──────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E720` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - single fuzz stanza:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E720 good/
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
