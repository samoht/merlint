Test bad example - should flag the standalone _to_ conversions but not action-verb names:
  $ merlint -B -r E333 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (5 total issues)
    [E333] Prefer _of_ over _to_ / _from_ (5 issues)
    Standalone conversion functions in OCaml use the [<dst>_of_<src>] form
    ([int_of_string], [string_of_float], ...) — never [<src>_to_<dst>] or
    [<dst>_from_<src>]. The convention reads as 'an X out of a Y' and matches the
    stdlib precedent. The rule only flags single-arrow functions ([T1 -> T2] with
    non-unit [T2]), so multi-argument actions ([add_to_set : 'a -> 'a list -> 'a
    list]) and writes-into-sink functions ([print_to_buffer : Buffer.t -> string
    -> unit]) are skipped by their type. Add domain-specific exceptions to
    [allowed_words].
    - bad.ml:4:0: Function 'int_to_string' uses the [<src>_to_<dst>] / [<dst>_from_<src>] form; OCaml convention is 'string_of_int' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...)
    - bad.ml:6:0: Function 'bytes_to_hex' uses the [<src>_to_<dst>] / [<dst>_from_<src>] form; OCaml convention is 'hex_of_bytes' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...)
    - bad.ml:11:0: Function 'path_to_uri' uses the [<src>_to_<dst>] / [<dst>_from_<src>] form; OCaml convention is 'uri_of_path' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...)
    - bad.ml:13:0: Function 'value_from_string' uses the [<src>_to_<dst>] / [<dst>_from_<src>] form; OCaml convention is 'value_of_string' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...)
    - bad.ml:14:0: Function 'bytes_from_hex' uses the [<src>_to_<dst>] / [<dst>_from_<src>] form; OCaml convention is 'bytes_of_hex' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬──────────────────────────────────────╮
  │ Category           │ Issues                               │
  ├────────────────────┼──────────────────────────────────────┤
  │ Naming Conventions │ 5 (5 prefer _of_ over _to_ / _from_) │
  ╰────────────────────┴──────────────────────────────────────╯
  
  
  Summary: ✗ 5 total issues (applied 1 rule)
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



