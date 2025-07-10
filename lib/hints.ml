(** Hints for fixing different types of issues *)

open Issue_type

(** Get a short title for a specific issue type *)
let get_hint_title = function
  | Complexity -> "High Cyclomatic Complexity"
  | Function_length -> "Long Functions"
  | Deep_nesting -> "Deep Nesting"
  | Obj_magic -> "Unsafe Type Casting"
  | Catch_all_exception -> "Catch-All Exception Handlers"
  | Str_module -> "Outdated Str Module"
  | Printf_module -> "Outdated Printf/Format Modules"
  | Variant_naming -> "Variant Naming Convention"
  | Module_naming -> "Module Naming Convention"
  | Value_naming -> "Value Naming Convention"
  | Type_naming -> "Type Naming Convention"
  | Long_identifier -> "Long Identifier Names"
  | Function_naming -> "Function Naming Pattern"
  | Missing_mli_doc -> "Missing Module Documentation"
  | Missing_value_doc -> "Missing Value Documentation"
  | Bad_doc_style -> "Documentation Style Issues"
  | Missing_standard_function -> "Missing Standard Functions"
  | Missing_ocamlformat_file -> "Missing Code Formatter"
  | Missing_mli_file -> "Missing Interface Files"
  | Test_exports_module -> "Test Module Convention"
  | Silenced_warning -> "Silenced Compiler Warnings"
  | Missing_test_file -> "Missing Test Coverage"
  | Test_without_library -> "Orphaned Test Files"
  | Test_suite_not_included -> "Excluded Test Suites"

(** Get a hint for a specific issue type *)
let get_hint = function
  | Complexity ->
      Some
        "This issue means your functions have too much conditional logic. Fix \
         them by extracting complex logic into smaller helper functions with \
         clear names that describe their purpose."
  | Function_length ->
      Some
        "This issue means your functions are too long and hard to read. Fix \
         them by extracting logical sections into separate functions with \
         descriptive names. Aim for functions under 50 lines."
  | Deep_nesting ->
      Some
        "This issue means your code has too many nested conditions making it \
         hard to follow. Fix it by using pattern matching, early returns with \
         'when' guards, or extracting nested logic into helper functions."
  | Obj_magic ->
      Some
        "This issue means you're using unsafe type casting that can crash your \
         program. Fix it by replacing Obj.magic with proper type definitions, \
         variant types, or GADTs to represent different cases safely."
  | Catch_all_exception ->
      Some
        "This issue means you're catching all exceptions which can hide bugs. \
         Fix it by replacing catch-all handlers with specific exception \
         patterns and add explicit handlers for each expected exception type."
  | Str_module ->
      Some
        "This issue means you're using the outdated Str module for regular \
         expressions. Fix it by switching to the modern Re module: add 're' to \
         your dune dependencies and replace Str functions with Re equivalents."
  | Printf_module ->
      Some
        "This issue means you're using outdated Printf/Format modules for \
         formatting. Fix it by switching to the modern Fmt module: add 'fmt' \
         to your dune dependencies and replace Printf/Format functions with \
         Fmt equivalents."
  | Variant_naming ->
      Some
        "This issue means your variant constructors don't follow OCaml naming \
         conventions. Fix them by renaming to Snake_case (e.g., MyVariant → \
         My_variant)."
  | Module_naming ->
      Some
        "This issue means your module names don't follow OCaml naming \
         conventions. Fix them by renaming to Snake_case (e.g., MyModule → \
         My_module)."
  | Value_naming ->
      Some
        "This issue means your value names don't follow OCaml naming \
         conventions. Fix them by renaming to snake_case (e.g., myValue → \
         my_value)."
  | Type_naming ->
      Some
        "This issue means your type names don't follow OCaml naming \
         conventions. Fix them by renaming to snake_case (e.g., myType → \
         my_type)."
  | Long_identifier ->
      Some
        "This issue means some of your names are too long and hard to read. \
         Fix them by replacing them with shorter, meaningful names. Avoid \
         unnecessary prefixes or suffixes (especially if they repeat the \
         module name)."
  | Function_naming ->
      Some
        "This issue means your function names don't match their return types. \
         Fix them by using consistent naming: get_* for extraction (returns \
         value directly), find_* for search (returns option type)."
  | Missing_mli_doc ->
      Some
        "This issue means your modules lack documentation making them hard to \
         understand. Fix it by adding module documentation at the top of .mli \
         files with a brief summary and description of the module's purpose."
  | Missing_value_doc ->
      Some
        "This issue means your public functions and values lack documentation \
         making them hard to use. Fix it by adding documentation comments that \
         explain what each function does, its parameters, and return value."
  | Bad_doc_style ->
      Some
        "This issue means your documentation doesn't follow OCaml conventions \
         making it inconsistent. Fix it by following the standard OCaml \
         documentation format with proper syntax and structure."
  | Missing_standard_function ->
      Some
        "This issue means your types lack standard functions making them hard \
         to use in collections and debugging. Fix it by implementing equal, \
         compare, pp (pretty-printer), and to_string functions for your types."
  | Missing_ocamlformat_file ->
      Some
        "This issue means your project lacks consistent code formatting. Fix \
         it by creating a .ocamlformat file in your project root with 'profile \
         = default' and a version number to ensure consistent formatting."
  | Missing_mli_file ->
      Some
        "This issue means your modules lack interface files making their \
         public API unclear. Fix it by creating .mli files that document which \
         functions and types should be public. Copy public signatures from the \
         .ml file and remove private ones."
  | Test_exports_module ->
      Some
        "This issue means your test files don't follow the expected convention \
         for test organization. Fix it by exporting a 'suite' value instead of \
         running tests directly, allowing better test composition and \
         organization."
  | Silenced_warning ->
      Some
        "This issue means you're hiding compiler warnings that indicate \
         potential problems. Fix it by removing warning silencing attributes \
         and addressing the underlying issues that trigger the warnings."
  | Missing_test_file ->
      Some
        "This issue means some of your library modules lack test coverage \
         making bugs more likely. Fix it by creating corresponding test files \
         for each library module to ensure your code works correctly."
  | Test_without_library ->
      Some
        "This issue means you have test files that don't correspond to any \
         library module making your test organization confusing. Fix it by \
         either removing orphaned test files or creating the corresponding \
         library modules."
  | Test_suite_not_included ->
      Some
        "This issue means some test suites aren't included in your main test \
         runner so they never get executed. Fix it by adding them to the main \
         test runner to ensure all tests are run during development."
