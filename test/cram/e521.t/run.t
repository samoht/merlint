Test bad example - cram test at test/ rather than test/cram/:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E521 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E521] Cram test outside test/cram/ (1 issue)
    Move cram tests (.t files or .t/ directories) under the package's test/cram/
    umbrella. Shared driver exes go in test/cram/helpers/; shell setup goes in
    test/cram/helpers.sh (sourced via (setup_scripts helpers.sh)).
    - pkg/test/foo.t:1:0: pkg/test/foo.t should live under pkg/test/cram/
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────────╮
  │ Category          │ Issues                             │
  ├───────────────────┼────────────────────────────────────┤
  │ Project Structure │ 1 (1 cram test outside test/cram/) │
  ╰───────────────────┴────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E521` for the rule's description, hint, and good/bad examples.
  [1]






Test good example - cram test under test/cram/:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E521 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
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



