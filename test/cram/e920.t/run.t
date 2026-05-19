Bad: README.md and lib/foo.mli have OCaml code blocks but no mdx stanza references them.

Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E920 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (2 total issues)
    [E920] Untested OCaml code in documentation (2 issues)
    When a README.md, .mli or .mld contains OCaml code examples, add an (mdx
    (files <file>)) stanza to the owning dune file so the snippets are
    type-checked and run during dune test.
    - bad/README.md:1:0: bad/README.md: contains OCaml code blocks but bad/dune has no (mdx ...) stanza
    - bad/lib/foo.mli:1:0: bad/lib/foo.mli: contains OCaml code blocks but bad/lib/dune has no (mdx ...) stanza
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬────────────────────────────────────────────╮
  │ Category      │ Issues                                     │
  ├───────────────┼────────────────────────────────────────────┤
  │ Documentation │ 2 (2 untested ocaml code in documentation) │
  ╰───────────────┴────────────────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E920` for the rule's description, hint, and good/bad examples.
  [1]






Good: every doc file with OCaml code is referenced by an mdx stanza.

Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E920 good/
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

