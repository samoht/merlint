merlint reports on what it read. A path it cannot find is a path it read
nothing of, so a run that skipped it and summarised the rest would answer "All
checks passed" over a file nobody looked at. It refuses the run instead and
names what it could not find.

The project is written here rather than committed beside this transcript,
because the sandbox keeps whatever a test leaves behind:

  $ rm -rf t && mkdir -p t/lib
  $ cat > t/dune-project <<'EOF'
  > (lang dune 3.0)
  > EOF
  $ cat > t/lib/dune <<'EOF'
  > (library
  >  (name mylib)
  >  (modules mylib))
  > EOF
  $ cat > t/lib/mylib.mli <<'EOF'
  > (** A tiny library. *)
  > 
  > type t
  > (** The type for a value. *)
  > EOF
  $ cat > t/lib/mylib.ml <<'EOF'
  > type t = int
  > EOF

E425 reads the interface's parsetree, which needs no build artefact, so the
runs below turn on the paths alone.

A path naming nothing is refused, and the status is the one cmdliner uses for
an argument merlint cannot act on:

  $ merlint -r E425 t/lib/nope.ml
  merlint: t/lib/nope.ml: no such file or directory
  merlint: nothing was analysed, because a run that skipped it would report the files it did read as the whole answer.
  [124]

A missing path beside paths that are there refuses the whole run. The summary
is one verdict over every argument, so reporting on the rest would carry the
same false reading, and it is the caller's list that has to be fixed before any
of it means anything:

  $ merlint -r E425 t/lib t/lib/nope.ml
  merlint: t/lib/nope.ml: no such file or directory
  merlint: nothing was analysed, because a run that skipped it would report the files it did read as the whole answer.
  [124]

Every missing path is named, not just the first: a caller fixing one at a time
would run merlint once per typo.

  $ merlint -r E425 t/lib/nope.ml t/nowhere t/lib/mylib.ml
  merlint: t/lib/nope.ml: no such file or directory
  merlint: t/nowhere: no such file or directory
  merlint: nothing was analysed, because a run that skipped them would report the files it did read as the whole answer.
  [124]

A directory that does not exist is the same answer. Analysing the project it
sits in instead would report a verdict about something other than what was
asked for:

  $ merlint -r E425 t/nowhere
  merlint: t/nowhere: no such file or directory
  merlint: nothing was analysed, because a run that skipped it would report the files it did read as the whole answer.
  [124]

Paths that are all there run as before:

  $ merlint -r E425 t/lib
  Dune root: $TESTCASE_ROOT/t
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
