A package checkout can be built from a dune workspace that lives elsewhere and
reaches its sources through a symlink. Here [pkg] links against [helper], a
library of the [ws] workspace, so [pkg] builds only as part of [ws] and its
.cmt/.cmti artefacts are written there.

  $ ln -s ../pkg ws/pkg
  $ cd pkg

Analysed as a project of its own the checkout cannot be built, so it has no
artefact for any of its files, so the build merlint runs to repair that fails
and the run is refused: status 4, no verdict, rather than a clean one.

  $ mv merlint.toml declared.toml
  $ merlint --build . 2>/dev/null | sed -E 's/applied [0-9]+ rules/applied N rules/' | tail -2
  Dune root: $TESTCASE_ROOT/pkg/
  $ merlint . > /dev/null 2>&1
  [4]

Nothing in the checkout points back at the workspace, and more than one
workspace may link the same sources, so the checkout names the one that builds
it:

  $ mv declared.toml merlint.toml
  $ cat merlint.toml
  workspace = "../ws"

merlint then analyses the checkout as the workspace knows it: the workspace is
the Dune root, the build happens there, and every file is checked.

  $ merlint --build . | sed -E 's/applied [0-9]+ rules/applied N rules/'
  Dune root: $TESTCASE_ROOT/ws/
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
  
  Summary: ✓ 0 total issues (applied N rules)
  ✓ All checks passed!

The declaration only moves a run that starts in the checkout. Started in the
workspace it is already there and stays put.

  $ cd ../ws
  $ merlint pkg | sed -n '1p'
  Dune root: $TESTCASE_ROOT/ws/

A declaration that does not apply here is a note, not a refusal. This is what a
second working tree of the checkout sees, since no workspace reaches it: the
run continues where it stands and answers exactly as it would with no
declaration at all.

  $ rm pkg
  $ cd ../pkg
  $ merlint . 2>&1 >/dev/null
  Note: merlint.toml declares workspace $TESTCASE_ROOT/ws/, whose source tree does not reach $TESTCASE_ROOT/pkg/. The workspace builds this checkout only if one of its directories is this one.
  Analysing this tree where it stands.
  Building the 2 files above, then analysing them again.
  merlint: the project does not build: Command failed with exit code 1: File "lib/dune", line 3, characters 12-18:
  3 |  (libraries helper))
                  ^^^^^^
  Error: Library "helper" not found.
  -> required by library "demo" in _build/default/lib
  -> required by _build/default/lib/.demo.objs/byte/demo.cmi
  -> required by alias lib/check
  merlint: nothing was analysed, because a verdict computed without the artefacts its rules read is not a verdict about this code.
  [4]
  $ merlint . 2>/dev/null | sed -E 's/applied [0-9]+ rules/applied N rules/' | tail -4
  Dune root: $TESTCASE_ROOT/pkg/
  ! 2 files have no typedtree: no build artefact describes them and the build system names no stanza that compiles them, so nothing says what to type them against and the rules that read a typedtree were skipped.
  ! $TESTCASE_ROOT/pkg/lib/demo.ml
  ! $TESTCASE_ROOT/pkg/lib/demo.mli
