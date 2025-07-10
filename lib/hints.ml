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

(** Helper functions for individual hints *)

let complexity_hint () =
  "This issue means your functions have too much conditional logic. Fix them \
   by extracting complex logic into smaller helper functions with clear names \
   that describe their purpose."

let function_length_hint () =
  "This issue means your functions are too long and hard to read. Fix them by \
   extracting logical sections into separate functions with descriptive names. \
   Note: Large pattern matching blocks are acceptable - functions with pattern \
   matching get double the line limit when they have more than 10 cases. For \
   better readability, consider using a helper function for each complex case. \
   Aim for functions under 50 lines otherwise."

let deep_nesting_hint () =
  "This issue means your code has too many nested conditions making it hard to \
   follow. Fix it by using pattern matching, early returns with 'when' guards, \
   or extracting nested logic into helper functions."

let obj_magic_hint () =
  "This issue means you're using unsafe type casting that can crash your \
   program. Fix it by replacing Obj.magic with proper type definitions, \
   variant types, or GADTs to represent different cases safely."

let catch_all_exception_hint () =
  "This issue means you're catching all exceptions which can hide bugs. Fix it \
   by replacing catch-all handlers with specific exception patterns and add \
   explicit handlers for each expected exception type."

let str_module_hint () =
  "This issue means you're using the outdated Str module for regular \
   expressions. Fix it by switching to the modern Re module: add 're' to your \
   dune dependencies and replace Str functions with Re equivalents."

let printf_module_hint () =
  "This issue means you're using outdated Printf/Format modules for \
   formatting. Fix it by switching to the modern Fmt module: add 'fmt' to your \
   dune dependencies and replace Printf/Format functions with Fmt equivalents."

let silenced_warning_hint () =
  "This issue means you're hiding compiler warnings that indicate potential \
   problems. Fix it by removing warning silencing attributes and addressing \
   the underlying issues that trigger the warnings."

let variant_naming_hint () =
  "This issue means your variant constructors don't follow OCaml naming \
   conventions. Fix them by renaming to Snake_case (e.g., MyVariant → \
   My_variant)."

let module_naming_hint () =
  "This issue means your module names don't follow OCaml naming conventions. \
   Fix them by renaming to Snake_case (e.g., MyModule → My_module)."

let value_naming_hint () =
  "This issue means your value names don't follow OCaml naming conventions. \
   Fix them by renaming to snake_case (e.g., myValue → my_value)."

let type_naming_hint () =
  "This issue means your type names don't follow OCaml naming conventions. Fix \
   them by renaming to snake_case (e.g., myType → my_type)."

let long_identifier_hint () =
  "This issue means your identifier has too many underscores making it hard to \
   read. Fix it by removing redundant prefixes and suffixes:\n\n\
   • In test files: remove 'test_' prefix (e.g., test_check_foo → check_foo or \
   just foo)\n\
   • In hint files: remove '_hint' suffix (e.g., complexity_hint → complexity)\n\
   • In modules: remove '_module' suffix (e.g., parser_module → parser)\n\
   • Remove redundant words that repeat the context (e.g., \
   test_check_mli_files_with_doc → mli_with_doc)\n\n\
   The file/module context already makes the purpose clear."

let function_naming_hint () =
  "This issue means your function names don't match their return types. Fix \
   them by using consistent naming: get_* for extraction (returns value \
   directly), find_* for search (returns option type)."

let missing_mli_doc_hint () =
  "This issue means your modules lack documentation making them hard to \
   understand. Fix it by adding module documentation at the top of .mli files \
   with a brief summary and description of the module's purpose."

let missing_value_doc_hint () =
  "This issue means your public functions and values lack documentation making \
   them hard to use. Fix it by adding documentation comments that explain what \
   each function does, its parameters, and return value."

let bad_doc_style_hint () =
  "This issue means your documentation doesn't follow OCaml conventions making \
   it inconsistent. Fix it by following the standard OCaml documentation \
   format with proper syntax and structure."

let missing_standard_function_hint () =
  "This issue means your types lack standard functions making them hard to use \
   in collections and debugging. Fix it by implementing equal, compare, pp \
   (pretty-printer), and to_string functions for your types."

let missing_ocamlformat_file_hint () =
  "This issue means your project lacks consistent code formatting. Fix it by \
   creating a .ocamlformat file in your project root with 'profile = default' \
   and a version number to ensure consistent formatting."

let missing_mli_file_hint () =
  "This issue means your modules lack interface files making their public API \
   unclear. Fix it by creating .mli files that document which functions and \
   types should be public. Copy public signatures from the .ml file and remove \
   private ones."

let test_exports_module_hint () =
  "This issue means your test files don't follow the expected convention for \
   test organization. Fix it by exporting a 'suite' value instead of running \
   tests directly, allowing better test composition and organization."

let missing_test_file_hint () =
  "This issue means some of your library modules lack test coverage making \
   bugs more likely. Fix it by creating corresponding test files for each \
   library module to ensure your code works correctly."

let test_without_library_hint () =
  "This issue means you have test files that don't correspond to any library \
   module making your test organization confusing. Fix it by either removing \
   orphaned test files or creating the corresponding library modules."

let test_suite_excluded_hint () =
  "This issue means some test suites aren't included in your main test runner \
   so they never get executed. Fix it by adding them to the main test runner \
   to ensure all tests are run during development."

(** Get a hint for a specific issue type *)
let get_hint = function
  | Complexity -> complexity_hint ()
  | Function_length -> function_length_hint ()
  | Deep_nesting -> deep_nesting_hint ()
  | Obj_magic -> obj_magic_hint ()
  | Catch_all_exception -> catch_all_exception_hint ()
  | Str_module -> str_module_hint ()
  | Printf_module -> printf_module_hint ()
  | Silenced_warning -> silenced_warning_hint ()
  | Variant_naming -> variant_naming_hint ()
  | Module_naming -> module_naming_hint ()
  | Value_naming -> value_naming_hint ()
  | Type_naming -> type_naming_hint ()
  | Long_identifier -> long_identifier_hint ()
  | Function_naming -> function_naming_hint ()
  | Missing_mli_doc -> missing_mli_doc_hint ()
  | Missing_value_doc -> missing_value_doc_hint ()
  | Bad_doc_style -> bad_doc_style_hint ()
  | Missing_standard_function -> missing_standard_function_hint ()
  | Missing_ocamlformat_file -> missing_ocamlformat_file_hint ()
  | Missing_mli_file -> missing_mli_file_hint ()
  | Test_exports_module -> test_exports_module_hint ()
  | Missing_test_file -> missing_test_file_hint ()
  | Test_without_library -> test_without_library_hint ()
  | Test_suite_not_included -> test_suite_excluded_hint ()
