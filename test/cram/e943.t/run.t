Two local packages: pkg-b uses pkg-a.helper only from its [(test ...)]
stanza, but lists pkg-a in its runtime [depends:]. E943 flags it.

Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E943 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E943] Misclassified test / dev dependency (1 issue)
    A dep used only from [(test ...)] / [(tests ...)] or a runtest-attached
    private executable belongs in [:with-test]. A dep used only from a private
    executable that's not attached to [runtest] (generator, benchmark, dev tool)
    belongs in [:with-dev-setup]. Add the appropriate filter: in a hand-written
    [<pkg>.opam], wrap the entry as ["alcotest" {with-test}] or ["bench"
    {with-dev-setup}]; in a [dune-project] [(package (depends ...))] stanza, write
    [(alcotest :with-test)] or [(bench :with-dev-setup)]. Build-tool packages dune
    resolves separately (dune, dune-configurator, js_of_ocaml, ocaml) and [conf-*]
    system wrappers are exempt.
    - bad/pkg-b/pkg-b.opam:1:0: pkg-b.opam declares pkg-a in [depends:], but pkg-a is only reached through test-scope stanzas (tests or runtest-attached executables) (e.g. library pkg-a.helper). Move it under a [{with-test}] filter.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬───────────────────────────────────────────╮
  │ Category          │ Issues                                    │
  ├───────────────────┼───────────────────────────────────────────┤
  │ Project Structure │ 1 (1 misclassified test / dev dependency) │
  ╰───────────────────┴───────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E943` for the rule's description, hint, and good/bad examples.
  [1]

Same setup, but pkg-b.opam now declares pkg-a with {with-test}. No findings.

Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E943 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 3 files
  
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

