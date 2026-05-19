Files inside a (vendored_dirs ...) declaration must never be analysed.
The root dune file marks [ext/] as vendored; the bait file [ext/ext_lib.ml]
would otherwise trip E105 (catch-all handler), E300 (variant naming), E505
(missing mli), and others. A clean run proves merlint honours the dune
boundary.

  $ merlint -B .
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

  Summary: ✓ 0 total issues (applied 92 rules)
  ✓ All checks passed!
