Build fixture project:
  $ dune build @check

Bad: code spans naming exported API items should be odoc links.
  $ merlint --build -r E420 bad.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (15 total issues)
    [E420] Missing Odoc Cross-Reference Link (15 issues)
    When documentation mentions another exported API item, use an odoc
    cross-reference link such as {!type-t}, {!val-v}, {!module-M},
    {!module-type-S}, {!exception-E}, {!extension-X}, {!constructor-C},
    {!field-f}, {!class-c}, {!class-type-c}, {!method-m}, or
    {!instance-variable-v}. Keep [x] for code literals and documented arguments.
    - bad.mli:19:2: Documentation for 'run' mentions exported type [t]; use odoc link {!type-t}
    - bad.mli:22:0: Documentation for 'M' mentions exported module type [S]; use odoc link {!module-type-S}
    - bad.mli:36:0: Documentation for 'make' mentions exported value [helper]; use odoc link {!val-helper}
    - bad.mli:36:0: Documentation for 'make' mentions exported method [ct.n]; use odoc link {!class-type-ct.method-n}
    - bad.mli:36:0: Documentation for 'make' mentions exported class type [ct]; use odoc link {!class-type-ct}
    - bad.mli:36:0: Documentation for 'make' mentions exported instance variable [c.iv]; use odoc link {!class-c.instance-variable-iv}
    - bad.mli:36:0: Documentation for 'make' mentions exported method [c.m]; use odoc link {!class-c.method-m}
    - bad.mli:36:0: Documentation for 'make' mentions exported class [c]; use odoc link {!class-c}
    - bad.mli:36:0: Documentation for 'make' mentions exported exception [E]; use odoc link {!exception-E}
    - bad.mli:36:0: Documentation for 'make' mentions exported module type [S]; use odoc link {!module-type-S}
    - bad.mli:36:0: Documentation for 'make' mentions exported module [M]; use odoc link {!module-M}
    - bad.mli:36:0: Documentation for 'make' mentions exported extension [Added]; use odoc link {!extension-Added}
    - bad.mli:36:0: Documentation for 'make' mentions exported constructor [Fast]; use odoc link {!constructor-Fast}
    - bad.mli:36:0: Documentation for 'make' mentions exported field [value]; use odoc link {!field-value}
    - bad.mli:36:0: Documentation for 'make' mentions exported type [t]; use odoc link {!type-t}
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬───────────────────────────────────────────╮
  │ Category      │ Issues                                    │
  ├───────────────┼───────────────────────────────────────────┤
  │ Documentation │ 15 (15 missing odoc cross-reference link) │
  ╰───────────────┴───────────────────────────────────────────╯
  
  
  Summary: ✗ 15 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E420` for the rule's description, hint, and good/bad examples.
  [1]

Good: odoc links satisfy the cross-reference rule.
  $ merlint --build -r E420 good.mli
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

  $ merlint --build -r E420 bad.mli > built.txt
  [1]
  $ merlint --build -r E420 good.mli > built-good.txt
  $ rm -rf _build
  $ find . -name '*.cmt*'
  $ merlint -r E420 bad.mli > unbuilt.txt
  [1]
  $ merlint -r E420 good.mli > unbuilt-good.txt
  $ diff built.txt unbuilt.txt
  $ diff built-good.txt unbuilt-good.txt
