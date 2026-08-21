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

A test in a non-mirroring directory (an imported [legacy/] suite) whose
module lives in a library subdirectory still has a real library module
behind it, so E610 must not fire:
Build good-legacy fixture project:
  $ (cd good-legacy && dune build @check)

  $ merlint --build -r E610 good-legacy/
  Dune root: $TESTCASE_ROOT/good-legacy/
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

A module defined inside another compilation unit has no source file, so the
only evidence it exists is a reference in a library typedtree. Built, the
reference to Mylib.Gadget.Control is there and the rule is silent:

Build stale fixture project:
  $ (cd stale && dune build @check)

  $ merlint -r E610 stale/
  Dune root: $TESTCASE_ROOT/stale/
  Running merlint analysis...
  
  Analyzing 2 files
  
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

Edit the library source and its .cmt no longer describes it. The artefact is
refused, the source is typechecked in its place, and the reference to
Mylib.Gadget.Control is read off that tree instead -- so the rule has evidence
the module exists and stays silent, with nothing to hedge about:

  $ chmod +w stale/lib/gadget.ml
  $ printf '\n(* A comment the .cmt predates. *)\n' >> stale/lib/gadget.ml

  $ merlint -r E610 stale/
  Dune root: $TESTCASE_ROOT/stale/
  Running merlint analysis...
  
  Analyzing 2 files
  
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

A successful Dune process is not evidence that a proven-stale generated file
changed: the shared cache can restore the same CMT. This adapter models that
successful no-op while the stale target exists, then delegates to real Dune
once merlint invalidates it. [--build] must leave a current typedtree:

  $ chmod +x fake-bin/dune
  $ stale_cmt=$(find stale/_build/default -name 'mylib__Gadget.cmt'); real_dune=$(command -v dune); PATH="$PWD/fake-bin:$PATH" STALE_CMT="$PWD/$stale_cmt" REAL_DUNE="$real_dune" merlint --build -r E610 stale/ >merlint-refresh.out 2>&1
  $ cat merlint-refresh.out
  Dune root: $TESTCASE_ROOT/stale/
  Running merlint analysis...
  
  Analyzing 2 files
  
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
