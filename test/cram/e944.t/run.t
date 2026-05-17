Optional sub-library uses must declare the known gating depopt.

Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E944 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E944] Optional sub-library missing depopt declaration (1 issue)
    When you use [X.suffix] from package X, X's installation might have skipped
    that sub-library because the system dep it gates wasn't available at X's build
    time. The gating dep is one of X's opam [depopts:]. Declare it in your own
    [depends:] so opam-install picks it up in a fresh switch. The (parent, sub)
    → depopt mapping lives in [merlint/lib/rules/e944.ml]'s [gating_table];
    extend it when you find a new case. Each entry is verified against X's actual
    depopts at run time; stale entries surface as findings too.
    - bad/pkg/pkg.opam:1:0: pkg uses optional sub-library fmt.tty but base-unix is missing from pkg.opam's [depends:]. Add "base-unix" — that's the depopt fmt declares to gate fmt.tty's installation (see File "merlint/lib/rules/e944.ml", line 44, characters 32-39).
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬───────────────────────────────────────────────────────╮
  │ Category          │ Issues                                                │
  ├───────────────────┼───────────────────────────────────────────────────────┤
  │ Project Structure │ 1 (1 optional sub-library missing depopt declaration) │
  ╰───────────────────┴───────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E944` for the rule's description, hint, and good/bad examples.
  [1]

Declaring the gate is accepted.

Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E944 good/
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
