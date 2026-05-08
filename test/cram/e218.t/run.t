Test bad example - should flag two inline Fmt.kstr Error wrappers:
  $ merlint -B -r E218 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    [E218] Extract Fmt.kstr Error/raise wrappers into let err_/fail_ helpers (4 issues)
    When the same [Fmt.kstr (fun s -> Error (Constructor s)) ...] or [Fmt.kstr
    (fun s -> raise (Constructor s)) ...] lambda appears at multiple call sites,
    extract a small helper at the top of the file:  let err_x  fmt = Fmt.kstr (fun
    s -> Error (Constructor s)) fmt let fail_x fmt = Fmt.kstr (fun s -> raise
    (Constructor s)) fmt  and replace each call site with [err_x "..." args] /
    [fail_x "..." args]. The lambda reads as noise at the call site; the helper
    reads as the domain operation ("emit a wire error", "raise a parse failure").
    For a single one-off site the inline form is fine — the helper is a
    deduplication tool. The rule only flags inline call sites (kstr with a
    literal-string format) and skips helper definitions, which thread a [fmt]
    parameter.
    - bad.ml:9:22: Helper name doesn't match its body: rename 'eval_errorf' to 'fail_<x>' (helpers that wrap [Error]/[raise] should start with [err_]/[fail_])
    - bad.ml:12:17: Inline [Fmt.kstr (fun _ -> Error/raise _) ...] should be a top-of-file helper: let err_of_wire_error fmt = Fmt.kstr (fun s -> Error (...)) fmt    (call: err_of_wire_error "...")
    - bad.ml:17:4: Inline [Fmt.kstr (fun _ -> Error/raise _) ...] should be a top-of-file helper: let err_of_wire_error fmt = Fmt.kstr (fun s -> Error (...)) fmt    (call: err_of_wire_error "...")
    - bad.ml:25:12: Inline [Fmt.kstr (fun _ -> Error/raise _) ...] should be a top-of-file helper: let fail_parse_error fmt = Fmt.kstr (fun s -> raise (...)) fmt    (call: fail_parse_error "...")
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬────────────────────────────────────────────────────────╮
  │ Category   │ Issues                                                 │
  ├────────────┼────────────────────────────────────────────────────────┤
  │ Code Style │ 4 (4 extract fmt.kstr error/raise wrappers into let    │
  │            │ err_/fail_ helpers)                                    │
  ╰────────────┴────────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 4 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - top-of-file [err_wire] helper, no flags:
  $ merlint -B -r E218 good.ml
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
