
Test bad example - should find non-test file in test stanza:
  $ merlint -B -r E618 bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E618] Non-Test File in Test Stanza (1 issue)
    All .ml files in a test stanza should follow the test_ naming convention
    (e.g., test_parser.ml) or be the test runner (test.ml). Files like helpers.ml
    or utils.ml should be renamed to test_helpers.ml or test_utils.ml.
    - bad/test/helpers.ml:1:0: File 'helpers.ml' in test stanza 'test' does not follow the test_ naming convention - rename to test_helpers.ml
  
  ╭──────────────┬────────────────────────────────────╮
  │ Category     │ Issues                             │
  ├──────────────┼────────────────────────────────────┤
  │ Test Quality │ 1 (1 non-test file in test stanza) │
  ╰──────────────┴────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]






Test good example - should find no issues:
  $ merlint -B -r E618 good/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!



