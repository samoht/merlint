A run whose typedtree-backed rules could not read a .cmt has examined less
than it was asked to. Reporting that as "0 issues" makes it indistinguishable
from a complete run that found nothing, so the summary has to say so.

Without building, no .cmt exists and those rules cannot run:

  $ merlint -r E425 lib.mli
  Dune root: $TESTCASE_ROOT/
  merlint: [WARNING] 1 typedtree-backed query found a missing or stale .cmt/.cmti file; the affected rule runs were skipped for those files. Run [dune build @check] (or pass [--build]) before merlint so the build artefacts are present and up to date.
                     $TESTCASE_ROOT/lib.mli
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
  ✗ No issues found, but 1 file could not be checked: the .cmt/.cmti was missing or out of date, so the rules that read a typedtree did not run on it. Re-run with -v to name it.
  [1]

With the artefacts present the run is complete and the verdict is clean:

  $ merlint --build -r E425 lib.mli
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
