Test bad example - dune uses REGEN_TRACES env sentinel:
  $ merlint -B -r E815 bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E815] REGEN_TRACES sentinel in dune (1 issue)
    The regen-traces alias should be the single entry point — no REGEN_TRACES=1
    env var sentinel. Remove the (enabled_if ...) guard so `dune build
    @regen-traces` works directly.
    - bad/foo/test/interop/oracle/dune:1:0: Interop test bad/foo/test/interop/oracle/dune uses REGEN_TRACES sentinel
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬─────────────────────────────────────╮
  │ Category        │ Issues                              │
  ├─────────────────┼─────────────────────────────────────┤
  │ Interop Testing │ 1 (1 regen_traces sentinel in dune) │
  ╰─────────────────┴─────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - dune has plain regen-traces alias without sentinel:
  $ merlint -B -r E815 good/
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
