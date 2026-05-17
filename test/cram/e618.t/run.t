
Test bad example - should find non-test file in test stanza:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E618 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E618] Non-Test File in Test Stanza (1 issue)
    All .ml files in a test/ directory should follow the test_ naming convention
    (e.g., test_parser.ml) or be the test runner (test.ml). Non-test modules
    should either be extracted into a private (library ...) stanza or renamed to
    test_<module>.ml.
    - bad/test/helpers.ml:1:0: File 'helpers.ml' in test stanza 'test' does not follow the test_ naming convention - extract into a private (library ...) stanza or rename to test_helpers.ml
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────────╮
  │ Category     │ Issues                             │
  ├──────────────┼────────────────────────────────────┤
  │ Test Quality │ 1 (1 non-test file in test stanza) │
  ╰──────────────┴────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E618` for the rule's description, hint, and good/bad examples.
  [1]






Test good example - should find no issues:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E618 good/
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



