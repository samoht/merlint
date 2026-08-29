merlint --build warms Dune's check alias so the rules that read a typedtree
find artefacts to read. What it warms is what the run was asked to analyse: the
alias of each scope named on the command line, in one Dune invocation. A scoped
run that rebuilt the whole workspace would spend minutes of build to lint one
directory, and every commit hook that lints one package would pay it.

Each run below spawns a Dune of its own, which must build this sandbox in this
sandbox whatever build directory the developer running the suite picked for the
outer one:

  $ unset DUNE_BUILD_DIR
  $ cd proj

A directory argument builds that directory's alias, and only that one:

  $ merlint -v --build -r E100 alpha 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@alpha/check'

A file argument is scoped by the directory holding it, which is the directory
whose alias compiles it:

  $ merlint -v --build -r E100 alpha/alpha.ml 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@alpha/check'

Several scopes are several alias targets in a single Dune invocation, and two
files of one directory name that directory once:

  $ merlint -v --build -r E100 alpha beta/beta.ml beta/beta.mli 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@alpha/check' '@beta/check'

Asked for the whole project, the whole project is what is built:

  $ merlint -v --build -r E100 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@check'

The dune root named explicitly is that same whole project, and the bare alias
is its alias: Dune has no @./check to build.

  $ merlint -v --build -r E100 . 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@check'

A directory outside the dune root is refused before any of this. It has no
alias under that root, but it also has no source any rule would read, so the
answer does not depend on what [--build] would have done next and the run does
not get that far. Both halves are named resolved, because a caller checking a
relative argument against a root needs to see where it landed:

  $ merlint --build -r E100 alpha ../outside 2>&1 >/dev/null
  merlint: $TESTCASE_ROOT/outside is outside the dune root $TESTCASE_ROOT/proj/
  merlint: nothing was analysed, because no rule reads a source from outside the root the run resolved.
  [4]
