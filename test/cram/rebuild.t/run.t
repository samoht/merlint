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
  Running: dune build --root '$TESTCASE_ROOT/t/' '@_build/default/lib/check'

A run given [--build] has already had its build. The repair does not run a
second one on top of it:

  $ rm -rf t/_build
  $ merlint -v --build -r E205 t/lib/mylib.ml 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/t/' '@_build/default/lib/check'

An executable helper is compiled by the executable target that owns it. The
directory check alias asks Dune for its typedtree, while the exact target makes
the stanza build even in a composed workspace whose scoped alias is empty. Both
belong to the same repair:

  $ mkdir -p t/app
  $ cat > t/app/dune <<'EOF'
  > (executable
  >  (name runner)
  >  (modules runner helper))
  > EOF
  $ cat > t/app/runner.ml <<'EOF'
  > let () = Helper.run ()
  > EOF
  $ cat > t/app/helper.ml <<'EOF'
  > let run () = Printf.printf "x\n"
  > EOF
  $ rm -rf t/_build
  $ merlint -v -r E205 t/app/helper.ml 2>&1 | grep '^Running: '
  Running: dune build --root '$TESTCASE_ROOT/t/' '@_build/default/app/check' '_build/default/app/runner.exe'

Merlint reads typedtrees from Dune's default context, so repairing one must not
build every other context in the workspace. A release-only check action makes
that otherwise invisible extra work observable:

  $ cat > t/dune-workspace <<'EOF'
  > (lang dune 3.21)
  > (context default)
  > (context
  >  (default
  >   (name release)))
  > EOF
  $ cat >> t/lib/dune <<'EOF'
  > (rule
  >  (alias check)
  >  (enabled_if (= %{context_name} release))
  >  (action (write-file release-was-built "")))
  > EOF
  $ rm -rf t/_build
  $ merlint -r E205 t/lib/mylib.ml >/dev/null 2>&1
  [1]
  $ test ! -e t/_build/release/lib/release-was-built

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
not examine. merlint builds, the build fails, and there is no second pass: a
project that does not build is refused at once, with what dune said about it,
rather than analysed against artefacts that describe something else. No verdict
is printed, because none was computed -- the catch-all handler in the source is
neither reported nor called clean.

  $ merlint -r E105 u/lib/ulib.ml
  Dune root: $TESTCASE_ROOT/u
  ! 1 file has no typedtree: no build artefact describes it and the build system names no stanza that compiles it, so nothing says what to type it against and the rules that read a typedtree were skipped.
  ! $TESTCASE_ROOT/u/lib/ulib.ml
  Building the file above, then analysing it again.
  merlint: the project does not build: Command failed with exit code 1: Entering directory 'u'
  File "lib/dune", line 3, characters 12-36:
  3 |  (libraries no-such-library-anywhere))
                  ^^^^^^^^^^^^^^^^^^^^^^^^
  Error: Library "no-such-library-anywhere" not found.
  -> required by library "ulib" in _build/default/lib
  -> required by _build/default/lib/.ulib.objs/byte/ulib.cmi
  -> required by alias lib/check
  Leaving directory 'u'
  merlint: nothing was analysed, because a verdict computed without the artefacts its rules read is not a verdict about this code.
  [4]

The JSON report carries the same refusal as an instrument failure, not as an
unchecked file. Zero analysed and zero unchecked say that no lint verdict was
computed; [build_failure] says why, and [passed] cannot be read as green:

  $ (merlint --json --build -r E105 u/lib/ulib.ml > report.json 2>/dev/null; status=$?; sed -E 's/.*"files_analyzed":([0-9]+).*"unchecked":([0-9]+).*"build_failure":\{"kind":"([^"]+)","error":".*"\},"passed":([^,}]+).*/files_analyzed=\1 unchecked=\2 build_failure=\3 passed=\4/' report.json; exit $status)
  files_analyzed=0 unchecked=0 build_failure=broken passed=false
  [4]

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
