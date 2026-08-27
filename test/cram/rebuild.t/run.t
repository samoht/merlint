A rule that reads a typedtree reads it out of a build artefact, or out of a
typecheck of the source where no artefact describes the source as it is now.
Where the build system can offer neither -- nothing here has ever been built,
so nothing says what to type the file against -- those rules do not run at all.
Reporting that as "no issues" reports a rule set that silently shrank, so
merlint builds what it was asked to read and analyses it again. Refusing is
what is left when the build changes nothing.

Each run below spawns a Dune of its own, which must build this sandbox in this
sandbox whatever build directory the developer running the suite picked for the
outer one:

  $ unset DUNE_BUILD_DIR

The project is written here rather than committed beside this transcript,
because the sandbox keeps whatever a test leaves behind:

  $ rm -rf t && mkdir -p t/lib
  $ cat > t/dune-project <<'EOF'
  > (lang dune 3.0)
  > EOF
  $ cat > t/lib/dune <<'EOF'
  > (library
  >  (name mylib))
  > EOF
  $ cat > t/lib/mylib.ml <<'EOF'
  > let p () = Printf.printf "x\n"
  > EOF

E205 resolves the module a name comes from, which only a typedtree answers.
Nothing is built, so the first pass reads nothing; merlint builds the directory
holding the file and reads it again, and the finding that was invisible is
reported:

  $ merlint -r E205 t/lib/mylib.ml
  Dune root: $TESTCASE_ROOT/t
  ! 1 file has no typedtree: no build artefact describes it and the build system names no stanza that compiles it, so nothing says what to type it against and the rules that read a typedtree were skipped.
  ! $TESTCASE_ROOT/t/lib/mylib.ml
  Building the file above, then analysing it again.
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (1 total issues)
    [E205] Consider Using Fmt Module (1 issue)
    The Fmt module provides a more modern and composable approach to formatting.
    It offers better type safety and cleaner APIs compared to Printf/Format
    modules.
    - t/lib/mylib.ml:1:11: Consider using Fmt module instead of Printf for better formatting
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬─────────────────────────────────╮
  │ Category   │ Issues                          │
  ├────────────┼─────────────────────────────────┤
  │ Code Style │ 1 (1 consider using fmt module) │
  ╰────────────┴─────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E205` for the rule's description, hint, and good/bad examples.
  [1]

The artefacts are there now, so the next run reads them and builds nothing:

  $ merlint -v -r E205 t/lib/mylib.ml 2>&1 | grep '^Running: ' | wc -l | tr -d ' '
  0

One build, and only for the directory holding the file. A run that repairs
itself asks Dune for the same alias a run given [--build] asks for:

  $ rm -rf t/_build
  $ merlint -v -r E205 t/lib/mylib.ml 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/t/' '@lib/check' 2>/dev/null

A run given [--build] has already had its build. The repair does not run a
second one on top of it:

  $ rm -rf t/_build
  $ merlint -v --build -r E205 t/lib/mylib.ml 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/t/' '@lib/check' 2>/dev/null

Refusing is what is left when a build cannot produce the artefact. This project
names a library that does not exist, so Dune can configure nothing for it and
no build merlint runs will change that:

  $ rm -rf u && mkdir -p u/lib
  $ cat > u/dune-project <<'EOF'
  > (lang dune 3.0)
  > EOF
  $ cat > u/lib/dune <<'EOF'
  > (library
  >  (name ulib)
  >  (libraries no-such-library-anywhere))
  > EOF
  $ cat > u/lib/ulib.ml <<'EOF'
  > let parse s = try int_of_string s with _ -> 0
  > EOF

E105 runs in the shared typedtree pass, so a file without one is a file it did
not examine. merlint builds, the build fails, and the second pass finds the
file no more readable than the first did. The count of rules applied says what
that leaves: this run applied none of them, and the catch-all handler in the
source goes unreported rather than being called clean.

  $ merlint -r E105 u/lib/ulib.ml
  Dune root: $TESTCASE_ROOT/u
  ! 1 file has no typedtree: no build artefact describes it and the build system names no stanza that compiles it, so nothing says what to type it against and the rules that read a typedtree were skipped.
  ! $TESTCASE_ROOT/u/lib/ulib.ml
  Building the file above, then analysing it again.
  x Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  ! 1 file has no typedtree: no build artefact describes it and the build system names no stanza that compiles it, so nothing says what to type it against and the rules that read a typedtree were skipped.
  ! $TESTCASE_ROOT/u/lib/ulib.ml
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
  
  Summary: ✗ 0 total issues (applied 0 rules, 1 file unchecked)
  ✗ No issues found, but 1 file could not be checked, so some or all of the rules did not run on it. The warnings above name it and say why; -v names every one.
    merlint ran the build for this and no artefact appeared, so the build itself is what needs fixing. Run it and read what it reports:
      dune build --root $TESTCASE_ROOT/u @check
  [2]

Once per run, there too. A run given [--build] whose build failed does not get
a second build out of the repair: one failing build is the answer, and running
it twice would double the wait before the refusal.

  $ merlint -v --build -r E105 u/lib/ulib.ml 2>&1 | grep '^Running: ' | wc -l | tr -d ' '
  1

The same source in a project that does build is read, and the finding is
reported. The rule did not change; what changed is whether anything could say
what to type the file against:

  $ cp u/lib/ulib.ml t/lib/ulib.ml
  $ merlint -r E105 t/lib/ulib.ml 2>/dev/null | tail -3
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E105` for the rule's description, hint, and good/bad examples.
