A run that could not look at part of the tree has to be able to say which part.
The warning names a sample of ten, which keeps the message readable on a
whole-repo run and told a lane nothing it could act on: recovering the rest of
the set meant sweeping the packages by hand. The cap is a default, not a ceiling
-- [-v] names every one, and [--json] carries both sets in full.

A library whose [(modules mylib)] names one module, beside twelve sources no
stanza claims:

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
  $ for i in 01 02 03 04 05 06 07 08 09 10 11 12; do printf 'let x = 1\n' > t/lib/orphan_$i.ml; done

By default the warning stops at ten and says how many it left out, and where the
rest are:

  $ merlint -r E425 t/lib 2>&1 | grep -E '^! ' | sed 's|.*/lib/|lib/|'
  ! 12 files are claimed by no dune stanza, so nothing compiles them and no rule examined them. Three ways that happens: no stanza names them (a [(modules ...)] spec may be excluding them); they no longer belong in the tree; or a stanza does name them and merlint's project index could not read that stanza, which is a defect in merlint and not one of yours. Check which with [dune exec -- project-index stanzas -p <dir>] and [dune exec -- project-index libraries -p <dir>], where <dir> is the package directory a named file sits under: a stanza that is in the dune file and in neither listing is the third.
  lib/orphan_01.ml
  lib/orphan_02.ml
  lib/orphan_03.ml
  lib/orphan_04.ml
  lib/orphan_05.ml
  lib/orphan_06.ml
  lib/orphan_07.ml
  lib/orphan_08.ml
  lib/orphan_09.ml
  lib/orphan_10.ml
  ! ... and 2 more (-v names every one; --json carries the whole set)

[-v] names all twelve, so a repo-wide run can enumerate its own blind spot in
one pass. The info-level lines that come with it carry timings, so only the file
names are compared here:

  $ merlint -v -r E425 t/lib 2>&1 | grep -oE 'lib/orphan_[0-9]+\.ml' | sort -u
  lib/orphan_01.ml
  lib/orphan_02.ml
  lib/orphan_03.ml
  lib/orphan_04.ml
  lib/orphan_05.ml
  lib/orphan_06.ml
  lib/orphan_07.ml
  lib/orphan_08.ml
  lib/orphan_09.ml
  lib/orphan_10.ml
  lib/orphan_11.ml
  lib/orphan_12.ml

The JSON document keeps the two kinds apart and carries both in full:
[unclaimed_files] for the sources no stanza compiles, so no rule ran on them,
and [unchecked_files] for the ones a rule was asked about and no artefact
described. Their lengths sum to [unchecked], so a caller reading either never
disagrees with the exit status that [exit.t] pins:

  $ merlint --json -r E425 t/lib 2>/dev/null | sed 's|"[^"]*/lib/|"lib/|g'
  {"project_root":"$TESTCASE_ROOT/t","files_analyzed":2,"rules_applied":1,"total_issues":0,"unchecked":12,"unchecked_files":[],"unclaimed_files":["lib/orphan_01.ml","lib/orphan_02.ml","lib/orphan_03.ml","lib/orphan_04.ml","lib/orphan_05.ml","lib/orphan_06.ml","lib/orphan_07.ml","lib/orphan_08.ml","lib/orphan_09.ml","lib/orphan_10.ml","lib/orphan_11.ml","lib/orphan_12.ml"],"skipped_paths":[],"failed_checks":[],"build_failure":null,"passed":false,"issues":[],"excluded":[]}

A file named on the command line is the same question asked of one file. The
orphans of a directory the caller did not name stay out of a file-scoped run --
that set is the caller's own accounting -- but a file it did name is exactly
what it is owed an answer about, and answering nothing reported a file no rule
could examine as a clean pass:

  $ merlint -r E425 t/lib/orphan_01.ml 2>&1 | grep -cE '^! .*orphan_01\.ml$'
  1
  $ merlint -r E425 t/lib/orphan_01.ml > /dev/null 2>&1
  [2]

A named file a stanza does claim is unaffected, so this costs an ordinary run
nothing:

  $ merlint -r E425 t/lib/mylib.ml > /dev/null 2>&1
