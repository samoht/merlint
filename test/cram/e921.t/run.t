Bad: README.md and foo.mli contain dune-promoted mdx-error blocks.

Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E921 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (2 total issues)
    [E921] Promoted MDX error block in source (2 issues)
    A README.md, .mli, or .mld file contains an mdx-error block produced by [dune
    promote] after a failing mdx run. The error output belongs in a [.corrected]
    file for review, not in the committed source. Fix the underlying example so it
    type-checks and remove the block.
    - bad/README.md:8:0: bad/README.md:8: dune-promoted mdx-error block found; fix the example so it compiles and remove the error block
    - bad/foo.mli:6:0: bad/foo.mli:6: dune-promoted mdx-error block found; fix the example so it compiles and remove the error block
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬──────────────────────────────────────────╮
  │ Category      │ Issues                                   │
  ├───────────────┼──────────────────────────────────────────┤
  │ Documentation │ 2 (2 promoted mdx error block in source) │
  ╰───────────────┴──────────────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E921` for the rule's description, hint, and good/bad examples.
  [1]

Good: no mdx-error blocks anywhere.

Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E921 good/
  Dune root: $TESTCASE_ROOT/good/
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
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
