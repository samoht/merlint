merlint has rules for .ml and .mli and for no other kind of file. Given a path
of any other kind it reads nothing of it, and it used to say so by leaving a
line out: no file count, a rule count drawn from the project rules alone, and
"All checks passed" over a file nobody opened. Every brief in this repository
carries "merlint on each file you touch, zero findings", and a lane that ran
merlint over a shell script and a .gitignore got that sentence and reported the
gate as met. The gate was empty, and the only thing that said so was a line
that was not there.

Such a path is named now, and the run reports incomplete coverage. It is not
refused, which is what a path that does not exist gets (missing.t): a list
naming something that is not there is wrong, and no verdict computed from a
wrong list means anything, while a list naming a dune stanza or a cram
transcript beside the sources is an ordinary thing to lint and refusing it
would leave the caller nothing to run.

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
  $ cat > t/notes.txt <<'EOF'
  > Not OCaml.
  > EOF

E425 reads the interface's parsetree, which needs no build artefact, so the
runs below turn on the paths alone.

A path merlint has no rule for is named, and the count above the verdict says
the run read nothing:

  $ merlint -r E425 t/notes.txt
  Dune root: $TESTCASE_ROOT/t
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  Summary: ✗ 0 total issues (applied 0 rules, 1 path skipped)
  ✗ merlint reads .ml and .mli only, so nothing above is a verdict on 1 path it was given:
      t/notes.txt
  [2]

Beside a source it can read, the source is analysed and the path is still
named. This is the case a refusal would have blocked: a lane linting the files
one change touched names the dune stanza next to them.

  $ merlint -r E425 t/lib/mylib.mli t/lib/dune
  Dune root: $TESTCASE_ROOT/t
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
  
  Summary: ✗ 0 total issues (applied 1 rule, 1 path skipped)
  ✗ merlint reads .ml and .mli only, so nothing above is a verdict on 1 path it was given:
      t/lib/dune
  [2]

Every one is named, not just the first, so a caller reads the whole gap in one
run:

  $ merlint -r E425 t/notes.txt t/lib/dune t/dune-project
  Dune root: $TESTCASE_ROOT/t
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  Summary: ✗ 0 total issues (applied 0 rules, 3 paths skipped)
  ✗ merlint reads .ml and .mli only, so nothing above is a verdict on 3 paths it was given:
      t/notes.txt
      t/lib/dune
      t/dune-project
  [2]
The document a scripted caller reads carries the same answer, so the JSON and
the status never disagree:

  $ merlint --json -r E425 t/notes.txt
  {"project_root":"$TESTCASE_ROOT/t","files_analyzed":0,"rules_applied":0,"total_issues":0,"unchecked":0,"unchecked_files":[],"unclaimed_files":[],"skipped_paths":["t/notes.txt"],"failed_checks":[],"passed":false,"issues":[],"excluded":[]}
  [2]

A directory argument is unaffected, and that is the shape the pre-commit hook
runs: it hands merlint one directory, never a file, and the files of other
kinds inside it are not paths the caller asked about. t/lib holds a dune
stanza; the run over it is complete and clean.

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

A finding in the source does not cancel the gap, and the gap does not hide the
finding. Bit 0 says the code has findings, bit 1 says the run answered for less
than it was given, and both together are status 3 -- the same bits an
unreadable artefact sets (exit.t):

  $ cat >> t/lib/mylib.mli <<'EOF'
  > 
  > type level = Debug | Info | Error
  > (** The type for the severity of a log entry. *)
  > EOF
  $ merlint -r E425 t/lib/mylib.mli t/lib/dune > /dev/null
  [3]
