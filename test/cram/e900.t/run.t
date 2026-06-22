Test bad example - foo uses Wire.Codec but has no c/ directory:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E900 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✗ Code Generation (1 total issues)
    [E900] Wire.Codec without a wired c/ directory (1 issue)
    Add a c/ directory whose gen.ml calls Wire_3d.main ~mode:`Doc to project the
    Wire codecs into a single <Name>.3d EverParse spec and validator, and wire it
    into the build with a dune that compiles gen and includes the generated
    dune.inc. See ocaml-clcw/c/ for the pattern.
    - foo/dune-project:1:0: foo uses Wire.Codec but has no c/ directory for EverParse 3D generation
  
  ╭─────────────────┬───────────────────────────────────────────────╮
  │ Category        │ Issues                                        │
  ├─────────────────┼───────────────────────────────────────────────┤
  │ Code Generation │ 1 (1 wire.codec without a wired c/ directory) │
  ╰─────────────────┴───────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E900` for the rule's description, hint, and good/bad examples.
  [1]






Test good example - foo uses Wire.Codec and has a c/ directory:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E900 good/
  Dune root: $TESTCASE_ROOT/good/
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




Test unwired example - foo has a c/ directory with only gen.ml, missing the dune
and dune.inc that build it, so the EverParse projection never runs:
Build unwired fixture project:
  $ (cd unwired && dune build @check)

  $ merlint --build -r E900 unwired/
  Dune root: $TESTCASE_ROOT/unwired/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✗ Code Generation (1 total issues)
    [E900] Wire.Codec without a wired c/ directory (1 issue)
    Add a c/ directory whose gen.ml calls Wire_3d.main ~mode:`Doc to project the
    Wire codecs into a single <Name>.3d EverParse spec and validator, and wire it
    into the build with a dune that compiles gen and includes the generated
    dune.inc. See ocaml-clcw/c/ for the pattern.
    - foo/c/dune:1:0: foo has a c/ directory but it is not wired into the build (missing dune, dune.inc), so the EverParse 3D generation never runs
  
  ╭─────────────────┬───────────────────────────────────────────────╮
  │ Category        │ Issues                                        │
  ├─────────────────┼───────────────────────────────────────────────┤
  │ Code Generation │ 1 (1 wire.codec without a wired c/ directory) │
  ╰─────────────────┴───────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E900` for the rule's description, hint, and good/bad examples.
  [1]






Test no-Wire edge case - plain Codec.v is not Wire.Codec.v and needs no c/ directory:
Build nowire fixture project:
  $ (cd nowire && dune build @check)

  $ merlint --build -r E900 nowire/
  Dune root: $TESTCASE_ROOT/nowire/
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




Test provider edge case - the wire package itself defines Wire.Codec and does
not need a consumer c/ directory:
  $ (cd self && dune build @check)

  $ merlint --build -r E900 self/
  Dune root: $TESTCASE_ROOT/self/
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



