Bad examples: a single-stanza dune with an explicit (modules ...) is
redundant, and two sibling stanzas that don't cover every .ml in the
directory silently drop files from the build:

Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E523 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E523] Redundant or incomplete (modules ...) in dune (2 issues)
    A dune file with a single library/executable/test stanza doesn't need (modules
    ...) — dune auto-discovers every .ml in the directory. When multiple stanzas
    share a directory the (modules ...) fields must together cover every .ml file,
    otherwise some module is silently dropped. Prefer splitting into sibling
    directories when the stanza split is a design choice rather than a build
    requirement.
    - bad/redundant/dune:1:0: bad/redundant/dune has a single stanza with a redundant (modules ...) field; drop it and let dune auto-discover the .ml files
    - bad/uncovered/dune:1:0: bad/uncovered/dune has multiple stanzas but the (modules ...) fields do not cover c; those .ml files are silently excluded from the build
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬─────────────────────────────────────────────────────╮
  │ Category          │ Issues                                              │
  ├───────────────────┼─────────────────────────────────────────────────────┤
  │ Project Structure │ 2 (2 redundant or incomplete (modules ...) in dune) │
  ╰───────────────────┴─────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E523` for the rule's description, hint, and good/bad examples.
  [1]






Good examples exercise every dune construct that can add modules beyond
the source directory: select branches, generate_sites_module, rule targets,
ocamllex, copy_files, and include_subdirs (which suppresses the rule
because subdirectory modules merge into the stanza):

Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E523 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 14 files
  
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



