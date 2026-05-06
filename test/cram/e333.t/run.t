Test bad example - should flag the standalone _to_ conversions but not action-verb names:
  $ merlint -B -r E333 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (3 total issues)
    [E333] Prefer _of_ over _to_ (3 issues)
    Standalone conversion functions in OCaml use the [<dst>_of_<src>] form
    ([int_of_string], [string_of_float], ...) — never [<src>_to_<dst>]. The
    convention reads as 'an X out of a Y' and matches the stdlib precedent.
    Module-method conversions ([Bytes.to_string], [Bytes.of_string]) are
    unaffected: the rule only flags identifiers that contain [_to_] inside the
    name itself, and skips action-verb prefixes ([add_to_set], [walk_to_root],
    [print_to_buffer], etc.). Add domain-specific exceptions to [allowed_words].
    - bad.ml:3:0: Function 'int_to_string' uses the [<src>_to_<dst>] form; OCaml convention is 'string_of_int' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...)
    - bad.ml:5:0: Function 'bytes_to_hex' uses the [<src>_to_<dst>] form; OCaml convention is 'hex_of_bytes' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...)
    - bad.ml:10:0: Function 'path_to_uri' uses the [<src>_to_<dst>] form; OCaml convention is 'uri_of_path' (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], ...)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬─────────────────────────────╮
  │ Category           │ Issues                      │
  ├────────────────────┼─────────────────────────────┤
  │ Naming Conventions │ 3 (3 prefer _of_ over _to_) │
  ╰────────────────────┴─────────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
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



