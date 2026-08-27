Test bad example - missing fuzz .mli file:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E705 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E705] Missing Fuzz MLI File (1 issue)
    Fuzz modules (fuzz_*.ml) should have corresponding .mli files that export only
    'suite : string * Alcobar.test_case list'. This enforces proper encapsulation
    of fuzz test internals.
    - bad/fuzz/fuzz_parser.ml:1:0: Fuzz module bad/fuzz/fuzz_parser.ml is missing interface file bad/fuzz/fuzz_parser.mli
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬─────────────────────────────╮
  │ Category     │ Issues                      │
  ├──────────────┼─────────────────────────────┤
  │ Test Quality │ 1 (1 missing fuzz mli file) │
  ╰──────────────┴─────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E705` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - fuzz .mli file present with correct type:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E705 good/
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

A correct fuzz interface must not be reported just because its .cmti was
never built. Without a typedtree the expected type cannot be resolved, and a
rule that reads that as "does not match" turns every compliant fuzz module in
a stale tree into a finding. Same sources as good/, never built -- so the first
pass has no typedtree to read, merlint builds the directory holding the file,
and the rule answers on the artefact rather than on the absence of one:

  $ merlint -r E705 unbuilt/
  Dune root: $TESTCASE_ROOT/unbuilt/
  ! 1 file has no typedtree: no build artefact describes it and the build system names no stanza that compiles it, so nothing says what to type it against and the rules that read a typedtree were skipped.
  ! $TESTCASE_ROOT/unbuilt/fuzz/fuzz_parser.mli
  Building the file above, then analysing it again.
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

An interface that exports more than the suite is still reported, so the clean
run above cannot be mistaken for the rule going quiet altogether:

  $ (cd bad_type && dune build @check)

  $ merlint --build -r E705 bad_type/
  Dune root: $TESTCASE_ROOT/bad_type/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E705] Missing Fuzz MLI File (1 issue)
    Fuzz modules (fuzz_*.ml) should have corresponding .mli files that export only
    'suite : string * Alcobar.test_case list'. This enforces proper encapsulation
    of fuzz test internals.
    - bad_type/fuzz/fuzz_parser.mli:1:0: Fuzz module interface should only export 'suite' with type string * Alcobar.test_case list
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬─────────────────────────────╮
  │ Category     │ Issues                      │
  ├──────────────┼─────────────────────────────┤
  │ Test Quality │ 1 (1 missing fuzz mli file) │
  ╰──────────────┴─────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E705` for the rule's description, hint, and good/bad examples.
  [1]
