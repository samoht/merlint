Bad examples: a single-stanza dune with an explicit (modules ...) is
redundant, and two sibling stanzas that don't cover every .ml in the
directory silently drop files from the build:

Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E523 bad/
  Dune root: $TESTCASE_ROOT/bad/
  ! 1 file is claimed by no dune stanza, so nothing compiles it and no rule examined it. Three ways that happens: no stanza names it (a [(modules ...)] spec may be excluding it); it no longer belongs in the tree; or a stanza does name it and merlint's project index could not read that stanza, which is a defect in merlint and not one of yours. Check which with [dune exec -- project-index stanzas -p <dir>] and [dune exec -- project-index libraries -p <dir>], where <dir> is the package directory a named file sits under: a stanza that is in the dune file and in neither listing is the third.
  ! $TESTCASE_ROOT/bad/uncovered/c.ml
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
  
  
  Summary: ✗ 2 total issues (applied 1 rule, 1 file unchecked)
  ✗ Some checks failed. See details above.
    Run `merlint help E523` for the rule's description, hint, and good/bad examples.
  [3]






Good examples exercise every dune construct that can add modules beyond
the source directory: select branches, generate_sites_module, rule targets,
ocamllex, copy_files, include_subdirs (which suppresses the rule because
subdirectory modules merge into the stanza), and an enabled_if-gated stanza
(whose module is still claimed -- merlint must not drop gated stanzas):

Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E523 good/
  Dune root: $TESTCASE_ROOT/good/
  ! 6 files are claimed by no dune stanza, so nothing compiles them and no rule examined them. Three ways that happens: no stanza names them (a [(modules ...)] spec may be excluding them); they no longer belong in the tree; or a stanza does name them and merlint's project index could not read that stanza, which is a defect in merlint and not one of yours. Check which with [dune exec -- project-index stanzas -p <dir>] and [dune exec -- project-index libraries -p <dir>], where <dir> is the package directory a named file sits under: a stanza that is in the dune file and in neither listing is the third.
  ! $TESTCASE_ROOT/good/include_subdirs/sub/baz.ml
  ! $TESTCASE_ROOT/good/select/chooser_default.ml
  ! $TESTCASE_ROOT/good/select/chooser_re.ml
  ! $TESTCASE_ROOT/good/select_dotted/c_tier.everparse.ml
  ! $TESTCASE_ROOT/good/select_dotted/c_tier.none.ml
  ! $TESTCASE_ROOT/good/src/helpers.ml
  Running merlint analysis...
  
  Analyzing 18 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  Summary: ✗ 0 total issues (applied 1 rule, 6 files unchecked)
  ✗ No issues found, but 6 files could not be checked, so some or all of the rules did not run on them. Re-run with -v to name them and say why.
  [2]



