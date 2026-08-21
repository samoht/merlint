A typedtree describes source. One read from a .cmt describes the source the
compiler read, which is the source on disk only until someone edits the file.
Where no artefact describes the file as it is now, merlint typechecks it instead
and the rules run on what is there; where nothing says what to typecheck it
against, the run has examined less than it was asked to and reports that rather
than passing.

Nothing is built, so no artefact describes lib.mli and the build system, which
has never built this project, can name no stanza that compiles it either:

  $ merlint -r E105 lib.mli
  Dune root: $TESTCASE_ROOT/
  ! 1 file has no typedtree: no build artefact describes it and the build system names no stanza that compiles it, so nothing says what to type it against and the rules that read a typedtree were skipped. Run [dune build @check] (or pass [--build]) before merlint.
  ! $TESTCASE_ROOT/lib.mli
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
  
  Summary: ✗ 0 total issues (applied 1 rule, 1 file unchecked)
  ✗ No issues found, but 1 file could not be fully checked, so some of the rules that read a typedtree did not run on it. Re-run with -v to name it and say why.
  [1]

The JSON document reports the verdict the exit status reports, and says how many
files the run could not reach. Nothing but the document goes to stdout, so the
output parses:

  $ merlint --json -r E105 lib.mli 2>/dev/null
  {"project_root":"$TESTCASE_ROOT/","files_analyzed":1,"rules_applied":1,"total_issues":0,"unchecked":1,"passed":false,"issues":[],"excluded":[]}
  [1]

With the artefacts present the run is complete and the verdict is clean:

  $ merlint --build -r E105 lib.mli
  Dune root: $TESTCASE_ROOT/
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
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!

An artefact newer than its source is not therefore an artefact of that source:
dune restores cached .cmt files by hardlink, so one compiled from different
content can carry the later timestamp. Edit the implementation, give the stale
artefact the newer mtime, and put an issue on the new line:

  $ chmod +w lib.ml
  $ printf '\nlet parse s = try int_of_string s with _ -> 0\n' >> lib.ml
  $ touch _build/default/.lib.objs/byte/lib.cmt

The digest the compiler recorded still names the source it read, so the artefact
is refused -- and the source is typechecked in its place. The rule runs on what
is on disk and points at the line that is there now, which no artefact
describes:

  $ merlint -r E105 lib.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E105] Catch-all Exception Handler (1 issue)
    Catch-all exception handlers (with _ ->) can hide unexpected errors and make
    debugging difficult. Always handle specific exceptions explicitly. If you must
    catch all exceptions, log them or re-raise after cleanup.
    - lib.ml:5:39: Catch-all exception handler found. This can hide unexpected errors.
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬───────────────────────────────────╮
  │ Category     │ Issues                            │
  ├──────────────┼───────────────────────────────────┤
  │ Code Quality │ 1 (1 catch-all exception handler) │
  ╰──────────────┴───────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E105` for the rule's description, hint, and good/bad examples.
  [1]

A doc comment is a property of the source, not of anything the compiler wrote:
it is in the interface's parsetree, which needs no artefact and no typechecker.
So the rules that read one answer for the file on disk. Document a type after
its declaration, where odoc binds the comment to the last constructor instead
of the type, and leave the artefact describing the source before the edit:

  $ chmod +w lib.mli
  $ cat >> lib.mli <<'EOF'
  > 
  > type level = Debug | Info | Error
  > (** The type for the severity of a log entry. *)
  > EOF
  $ cat >> lib.ml <<'EOF'
  > 
  > type level = Debug | Info | Error
  > EOF
  $ touch _build/default/.lib.objs/byte/lib.cmti
  $ merlint -r E425 lib.mli | grep -E "lib.mli:|Summary"
    - lib.mli:10:0: Type 'level' has no documentation: the comment after its last constructor documents 'Error'. Put the type's doc before 'type level'
  Summary: ✗ 1 total issue (applied 1 rule)

Nothing the compiler wrote is involved, so removing the artefact outright
changes no answer:

  $ rm -f _build/default/.lib.objs/byte/lib.cmti
  $ merlint -r E425 lib.mli | grep -E "lib.mli:|Summary"
    - lib.mli:10:0: Type 'level' has no documentation: the comment after its last constructor documents 'Error'. Put the type's doc before 'type level'
  Summary: ✗ 1 total issue (applied 1 rule)

A stanza Dune does not build here is one the build system has nothing to say
about, so a file of it can never be placed and no build the user runs will
change that. It is gated out of the report; the ungated file at the top of this
run was not.

  $ mkdir -p gated
  $ cat > gated/dune <<'EOF'
  > (library
  >  (name glib)
  >  (enabled_if (= %{context_name} never-a-real-context)))
  > EOF
  $ cat > gated/glib.mli <<'EOF'
  > (** A gated module. *)
  > 
  > type t
  > (** The type for a value. *)
  > EOF
  $ cat > gated/glib.ml <<'EOF'
  > type t = int
  > EOF
  $ merlint --build -r E425 gated/glib.mli
  Dune root: $TESTCASE_ROOT/
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
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!

A build and its analysis must use the same source snapshot. This Dune adapter
lands a new source immediately after the build finishes. The current run must
not discover that unbuilt file after the warm-up; the next run will build and
analyse it normally:

  $ mkdir -p race-bin
  $ cp dune-adapter race-bin/dune
  $ chmod +x race-bin/dune
  $ rm -f race/lib/late.ml
  $ real_dune=$(command -v dune); PATH="$PWD/race-bin:$PATH" ADD_SOURCE="$PWD/race/lib/late.ml" REAL_DUNE="$real_dune" merlint --build -r E100 race/
  Dune root: $TESTCASE_ROOT/race/
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
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!

An artefact deleted is not the same as an artefact that never existed: merlint
typechecks a source no artefact describes, and it can only do that where the
build system names a configuration for the file. A parse needs no such
configuration, so with nothing built at all the answer is still the same one:

  $ rm -rf _build
  $ find . -name '*.cmt*' | wc -l | tr -d ' '
  0
  $ merlint -r E425 lib.mli | grep -E "lib.mli:|Summary"
    - lib.mli:10:0: Type 'level' has no documentation: the comment after its last constructor documents 'Error'. Put the type's doc before 'type level'
  Summary: ✗ 1 total issue (applied 1 rule)
