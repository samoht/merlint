Two local packages: pkg-b uses pkg-a.helper but doesn't declare pkg-a
in its [depends:]. E941 flags it.

Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E941 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E941] Missing runtime dependency (1 issue)
    When a library in your package's [(libraries L)] resolves to opam package P, P
    must appear in your package's [depends:]. This includes libraries linked by
    public executables, since [opam install] builds those through [@install].
    Otherwise [opam install] from a fresh switch fails for downstream users --
    your local build only works because P happens to be in the active switch. The
    fix depends on how you author opam metadata: if you hand-write [<pkg>.opam],
    add the package to its [depends:]; if you let dune generate [<pkg>.opam] from
    [dune-project], add it to the [(package (depends ...))] stanza (use
    [<pkg>.opam.template] only for fields dune can't generate). Builtin libraries
    (unix, str, threads, ...), build-tool packages dune resolves separately
    (ocaml, dune, js_of_ocaml), [conf-*] system-library wrappers, and libraries
    owned by the package itself are exempt.
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
    Run `merlint help E941` for the rule's description, hint, and good/bad examples.
  [1]

Same setup, but pkg-b.opam now declares "pkg-a". No findings.

Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E941 good/
  Dune root: $TESTCASE_ROOT/good/
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

Public executables are install targets too: pkg-b installs an executable that
links pkg-a.helper, so pkg-b still needs a runtime dependency on pkg-a.

Build bad executable fixture project:
  $ (cd bad-exe && dune build @check)

  $ merlint --build -r E941 bad-exe/
  Dune root: $TESTCASE_ROOT/bad-exe/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E941] Missing runtime dependency (1 issue)
    When a library in your package's [(libraries L)] resolves to opam package P, P
    must appear in your package's [depends:]. This includes libraries linked by
    public executables, since [opam install] builds those through [@install].
    Otherwise [opam install] from a fresh switch fails for downstream users --
    your local build only works because P happens to be in the active switch. The
    fix depends on how you author opam metadata: if you hand-write [<pkg>.opam],
    add the package to its [depends:]; if you let dune generate [<pkg>.opam] from
    [dune-project], add it to the [(package (depends ...))] stanza (use
    [<pkg>.opam.template] only for fields dune can't generate). Builtin libraries
    (unix, str, threads, ...), build-tool packages dune resolves separately
    (ocaml, dune, js_of_ocaml), [conf-*] system-library wrappers, and libraries
    owned by the package itself are exempt.
    - bad-exe/pkg-b/pkg-b.opam:1:0: pkg-b uses library pkg-a.helper (from package pkg-a) via the (libraries ...) of a public executable, but pkg-a is missing from pkg-b.opam's [depends:]. Add it.
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
    Run `merlint help E941` for the rule's description, hint, and good/bad examples.
  [1]

Build good executable fixture project:
  $ (cd good-exe && dune build @check)

  $ merlint --build -r E941 good-exe/
  Dune root: $TESTCASE_ROOT/good-exe/
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

Private benches are not install targets. pkg-b has a private bench library that
links pkg-a.helper, used only by a private executable -- nothing public depends
on it, so it is not install-reachable. [opam install pkg-b] never builds it, so
pkg-a belongs in {with-test}, not [depends:]. E941 stays silent even though
pkg-b.opam does not depend on pkg-a.

Build good bench fixture project:
  $ (cd good-bench && dune build @check)

  $ merlint --build -r E941 good-bench/
  Dune root: $TESTCASE_ROOT/good-bench/
  Running merlint analysis...
  
  Analyzing 4 files
  
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

E941 answers by resolving a library name to the package that provides it,
and this run's index resolves only the packages it scanned. A run narrowed
to one directory leaves the provider unscanned, and the same lookup then
answers "nothing provides it" -- which is what a correctly declared
dependency also looks like. The fixture is the monorepo shape: sibling
packages, each its own dune project, under one workspace root.

Pointed at the whole workspace, the index holds pkg-a and the rule decides:

  $ merlint -r E941 unscanned/
  Dune root: $TESTCASE_ROOT/unscanned/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E941] Missing runtime dependency (1 issue)
    When a library in your package's [(libraries L)] resolves to opam package P, P
    must appear in your package's [depends:]. This includes libraries linked by
    public executables, since [opam install] builds those through [@install].
    Otherwise [opam install] from a fresh switch fails for downstream users --
    your local build only works because P happens to be in the active switch. The
    fix depends on how you author opam metadata: if you hand-write [<pkg>.opam],
    add the package to its [depends:]; if you let dune generate [<pkg>.opam] from
    [dune-project], add it to the [(package (depends ...))] stanza (use
    [<pkg>.opam.template] only for fields dune can't generate). Builtin libraries
    (unix, str, threads, ...), build-tool packages dune resolves separately
    (ocaml, dune, js_of_ocaml), [conf-*] system-library wrappers, and libraries
    owned by the package itself are exempt.
    - unscanned/pkg-b/pkg-b.opam:1:0: pkg-b uses library pkg-a.helper (from package pkg-a) via the (libraries ...) of pkg-b, but pkg-a is missing from pkg-b.opam's [depends:]. Add it.
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
    Run `merlint help E941` for the rule's description, hint, and good/bad examples.
  [1]

Pointed at pkg-b alone, pkg-a is never scanned and the rule cannot decide. The
summary counts the rule it could not check, and the run exits 2 -- where before
it printed the clean summary of a complete run and exited 0. A caller's gate
rests on that status, so the [2] below is asserted with the text: a change that
returns 0 under this same summary turns this test red.

  $ merlint -r E941 unscanned/pkg-b
  Dune root: $TESTCASE_ROOT/unscanned
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
  
  Summary: ✗ 0 total issues (applied 1 rule, 1 rule not checked)
  [2]

E941 could not resolve two names, and the summary counts one rule. A rule that
cannot resolve forty names is still one rule this run did not check, and
counting the names would read as forty rules. The count is all the text report
says; [--json] carries a [failed_checks] member per name, each naming the rule
and what it could not resolve.
