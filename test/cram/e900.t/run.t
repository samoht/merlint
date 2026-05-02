Test bad example - foo uses Wire.Codec but has no c/ directory:
  $ merlint -B -r E900 bad/
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
    [E900] Wire.Codec without c/ directory (1 issue)
    Add a c/ directory with gen.ml that calls Wire_3d.main to generate .3d files
    and C validators from the Wire codec definitions. See ocaml-clcw/c/ for the
    pattern.
    - foo/dune-project:1:0: foo uses Wire.Codec but has no c/ directory for EverParse 3D generation
  
  ╭─────────────────┬───────────────────────────────────────╮
  │ Category        │ Issues                                │
  ├─────────────────┼───────────────────────────────────────┤
  │ Code Generation │ 1 (1 wire.codec without c/ directory) │
  ╰─────────────────┴───────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - foo uses Wire.Codec and has a c/ directory:
  $ merlint -B -r E900 good/
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
