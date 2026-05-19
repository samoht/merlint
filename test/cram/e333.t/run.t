Build fixture project:
  $ dune build @check

Test bad interface - should flag the standalone _to_ conversions but not action-verb names:
  $ merlint --build -r E333 bad.mli
  Dune root: $TESTCASE_ROOT/
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
    rule checks top-level declarations in [.ml] and [.mli] files. It only flags
    single-arrow functions ([T1 -> T2] with non-unit [T2]), so multi-argument
    actions ([add_to_set : 'a -> 'a list -> 'a list]) and writes-into-sink
    functions ([print_to_buffer : Buffer.t -> string -> unit]) are skipped by
    their type. Add domain-specific exceptions to [allowed_words].
    - bad.mli:1:0: Function 'int_to_string' uses a non-canonical conversion-naming form; OCaml convention is 'string_of_int' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.mli:2:0: Function 'bytes_to_hex' uses a non-canonical conversion-naming form; OCaml convention is 'hex_of_bytes' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.mli:3:0: Function 'path_to_uri' uses a non-canonical conversion-naming form; OCaml convention is 'uri_of_path' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.mli:4:0: Function 'value_from_string' uses a non-canonical conversion-naming form; OCaml convention is 'value_of_string' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.mli:5:0: Function 'bytes_from_hex' uses a non-canonical conversion-naming form; OCaml convention is 'bytes_of_hex' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.mli:9:0: Function 'int_of_t' uses a non-canonical conversion-naming form; OCaml convention is 'to_int' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.mli:10:0: Function 't_of_int' uses a non-canonical conversion-naming form; OCaml convention is 'of_int' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...).
    - bad.mli:11:0: Function 'to_pair' uses [to_<X>] but its source type is 'string', not [t]. Preferred fix: declare [type t = string] in this module so the function reads as [t -> X] (the canonical primary-type name, per [List.to_seq] / [Bytes.to_string]). Fallback: rename the function to 'pair_of_string' ([<dst>_of_<src>] form).
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
    Run `merlint help E333` for the rule's description, hint, and good/bad examples.
  [1]






Test good example - should find no issues:
  $ merlint --build -r E333 good.ml
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




Test the .mli directly: intra-public conventions, nested module, and a
parametric alias must all be accepted without flagging:
  $ merlint --build -r E333 good.mli
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




Implementation declarations are checked too.
  $ merlint --build -r E333 good.ml
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




  $ merlint --build -r E333 bad.ml
  Dune root: $TESTCASE_ROOT/
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
    rule checks top-level declarations in [.ml] and [.mli] files. It only flags
    single-arrow functions ([T1 -> T2] with non-unit [T2]), so multi-argument
    actions ([add_to_set : 'a -> 'a list -> 'a list]) and writes-into-sink
    functions ([print_to_buffer : Buffer.t -> string -> unit]) are skipped by
    their type. Add domain-specific exceptions to [allowed_words].
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
    Run `merlint help E333` for the rule's description, hint, and good/bad examples.
  [1]
