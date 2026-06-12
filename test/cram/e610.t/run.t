Test bad example - should find test without library:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E610 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E610] Test Without Library (2 issues)
    Every test module should have a corresponding library module. This ensures
    that tests are testing actual library functionality rather than testing code
    that doesn't exist in the library.
    - bad/test/test_old_feature.ml:1:0: Test file exists but corresponding library module 'old_feature.ml' not found
    - bad/test/test_runner.ml:1:0: Test file exists but corresponding library module 'runner.ml' not found
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────╮
  │ Category     │ Issues                     │
  ├──────────────┼────────────────────────────┤
  │ Test Quality │ 2 (2 test without library) │
  ╰──────────────┴────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E610` for the rule's description, hint, and good/bad examples.
  [1]

Test good example with library subdirectories - test files match library modules in subdirs:
Build good fixture project:
  $ (cd good-subdir && dune build @check)

  $ merlint --build -r E610 good-subdir/
  Dune root: $TESTCASE_ROOT/good-subdir/
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

Test good example - all test files have corresponding library modules:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E610 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 6 files
  
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

A sub-library's test executable needs its own deps, so it lives in a test/
subdirectory (e.g. test/eio/test_store_eio.ml). The flat library module it
exercises (lib/store_eio.ml) still counts as its corresponding module even
though the test sits one directory deeper than the library source.

Build good-sublib fixture project:
  $ (cd good-sublib && dune build @check)

  $ merlint --build -r E610 good-sublib/
  Dune root: $TESTCASE_ROOT/good-sublib/
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

Generated modules count as library modules: lexer.mll (ocamllex) and parser.mly
(ocamlyacc/menhir) produce lexer/parser modules at build time, so test_lexer.ml
and test_parser.ml have corresponding library modules even though no lexer.ml or
parser.ml exists in the source tree.

Build good-generated fixture project:
  $ (cd good-generated && dune build @check)

  $ merlint --build -r E610 good-generated/
  Dune root: $TESTCASE_ROOT/good-generated/
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
