Test bad example - sans-IO library reads the wall clock:
  $ merlint -B -r E931 bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E931] Ambient clock in sans-IO library code (1 issue)
    Sans-IO packages (tagged [codec.*] or [protocol]) must not read the wall clock
    or monotonic clock from library code. Time is an input, not a side effect:
    take [~now] as a parameter, let the caller's adapter or CLI [bin/] call
    [Mtime_clock.now] / [Ptime_clock.now] / [Unix.gettimeofday] / [Sys.time] and
    pass the value in. Library attribution follows dune's [(public_name P.X)] via
    [Project_index] so a sibling adapter package is scanned against its own tags,
    not its sans-IO sister's.
    - bad/pkg/pkg.opam:1:0: pkg: ambient clock in sans-IO lib code: bad/pkg/lib/pkg.ml:1:19 ambient clock [Unix.gettimeofday] in lib code: take [~now] as a parameter; the caller's adapter is the right place to read the wall clock
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬─────────────────────────────────────────────╮
  │ Category          │ Issues                                      │
  ├───────────────────┼─────────────────────────────────────────────┤
  │ Project Structure │ 1 (1 ambient clock in sans-io library code) │
  ╰───────────────────┴─────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - sans-IO library takes time as input:
  $ merlint -B -r E931 good/
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
