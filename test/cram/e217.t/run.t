Test bad example - should flag generic f (Fmt.str ...) but NOT specialized failwith / invalid_arg cases:
  $ merlint -B -r E217 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (7 total issues)
    [E217] Prefer the matching Fmt helper over (Fmt.str ...) (7 issues)
    Most calls of the shape [<f> (Fmt.str ...)] have a direct [Fmt.X] equivalent
    that avoids the intermediate [Fmt.str] string allocation and reads better: -
    [Buffer.add_string buf (Fmt.str ...)] -> [Fmt.bprintf buf "..."]; -
    [print_endline (Fmt.str ...)] -> [Fmt.pr "...@."]; - [print_string (Fmt.str
    ...)] -> [Fmt.pr "..."]; - [prerr_endline (Fmt.str ...)] -> [Fmt.epr "...@."];
    - [prerr_string (Fmt.str ...)] -> [Fmt.epr "..."]; - [Error (Fmt.str ...)] ->
    [Fmt.kstr (fun e -> Error e) "..."], or a one-shot [error_msgf] helper in the
    package; - any other [<f> (Fmt.str ...)] -> [Fmt.kstr <f> "..."]. Specialised
    cases for [failwith], [invalid_arg], [Alcotest.fail], and bare [fail] are
    handled by E215, E216, and E616 respectively.
    - bad.ml:2:22: Wrap with [Fmt.kstr (fun s -> Error s) "..."] instead of [... (Fmt.str ...)]
    - bad.ml:6:14: Wrap with [Fmt.kstr log "..."] instead of [... (Fmt.str ...)]
    - bad.ml:9:14: Wrap with [Fmt.kstr (fun s -> Some s) "..."] instead of [... (Fmt.str ...)]
    - bad.ml:13:2: Wrap with [Fmt.bprintf buf "..."] instead of [... (Fmt.str ...)]
    - bad.ml:15:20: Wrap with [Fmt.pr "...@."] instead of [... (Fmt.str ...)]
    - bad.ml:16:20: Wrap with [Fmt.epr "...@."] instead of [... (Fmt.str ...)]
    - bad.ml:17:19: Wrap with [Fmt.pr "..."] instead of [... (Fmt.str ...)]
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬────────────────────────────────────────────────────────╮
  │ Category   │ Issues                                                 │
  ├────────────┼────────────────────────────────────────────────────────┤
  │ Code Style │ 7 (7 prefer the matching fmt helper over (fmt.str      │
  │            │ ...))                                                  │
  ╰────────────┴────────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 7 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E217 good.ml
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
