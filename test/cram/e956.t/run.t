E956 flags a (libraries ...) entry none of whose compilation units appear
in the imports the compiler recorded for the stanza's units.

The bad fixture is the probe/wire incident in miniature: the consumer
stanza links [spy] and [wire]; [spy] is a wrapped library with an internal
[wire.ml] (unit [Spy__Wire]); the consumer genuinely uses the [wire]
codec's entry unit [Wire] and mentions the token "Wire" in a comment, but
never imports any unit of [spy]. A text-based module-reference scan
credits spy with the comment token; the import record does not.

Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build --json -r E956 bad/
  {"project_root":"$TESTCASE_ROOT/bad/","files_analyzed":4,"rules_applied":1,"total_issues":1,"unchecked":0,"unchecked_files":[],"unclaimed_files":[],"skipped_paths":[],"failed_checks":[],"passed":false,"issues":[{"code":"E956","title":"Dead library dependency","category":"Project Structure","message":"spy is linked by stanza consumer but never imported: no compilation unit of spy appears in the stanza's .cmt imports. Remove it from (libraries ...).","location":{"file":"bad/consumer/dune","start":{"line":1,"column":0},"end":{"line":1,"column":0}}}],"excluded":[]}
  [1]

Test good example - both libraries are imported by the consumer, and the
umbrella library (re_export ...)s them to its dependents without importing
them itself:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E956 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 5 files
  
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
