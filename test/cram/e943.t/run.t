Two local packages: pkg-b uses pkg-a.helper only from its [(test ...)]
stanza, but lists pkg-a in its runtime [depends:]. E943 flags it.

  $ merlint -B -r E943 bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E943] Misclassified test-only dependency (1 issue)
    A dep that's used only from [(test ...)] / [(tests ...)] stanzas or a private
    [(executable ...)] (no [public_name]) belongs in [:with-test], not in the
    runtime [depends:]. Add a [{with-test}] filter: in a hand-written
    [<pkg>.opam], wrap the entry as ["alcotest" {with-test}]; in a [dune-project]
    [(package (depends ...))] stanza, write [(alcotest :with-test)]. Downstream
    users who [opam install <pkg>] will then skip the test framework. Build-tool
    packages dune resolves separately and [conf-*] system wrappers are exempt.
    - bad/pkg-b/pkg-b.opam:1:0: pkg-b.opam declares pkg-a in [depends:], but pkg-a is only reached through test-scope stanzas (e.g. library pkg-a.helper). Move it under a [{with-test}] filter.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────────────────────╮
  │ Category          │ Issues                                   │
  ├───────────────────┼──────────────────────────────────────────┤
  │ Project Structure │ 1 (1 misclassified test-only dependency) │
  ╰───────────────────┴──────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Same setup, but pkg-b.opam now declares pkg-a with {with-test}. No findings.

  $ merlint -B -r E943 good/
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

