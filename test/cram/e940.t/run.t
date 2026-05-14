Bad fixture: dune file present but missing the %{dune-warnings} stanza.

  $ merlint -B -r E940 bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E940] Dune warnings flag (1 issue)
    Every project (or subtree) should enable [%{dune-warnings}] on the dev profile
    so warnings are uniform across builds. Add the stanza [(env (dev (flags
    :standard %{dune-warnings})))] to the top-level [dune] file. Note
    [%{dune-warnings}] requires [(lang dune 3.21)] or newer in the corresponding
    [dune-project].
    - bad/dune:1:0: bad/dune does not enable %{dune-warnings}; add [(env (dev (flags :standard %{dune-warnings})))] so standalone opam builds fail on warnings
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────╮
  │ Category          │ Issues                   │
  ├───────────────────┼──────────────────────────┤
  │ Project Structure │ 1 (1 dune warnings flag) │
  ╰───────────────────┴──────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Good fixture: dune file enables %{dune-warnings} on dev.

  $ merlint -B -r E940 good/
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
