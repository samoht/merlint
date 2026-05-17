Test bad example - foo.mli exposes Wire.struct_ symbol:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E905 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✗ Code Generation (1 total issues)
    [E905] Wire struct_/module_ in public API (1 issue)
    Move struct_, module_, c_stubs, ml_stubs out of the .mli. These belong in
    c/gen.ml where they are used to generate EverParse 3D files and C stubs. The
    codec is the public API; the 3D projection is a build artifact.
    - foo/foo.mli:1:0: foo/foo.mli exposes Wire EverParse symbol `struct_` in public API
  
  ╭─────────────────┬──────────────────────────────────────────╮
  │ Category        │ Issues                                   │
  ├─────────────────┼──────────────────────────────────────────┤
  │ Code Generation │ 1 (1 wire struct_/module_ in public api) │
  ╰─────────────────┴──────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E905` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - foo.mli keeps Wire EverParse symbols out of the public API:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E905 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 0 files
  
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
