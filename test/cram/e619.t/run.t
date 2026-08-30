
Test bad example - the cases library defines a suite the runner never names.
test_list.ml declares its suites as a list rather than one (name, cases)
pair, the shape ocaml-hash/test/backend and ocaml-crypto/test/backend use;
the finding's location is the list element, not the enclosing let:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E619 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E619] Test Suite Never Run (2 issues)
    A test module in a library exports a 'suite' that no runner names. The alias
    over its directory then passes without running one of its cases, which reads
    exactly like a directory whose tests all pass. Name the suite in the runner
    that links the library, or delete the module.
    - bad/test/cases/test_list.ml:8:4: Test suite Test_list.suite is never run: nothing linking library e619_bad_cases references it
    - bad/test/cases/test_unused.ml:2:0: Test suite Test_unused.suite is never run: nothing linking library e619_bad_cases references it
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────╮
  │ Category     │ Issues                     │
  ├──────────────┼────────────────────────────┤
  │ Test Quality │ 2 (2 test suite never run) │
  ╰──────────────┴────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E619` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E619 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 4 files
  
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
