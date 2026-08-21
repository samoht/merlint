Build fixture project:
  $ dune build @check

Test bad example - should find create/make that should be 'v':
  $ merlint --build -r E332 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (5 total issues)
    [E332] Prefer 'v' Constructor (5 issues)
    In OCaml modules, the idiomatic name for the primary constructor is 'v' rather
    than 'create' or 'make'. This follows the convention used by many standard
    libraries. For example, 'Module.create' should be 'Module.v'. This makes the
    API more consistent and idiomatic.
    - bad.ml:7:2: Function 'User.create' should be named 'v' - this is the idiomatic constructor name in OCaml modules
    - bad.ml:14:2: Function 'Widget.make' should be named 'v' - this is the idiomatic constructor name in OCaml modules
    - bad.ml:21:2: Function 'Config.create' should be named 'v' - this is the idiomatic constructor name in OCaml modules
    - bad.ml:31:0: Function 'create' should be named 'v' - this is the idiomatic constructor name in OCaml modules
    - bad.ml:32:0: Function 'make' should be named 'v' - this is the idiomatic constructor name in OCaml modules
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬──────────────────────────────╮
  │ Category           │ Issues                       │
  ├────────────────────┼──────────────────────────────┤
  │ Naming Conventions │ 5 (5 prefer 'v' constructor) │
  ╰────────────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 5 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E332` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint --build -r E332 good.ml
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

A qualified allowed_words entry (Container.create) exempts only that binding;
a bare top-level create is still flagged:
  $ merlint --build -r E332 allowed.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (1 total issues)
    [E332] Prefer 'v' Constructor (1 issue)
    In OCaml modules, the idiomatic name for the primary constructor is 'v' rather
    than 'create' or 'make'. This follows the convention used by many standard
    libraries. For example, 'Module.create' should be 'Module.v'. This makes the
    API more consistent and idiomatic.
    - allowed.ml:5:0: Function 'create' should be named 'v' - this is the idiomatic constructor name in OCaml modules
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬──────────────────────────────╮
  │ Category           │ Issues                       │
  ├────────────────────┼──────────────────────────────┤
  │ Naming Conventions │ 1 (1 prefer 'v' constructor) │
  ╰────────────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E332` for the rule's description, hint, and good/bad examples.
  [1]

A declaration is in the parsetree: its name, its kind and where it is are read
from the source itself, so answering this rule needs nothing the compiler ever
wrote. Record the answer with the artefacts present, take every one of them
away, and the answer does not move -- not the findings and not the verdict,
which would report the run incomplete if a rule had wanted a typedtree:

  $ merlint --build -r E332 bad.ml > built.txt
  [1]
  $ merlint --build -r E332 good.ml > built-good.txt
  $ rm -rf _build
  $ find . -name '*.cmt*'
  $ merlint -r E332 bad.ml > unbuilt.txt
  [1]
  $ merlint -r E332 good.ml > unbuilt-good.txt
  $ diff built.txt unbuilt.txt
  $ diff built-good.txt unbuilt-good.txt
