Test bad example - should flag the standalone _to_ conversions but not action-verb names:
  $ merlint -B -r E333 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (8 total issues)
    [E333] Prefer _of_ over _to_ / _from_ (8 issues)
    Standalone conversion functions in OCaml use the [<dst>_of_<src>] form
    ([int_of_string], [string_of_float], ...) — never [<src>_to_<dst>],
    [<dst>_from_<src>], [<X>_of_t], or [t_of_<X>]. The convention reads as 'an X
    out of a Y' and matches the stdlib precedent. The [to_<X>] prefix is reserved
    for conversions whose source is the module's own [t] ([List.to_seq],
    [Bytes.to_string]); use [<X>_of_<src>] when the source is anything else. The
    rule runs on [.mli] only -- naming is a public-API concern; private helpers in
    [.ml] are not flagged. The rule only flags single-arrow functions ([T1 -> T2]
    with non-unit [T2]), so multi-argument actions ([add_to_set : 'a -> 'a list ->
    'a list]) and writes-into-sink functions ([print_to_buffer : Buffer.t ->
    string -> unit]) are skipped by their type. Add domain-specific exceptions to
    [allowed_words].
    - bad.ml:4:0: Function 'int_to_string' uses a non-canonical conversion-naming form; OCaml convention is 'string_of_int' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.ml:6:0: Function 'bytes_to_hex' uses a non-canonical conversion-naming form; OCaml convention is 'hex_of_bytes' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.ml:11:0: Function 'path_to_uri' uses a non-canonical conversion-naming form; OCaml convention is 'uri_of_path' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.ml:13:0: Function 'value_from_string' uses a non-canonical conversion-naming form; OCaml convention is 'value_of_string' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.ml:14:0: Function 'bytes_from_hex' uses a non-canonical conversion-naming form; OCaml convention is 'bytes_of_hex' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.ml:22:0: Function 'int_of_t' uses a non-canonical conversion-naming form; OCaml convention is 'to_int' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.ml:23:0: Function 't_of_int' uses a non-canonical conversion-naming form; OCaml convention is 'of_int' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.ml:30:0: Function 'to_pair' uses [to_<X>] but its source type is 'string', not [t]. Preferred fix: declare [type t = string] in this module so the function reads as [t -> X] (the canonical primary-type name, per [List.to_seq] / [Bytes.to_string]). Fallback: rename the function to 'pair_of_string' ([<dst>_of_<src>] form).
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬──────────────────────────────────────╮
  │ Category           │ Issues                               │
  ├────────────────────┼──────────────────────────────────────┤
  │ Naming Conventions │ 8 (8 prefer _of_ over _to_ / _from_) │
  ╰────────────────────┴──────────────────────────────────────╯
  
  
  Summary: ✗ 8 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]






Test good example - should find no issues:
  $ merlint -B -r E333 good.ml
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



