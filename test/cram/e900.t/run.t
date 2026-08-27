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
    Add a c/ directory that projects the package's Wire codecs into a verified
    EverParse parser, the standard pattern across the CCSDS packages
    (ocaml-clcw/c, ocaml-pe/c, ...). Three wiring files: (1) gen.ml calls
    Wire_3d.main ~mode:`Standalone ~package:"<pkg>" [Wire_3d.pack
    <Module>.<codec>; ...], which emits a single <Name>.3d spec and C validator;
    (2) dune builds it -- (executable (name gen) (libraries <pkg> wire.3d)) plus
    (rule (alias 3d) (mode promote) (targets dune.inc) (action (run %{exe:gen.exe}
    dune))) and (include dune.inc); (3) the generated dune.inc and the C output
    (<Name>.3d, <Name>.c/.h, the <Name>Wrapper and EverParse runtime headers) are
    committed -- promoted to the source tree -- so an ordinary build compiles the
    checked-in C without EverParse. Regenerate after a codec change with
    BUILD_EVERPARSE=1 dune build @<pkg>/c/3d (the C-emitting rule is gated on that
    env var); it needs the EverParse 3d.exe on PATH (e.g. ~/.local/everparse/bin).
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
  ! 1 file is claimed by no dune stanza, so nothing compiles it and no rule examined it. Three ways that happens: no stanza names it (a [(modules ...)] spec may be excluding it); it no longer belongs in the tree; or a stanza does name it and merlint's project index could not read that stanza, which is a defect in merlint and not one of yours. Check which with [dune exec -- project-index stanzas -p <dir>] and [dune exec -- project-index libraries -p <dir>], where <dir> is the package directory a named file sits under: a stanza that is in the dune file and in neither listing is the third.
  ! $TESTCASE_ROOT/good/foo/c/gen.ml
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
  
  Summary: ✗ 0 total issues (applied 1 rule, 1 file unchecked)
  ✗ No issues found, but 1 file could not be checked, so some or all of the rules did not run on it. The warnings above name it and say why; -v names every one.
  [2]




Test unwired example - foo has a c/ directory with only gen.ml, missing the dune
and dune.inc that build it, so the EverParse projection never runs:
Build unwired fixture project:
  $ (cd unwired && dune build @check)

  $ merlint --build -r E900 unwired/
  Dune root: $TESTCASE_ROOT/unwired/
  ! 1 file is claimed by no dune stanza, so nothing compiles it and no rule examined it. Three ways that happens: no stanza names it (a [(modules ...)] spec may be excluding it); it no longer belongs in the tree; or a stanza does name it and merlint's project index could not read that stanza, which is a defect in merlint and not one of yours. Check which with [dune exec -- project-index stanzas -p <dir>] and [dune exec -- project-index libraries -p <dir>], where <dir> is the package directory a named file sits under: a stanza that is in the dune file and in neither listing is the third.
  ! $TESTCASE_ROOT/unwired/foo/c/gen.ml
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
    Add a c/ directory that projects the package's Wire codecs into a verified
    EverParse parser, the standard pattern across the CCSDS packages
    (ocaml-clcw/c, ocaml-pe/c, ...). Three wiring files: (1) gen.ml calls
    Wire_3d.main ~mode:`Standalone ~package:"<pkg>" [Wire_3d.pack
    <Module>.<codec>; ...], which emits a single <Name>.3d spec and C validator;
    (2) dune builds it -- (executable (name gen) (libraries <pkg> wire.3d)) plus
    (rule (alias 3d) (mode promote) (targets dune.inc) (action (run %{exe:gen.exe}
    dune))) and (include dune.inc); (3) the generated dune.inc and the C output
    (<Name>.3d, <Name>.c/.h, the <Name>Wrapper and EverParse runtime headers) are
    committed -- promoted to the source tree -- so an ordinary build compiles the
    checked-in C without EverParse. Regenerate after a codec change with
    BUILD_EVERPARSE=1 dune build @<pkg>/c/3d (the C-emitting rule is gated on that
    env var); it needs the EverParse 3d.exe on PATH (e.g. ~/.local/everparse/bin).
    - foo/c/dune:1:0: foo has a c/ directory but it is not wired into the build (missing dune, dune.inc), so the EverParse 3D generation never runs
  
  ╭─────────────────┬───────────────────────────────────────────────╮
  │ Category        │ Issues                                        │
  ├─────────────────┼───────────────────────────────────────────────┤
  │ Code Generation │ 1 (1 wire.codec without a wired c/ directory) │
  ╰─────────────────┴───────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule, 1 file unchecked)
  ✗ Some checks failed. See details above.
    Run `merlint help E900` for the rule's description, hint, and good/bad examples.
  [3]






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



