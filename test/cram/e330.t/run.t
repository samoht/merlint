Test bad example - should find redundant module name:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E330 bad/process.ml
  Dune root: $TESTCASE_ROOT/bad
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (3 total issues)
    [E330] Redundant Module Name (3 issues)
    Avoid prefixing type or function names with the module name. The module
    already provides the namespace, so Message.message_type should just be
    Message.t. Exception: Pp.pp is idiomatic for pretty-printing modules.
    - bad/process.ml:2:0: Function 'process_start' has redundant module prefix from Process
    - bad/process.ml:3:0: Function 'process_stop' has redundant module prefix from Process
    - bad/process.ml:4:0: Type 'process_config' has redundant module prefix from Process
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬─────────────────────────────╮
  │ Category           │ Issues                      │
  ├────────────────────┼─────────────────────────────┤
  │ Naming Conventions │ 3 (3 redundant module name) │
  ╰────────────────────┴─────────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E330` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E330 good/process.ml
  Dune root: $TESTCASE_ROOT/good
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

Test pp module - pp function should be allowed:
  $ merlint -B -r E330 good/pp.ml
  Dune root: $TESTCASE_ROOT/good
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

Test test functions - test_* functions in test_*.ml files should be allowed:
  $ merlint -B -r E330 good/test_example.ml
  Dune root: $TESTCASE_ROOT/good
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
