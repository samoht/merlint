Two local packages: pkg-b uses pkg-a.helper but doesn't declare pkg-a
in its [depends:]. E941 flags it.

  $ merlint -B -r E941 bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E941] Missing runtime dependency (1 issue)
    When a library in your package's [(libraries L)] resolves to opam package P, P
    must appear in your package's [depends:]. Otherwise [opam install] from a
    fresh switch fails for downstream users -- your local build only works because
    P happens to be in the active switch. The fix depends on how you author opam
    metadata: if you hand-write [<pkg>.opam], add the package to its [depends:];
    if you let dune generate [<pkg>.opam] from [dune-project], add it to the
    [(package (depends ...))] stanza (use [<pkg>.opam.template] only for fields
    dune can't generate). Builtin libraries (unix, str, threads, ...), build-tool
    packages dune resolves separately (ocaml, dune, js_of_ocaml), [conf-*]
    system-library wrappers, and libraries owned by the package itself are exempt.
    - bad/pkg-b/pkg-b.opam:1:0: pkg-b uses library pkg-a.helper (from package pkg-a) via the (libraries ...) of pkg-b, but pkg-a is missing from pkg-b.opam's [depends:]. Add it.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────────────╮
  │ Category          │ Issues                           │
  ├───────────────────┼──────────────────────────────────┤
  │ Project Structure │ 1 (1 missing runtime dependency) │
  ╰───────────────────┴──────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Same setup, but pkg-b.opam now declares "pkg-a". No findings.

  $ merlint -B -r E941 good/
  Running merlint analysis...
  
  Analyzing 2 files
  
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
