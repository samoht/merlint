Build fixture project:
  $ dune build @check

Test bad example - should find missing value documentation:
  $ merlint -B -r E405 bad.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (2 total issues)
    [E405] Missing Value Documentation (2 issues)
    All public values should have documentation explaining their purpose and
    usage. Add doc comments (** ... *) before or after value declarations in .mli
    files.
    - bad.mli:2:0: Public value 'parse' is missing documentation
    - bad.mli:7:0: Public value 'missing_documentation' is missing documentation
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬───────────────────────────────────╮
  │ Category      │ Issues                            │
  ├───────────────┼───────────────────────────────────┤
  │ Documentation │ 2 (2 missing value documentation) │
  ╰───────────────┴───────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E405` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E405 good.mli
  Dune root: $TESTCASE_ROOT/
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
