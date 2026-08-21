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
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@alpha/check' 2>/dev/null

A file argument is scoped by the directory holding it, which is the directory
whose alias compiles it:

  $ merlint -v --build -r E100 alpha/alpha.ml 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@alpha/check' 2>/dev/null

Several scopes are several alias targets in a single Dune invocation, and two
files of one directory name that directory once:

  $ merlint -v --build -r E100 alpha beta/beta.ml beta/beta.mli 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@alpha/check' '@beta/check' 2>/dev/null

Asked for the whole project, the whole project is what is built:

  $ merlint -v --build -r E100 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@check' 2>/dev/null

The dune root named explicitly is that same whole project, and the bare alias
is its alias: Dune has no @./check to build.

  $ merlint -v --build -r E100 . 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/proj/' '@check' 2>/dev/null

A directory outside the dune root has no alias under that root. Building the
whole tree instead would do something other than what was asked without saying
so, so the warm-up refuses and names the scope it cannot place. The analysis
carries on with whatever artefacts are already there:

  $ merlint --build -r E100 alpha ../outside 2>&1 >/dev/null
  Warning: $TESTCASE_ROOT/outside/ is outside the dune root $TESTCASE_ROOT/proj/, so it has no [@check] alias there
  Function type analysis may not work properly.
  Continuing with analysis...
