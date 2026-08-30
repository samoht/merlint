Test bad example - empty test suite. test_codec.ml declares a list of
suites whose second element is empty, so the finding points at that
element rather than at the let. The name in the message is still derived
from the file ('codec') and not from the element ('codec errors'):
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E621 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E621] Empty Test Suite (2 issues)
    An empty test suite provides no value. Tests should: (1) cover the module's
    public API with representative inputs, (2) exercise boundary conditions and
    edge cases, (3) verify error handling and invalid inputs, (4) document
    expected behaviour through concrete examples. A suite with no test cases will
    never catch regressions.
    - bad/test_codec.ml:9:4: Test suite 'codec' is empty — add meaningful tests covering the public API, edge cases, and error paths
    - bad/test_parser.ml:1:0: Test suite 'parser' is empty — add meaningful tests covering the public API, edge cases, and error paths
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────╮
  │ Category     │ Issues                 │
  ├──────────────┼────────────────────────┤
  │ Test Quality │ 2 (2 empty test suite) │
  ╰──────────────┴────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E621` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - non-empty test suite:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E621 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 1 files
  
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
