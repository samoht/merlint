merlint answers two independent questions about a run: whether the code it read
has findings, and whether it read everything it was pointed at. One non-zero
status answered both, so a caller could not tell "your code has problems" from
"I could not look at part of it" -- two answers that call for different work,
one on the tree and one on merlint. The status is a bit set: bit 0 (1) says
findings, bit 1 (2) says incomplete coverage. Both bits, status 3, is the worst
of the three: the findings are real *and* the run that produced them did not
read everything, so the list is also short. Any non-zero still reads as failure
for a caller that only wants pass or fail, which is what the pre-commit hook
does.

The project is written here rather than committed beside this transcript,
because the cases below add a source and then a finding to it and the sandbox
keeps whatever a test leaves behind:

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

E425 reads the interface's parsetree, which needs no build artefact, so nothing
here is unchecked for want of a build: coverage is decided by the dune stanzas
alone.

Nothing to report and every source claimed by a stanza -- complete and clean,
status 0:

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

A source no stanza claims is not a finding about the code: no rule ran on it, so
merlint has nothing to say about it either way. That is a hole in the run's
coverage, and on its own -- no finding anywhere -- it answers 2:

  $ printf 'let x = 1\n' > t/lib/orphan.ml
  $ merlint -r E425 t/lib
  Dune root: $TESTCASE_ROOT/t
  ! 1 file is claimed by no dune stanza, so nothing compiles it and no rule examined it. Three ways that happens: no stanza names it (a [(modules ...)] spec may be excluding it); it no longer belongs in the tree; or a stanza does name it and merlint's project index could not read that stanza, which is a defect in merlint and not one of yours. Check which with [dune exec -- project-index stanzas -p <dir>] and [dune exec -- project-index libraries -p <dir>], where <dir> is the package directory a named file sits under: a stanza that is in the dune file and in neither listing is the third.
  ! $TESTCASE_ROOT/t/lib/orphan.ml
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
  
  Summary: ✗ 0 total issues (applied 1 rule, 1 file unchecked)
  ✗ No issues found, but 1 file could not be checked, so some or all of the rules did not run on it. The warnings above name it and say why; -v names every one.
  [2]

Give the same run a finding as well -- a doc comment after the last constructor,
which binds to that constructor and leaves the type undocumented. Neither answer
cancels the other, so both bits are set and the status is 3:

  $ cat >> t/lib/mylib.mli <<'EOF'
  > 
  > type level = Debug | Info | Error
  > (** The type for the severity of a log entry. *)
  > EOF
  $ cat >> t/lib/mylib.ml <<'EOF'
  > 
  > type level = Debug | Info | Error
  > EOF
  $ merlint -r E425 t/lib > /dev/null
  [3]

Take the unclaimed source away and the finding is all that is left, over a run
that read everything it was pointed at -- status 1:

  $ rm t/lib/orphan.ml
  $ merlint -r E425 t/lib > /dev/null
  [1]

The statuses are documented where a caller looks for them, so nobody has to read
this transcript to find them out:

  $ merlint --help=plain | sed -n '/^EXIT STATUS/,/^[A-Z]/p' | sed 's/^ *//' | grep -E '^[0-9]'
  0   on a complete run with no findings.
  1   findings: the code merlint read has issues to fix.
  2   incomplete coverage: merlint could not read part of it.
  3   both: findings, over a run that read only part of the tree.
  124 refused: nothing was analysed, so there is no verdict.
  125 on unexpected internal errors.
