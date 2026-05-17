Test bad example - main.ml defines two Cmd.v subcommands:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E524 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E524] Multiple Cmdliner subcommands in one file (1 issue)
    Each Cmd.v subcommand should live in its own file. Move each Cmd.v into a
    sibling file (e.g. cmd_<name>.ml exposing a single val cmd) and reference it
    from main.ml's Cmd.group. Sub-subcommands of a grouped subcommand follow the
    same rule — use cmd_<parent>/<leaf>.ml or cmd_<parent>_<leaf>.ml siblings.
    - bad/main.ml:1:0: defines 2 Cmdliner subcommands in one file; split them into one file per subcommand
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬─────────────────────────────────────────────────╮
  │ Category          │ Issues                                          │
  ├───────────────────┼─────────────────────────────────────────────────┤
  │ Project Structure │ 1 (1 multiple cmdliner subcommands in one file) │
  ╰───────────────────┴─────────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E524` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - main.ml defines a single Cmd.v subcommand:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E524 good/
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
