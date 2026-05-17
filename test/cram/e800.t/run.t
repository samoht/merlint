Test bad example - foo/test/interop/oracle/scripts/ exists but no generate.sh:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E800 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E800] Missing generate.sh (1 issue)
    Every interop test must have scripts/generate.sh as the single entry point for
    trace regeneration via `dune build @regen-traces`.
    - bad/foo/test/interop/oracle/scripts/generate.sh:1:0: Interop test bad/foo/test/interop/oracle/scripts/ is missing generate.sh
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬───────────────────────────╮
  │ Category        │ Issues                    │
  ├─────────────────┼───────────────────────────┤
  │ Interop Testing │ 1 (1 missing generate.sh) │
  ╰─────────────────┴───────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E800` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - foo/test/interop/oracle/scripts/generate.sh exists:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E800 good/
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
