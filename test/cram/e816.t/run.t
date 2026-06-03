Test bad example - generate.sh hardcodes ../traces, ignoring its $1 arg:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E816 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E816] generate.sh ignores output-dir argument (1 issue)
    scripts/generate.sh must take the output directory as its first argument, e.g.
    `TRACE_DIR="$(cd "${1:-$SCRIPT_DIR/../traces}" && pwd)"`. The traces/dune
    regen rule runs it with the build trace dir as $1; a script that hardcodes
    ../traces writes to the wrong place.
    - bad/foo/test/interop/oracle/scripts/generate.sh:1:0: bad/foo/test/interop/oracle/scripts/generate.sh ignores its output-dir argument ($1)
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬───────────────────────────────────────────────╮
  │ Category        │ Issues                                        │
  ├─────────────────┼───────────────────────────────────────────────┤
  │ Interop Testing │ 1 (1 generate.sh ignores output-dir argument) │
  ╰─────────────────┴───────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E816` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - generate.sh takes the output dir as $1:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E816 good/
  Dune root: $TESTCASE_ROOT/good/
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
