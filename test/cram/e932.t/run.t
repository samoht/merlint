Test bad example - protocol package missing ocaml-probe:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E932 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E932] Protocol probe dependency (1 issue)
    Every package tagged [protocol] must depend on [ocaml-probe]. Protocol
    libraries should declare a closed [Event.t] vocabulary and expose
    [Event.emit_probe] so adapters can publish typed Runtime_events probes without
    owning an in-process subscription API.
    - bad/pkg/pkg.opam:1:0: pkg is tagged [protocol] but does not depend on ocaml-probe
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬─────────────────────────────────╮
  │ Category          │ Issues                          │
  ├───────────────────┼─────────────────────────────────┤
  │ Project Structure │ 1 (1 protocol probe dependency) │
  ╰───────────────────┴─────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E932` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - protocol package depends on ocaml-probe:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E932 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
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
