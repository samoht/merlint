Build fixture project:
  $ dune build @check

Test bad example - should find missing value documentation:
  $ merlint --build -r E405 bad.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (2 total issues)
    [E405] Missing Value Documentation (2 issues)
    All public values should have documentation explaining their purpose and
    usage. Add doc comments (** ... *) before or after value declarations in .mli
    files.
    - bad.mli:2:0: Public value 'parse' is missing documentation
    - bad.mli:7:0: Public value 'missing_documentation' is missing documentation
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬───────────────────────────────────╮
  │ Category      │ Issues                            │
  ├───────────────┼───────────────────────────────────┤
  │ Documentation │ 2 (2 missing value documentation) │
  ╰───────────────┴───────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E405` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint --build -r E405 good.mli
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

A declaration is in the parsetree: its name, its kind and where it is are read
from the source itself, so answering this rule needs nothing the compiler ever
wrote. Record the answer with the artefacts present, take every one of them
away, and the answer does not move -- not the findings and not the verdict,
which would report the run incomplete if a rule had wanted a typedtree:

  $ merlint --build -r E405 bad.mli > built.txt
  [1]
  $ merlint --build -r E405 good.mli > built-good.txt
  $ rm -rf _build
  $ find . -name '*.cmt*'
  $ merlint -r E405 bad.mli > unbuilt.txt
  [1]
  $ merlint -r E405 good.mli > unbuilt-good.txt
  $ diff built.txt unbuilt.txt
  $ diff built-good.txt unbuilt-good.txt
