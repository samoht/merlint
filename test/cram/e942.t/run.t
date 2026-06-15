Bad: a package that bans fmt but links it via (libraries ...) and depends: on it.
  $ (cd bad && dune build @check)
  $ merlint --build -r E942 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E942] Disallowed library dependency (1 issue)
    This package links or declares a dependency banned by the
    [disallowed_libraries] list in merlint.toml. Drop the dependency, or relax the
    ban. The list is empty by default; set it (e.g. [disallowed_libraries =
    ["fmt"]]) to enforce a build-level boundary, the companion to E221's
    source-level module ban.
    - bad/jsapp/jsapp.opam:1:0: jsapp depends on fmt, which is disallowed by disallowed_libraries in merlint.toml. Remove it from the package's (libraries ...) and [depends:].
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬─────────────────────────────────────╮
  │ Category          │ Issues                              │
  ├───────────────────┼─────────────────────────────────────┤
  │ Project Structure │ 1 (1 disallowed library dependency) │
  ╰───────────────────┴─────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E942` for the rule's description, hint, and good/bad examples.
  [1]

Good: the same package, formatting without fmt and not depending on it.
  $ (cd good && dune build @check)
  $ merlint --build -r E942 good/
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
