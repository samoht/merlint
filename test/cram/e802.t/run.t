Test bad example - foo/test/interop/oracle/ has no traces/ dir:
  $ merlint -B -r E802 bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E802] Interop test not replay-only (1 issue)
    Traces must be committed to git. The test stanza must depend on (source_tree
    traces) so tests run from traces alone — the external tool is NOT required
    at test time. This is the 'generate once, replay always' principle.
    - (global) Interop test bad/foo/test/interop/oracle: missing traces/ directory — traces must be committed
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬────────────────────────────────────╮
  │ Category        │ Issues                             │
  ├─────────────────┼────────────────────────────────────┤
  │ Interop Testing │ 1 (1 interop test not replay-only) │
  ╰─────────────────┴────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - foo/test/interop/oracle/ has traces/ and dune (source_tree traces):
  $ merlint -B -r E802 good/
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
