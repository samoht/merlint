(** Single source of truth for all linting rules data *)

open Issue_type
open Rule

(* All rules data - single source of truth *)
let all_rules =
  [
    (* Complexity Rules *)
    Rule.v ~issue:Complexity ~title:"High Cyclomatic Complexity"
      ~category:Complexity
      ~examples:
        [ Rule.bad Examples.E001.bad_ml; Rule.good Examples.E001.good_ml ]
      {|This issue means your functions have too much conditional logic. Fix them
by extracting complex logic into smaller helper functions with clear names
that describe their purpose.|};
    Rule.v ~issue:Function_length ~title:"Long Functions" ~category:Complexity
      ~examples:
        [ Rule.bad Examples.E005.bad_ml; Rule.good Examples.E005.good_ml ]
      {|This issue means your functions are too long and hard to read. Fix them by
extracting logical sections into separate functions with descriptive names.
Note: Functions with pattern matching get additional allowance (2 lines per case).
Pure data structures (lists, records) are also exempt from length checks.
For better readability, consider using helper functions for complex logic.
Aim for functions under 50 lines of actual logic.|};
    Rule.v ~issue:Deep_nesting ~title:"Deep Nesting" ~category:Complexity
      ~examples:
        [ Rule.bad Examples.E010.bad_ml; Rule.good Examples.E010.good_ml ]
      {|This issue means your code has too many nested conditions making it hard to
follow. Fix it by using pattern matching, early returns with 'when' guards,
or extracting nested logic into helper functions.|};
    (* Security/Safety Rules *)
    Rule.v ~issue:Obj_magic ~title:"Unsafe Type Casting"
      ~category:Security_safety
      ~examples:
        [ Rule.bad Examples.E100.bad_ml; Rule.good Examples.E100.good_ml ]
      {|This issue means you're using unsafe type casting that can crash your
program. Fix it by replacing Obj.magic with proper type definitions,
variant types, or GADTs to represent different cases safely.|};
    Rule.v ~issue:Catch_all_exception ~title:"Catch-all Exception Handler"
      ~category:Security_safety
      ~examples:
        [ Rule.bad Examples.E105.bad_ml; Rule.good Examples.E105.good_ml ]
      {|This issue means you're catching all exceptions with a wildcard pattern,
which can hide unexpected errors and make debugging difficult. Fix it by
handling specific exceptions explicitly. If you must catch all exceptions,
at least log them before re-raising or handling.|};
    Rule.v ~issue:Silenced_warning ~title:"Silenced Compiler Warnings"
      ~category:Security_safety
      ~examples:
        [ Rule.bad Examples.E110.bad_ml; Rule.good Examples.E110.good_ml ]
      {|This issue means you're hiding compiler warnings that indicate potential
problems. Fix it by removing warning silencing attributes and addressing
the underlying issues that trigger the warnings.|};
    (* Style/Modernization Rules *)
    Rule.v ~issue:Str_module ~title:"Outdated Str Module"
      ~category:Style_modernization
      ~examples:
        [ Rule.bad Examples.E200.bad_ml; Rule.good Examples.E200.good_ml ]
      {|This issue means you're using the outdated Str module for regular
expressions. Fix it by switching to the modern Re module: add 're' to your
dune dependencies and replace Str functions with Re equivalents.|};
    Rule.v ~issue:Printf_module ~title:"Consider Using Fmt Module"
      ~category:Style_modernization
      ~examples:
        [ Rule.bad Examples.E205.bad_ml; Rule.good Examples.E205.good_ml ]
      {|This is a style suggestion. While Printf and Format are part of OCaml's
standard library and perfectly fine to use, the Fmt library offers additional
features like custom formatters and better composability. Consider using Fmt
for new code, but Printf/Format remain valid choices for many use cases.|};
    (* Naming Convention Rules *)
    Rule.v ~issue:Variant_naming ~title:"Variant Naming Convention"
      ~category:Naming_conventions
      ~examples:
        [ Rule.bad Examples.E300.bad_ml; Rule.good Examples.E300.good_ml ]
      {|This issue means your variant constructors don't follow OCaml naming
conventions. Fix them by renaming to Snake_case (e.g., MyVariant →
My_variant).|};
    Rule.v ~issue:Module_naming ~title:"Module Naming Convention"
      ~category:Naming_conventions
      ~examples:
        [ Rule.bad Examples.E305.bad_ml; Rule.good Examples.E305.good_ml ]
      {|This issue means your module names don't follow OCaml naming conventions.
Fix them by using underscores between words while keeping the first letter capitalized (e.g., MyModule → My_module).|};
    Rule.v ~issue:Value_naming ~title:"Value Naming Convention"
      ~category:Naming_conventions
      ~examples:
        [ Rule.bad Examples.E310.bad_ml; Rule.good Examples.E310.good_ml ]
      {|This issue means your value names don't follow OCaml naming conventions.
Fix them by renaming to snake_case (e.g., myValue → my_value).|};
    Rule.v ~issue:Type_naming ~title:"Type Naming Convention"
      ~category:Naming_conventions
      ~examples:
        [ Rule.bad Examples.E315.bad_ml; Rule.good Examples.E315.good_ml ]
      {|This issue means your type names don't follow OCaml naming conventions. Fix
them by renaming to snake_case (e.g., myType → my_type).|};
    Rule.v ~issue:Long_identifier ~title:"Long Identifier Names"
      ~category:Naming_conventions
      ~examples:
        [ Rule.bad Examples.E320.bad_ml; Rule.good Examples.E320.good_ml ]
      {|This issue means your identifier has too many underscores (more than 4) making it hard to
read. Fix it by removing redundant prefixes and suffixes:

• In test files: remove 'test_' prefix (e.g., test_check_foo → check_foo or
  just foo)
• In hint files: remove '_hint' suffix (e.g., complexity_hint → complexity)
• In modules: remove '_module' suffix (e.g., parser_module → parser)
• Remove redundant words that repeat the context (e.g., check_mli_doc →
  check_mli)

The file/module context already makes the purpose clear.|};
    Rule.v ~issue:Function_naming ~title:"Function Naming Pattern"
      ~category:Naming_conventions
      ~examples:
        [ Rule.bad Examples.E325.bad_ml; Rule.good Examples.E325.good_ml ]
      {|This issue means your function names don't match their return types. Fix
them by using consistent naming: get_* for extraction (returns value
directly), find_* for search (returns option type).|};
    Rule.v ~issue:Redundant_module_name ~title:"Redundant Module Names"
      ~category:Naming_conventions
      ~examples:
        [ Rule.bad Examples.E330.bad_ml; Rule.good Examples.E330.good_ml ]
      {|This issue means your function or type name redundantly includes the module
name. Fix it by removing the redundant prefix since the module context is
already clear from usage.|};
    Rule.v ~issue:Used_underscore_binding
      ~title:"Used Underscore-Prefixed Binding" ~category:Naming_conventions
      ~examples:
        [ Rule.bad Examples.E335.bad_ml; Rule.good Examples.E335.good_ml ]
      {|This issue means a binding prefixed with underscore (indicating it should be
unused) is actually used in the code. Fix it by removing the underscore prefix
to clearly indicate the binding is intentionally used.|};
    Rule.v ~issue:Boolean_blindness ~title:"Boolean Blindness"
      ~category:Naming_conventions
      ~examples:
        [ Rule.bad Examples.E350.bad_ml; Rule.good Examples.E350.good_ml ]
      {|This issue means your function has multiple boolean parameters, making call
sites ambiguous and error-prone. Fix it by using explicit variant types that
leverage OCaml's type system for clarity and safety.|};
    Rule.v ~issue:Error_pattern ~title:"Inline Error Construction"
      ~category:Style_modernization
      ~examples:
        [ Rule.bad Examples.E340.bad_ml; Rule.good Examples.E340.good_ml ]
      {|This issue means you're constructing errors inline instead of using helper
functions. Fix by defining err_* functions at the top of your file for each
error case. This promotes consistency, enables easy error message updates, and
makes error handling patterns clearer.|};
    Rule.v ~issue:Mutable_state ~title:"Global Mutable State"
      ~category:Style_modernization
      ~examples:
        [ Rule.bad Examples.E351.bad_ml; Rule.good Examples.E351.good_ml ]
      {|This issue warns about global mutable state which makes code harder to test
and reason about. Local mutable state within functions is perfectly acceptable
in OCaml. Fix by either using local refs within functions, or preferably by
using functional approaches with explicit state passing.|};
    (* Documentation Rules *)
    Rule.v ~issue:Missing_mli_doc ~title:"Missing Module Documentation"
      ~category:Documentation
      ~examples:
        [ Rule.bad Examples.E400.bad_ml; Rule.good Examples.E400.good_ml ]
      {|This issue means your modules lack documentation making them hard to
understand. Fix it by adding module documentation at the top of .mli files
with a brief summary and description of the module's purpose.|};
    Rule.v ~issue:Missing_value_doc ~title:"Missing Value Documentation"
      ~category:Documentation
      ~examples:
        [ Rule.bad Examples.E405.bad_mli; Rule.good Examples.E405.good_mli ]
      {|This issue means your public functions and values lack documentation making
them hard to use. Fix it by adding documentation comments that explain what
each function does, its parameters, and return value.|};
    Rule.v ~issue:Bad_doc_style ~title:"Documentation Style Issues"
      ~category:Documentation
      ~examples:
        [ Rule.bad Examples.E410.bad_mli; Rule.good Examples.E410.good_mli ]
      {|This issue means your documentation doesn't follow OCaml conventions making
it inconsistent. Fix it by following the standard OCaml documentation
format with proper syntax and structure.|};
    Rule.v ~issue:Missing_standard_function ~title:"Missing Standard Functions"
      ~category:Documentation
      ~examples:
        [ Rule.bad Examples.E415.bad_mli; Rule.good Examples.E415.good_mli ]
      {|This issue means your types lack standard functions making them hard to use
in collections and debugging. Fix it by implementing equal, compare, pp
(pretty-printer), and to_string functions for your types.|};
    (* Project Structure Rules *)
    Rule.v ~issue:Missing_ocamlformat_file ~title:"Missing Code Formatter"
      ~category:Project_structure
      ~examples:
        [ Rule.bad Examples.E500.bad_ml; Rule.good Examples.E500.good_ml ]
      {|This issue means your project lacks consistent code formatting. Fix it by
creating a .ocamlformat file in your project root with 'profile = default'
and a version number to ensure consistent formatting.|};
    Rule.v ~issue:Missing_mli_file ~title:"Missing Interface Files"
      ~category:Project_structure
      ~examples:
        [ Rule.bad Examples.E505.bad_ml; Rule.good Examples.E505.good_ml ]
      {|This issue means your modules lack interface files making their public API
unclear. Fix it by creating .mli files that document which functions and
types should be public. Copy public signatures from the .ml file and remove
private ones.|};
    (* Testing Rules *)
    Rule.v ~issue:Test_exports_module ~title:"Test Module Convention"
      ~category:Testing
      ~examples:
        [ Rule.bad Examples.E600.bad_ml; Rule.good Examples.E600.good_ml ]
      {|This issue means your test files don't follow the expected convention for
test organization. Fix it by exporting a 'suite' value instead of running
tests directly, allowing better test composition and organization.|};
    Rule.v ~issue:Missing_test_file ~title:"Missing Test Coverage"
      ~category:Testing
      ~examples:
        [ Rule.bad Examples.E605.bad_ml; Rule.good Examples.E605.good_ml ]
      {|This issue means some of your library modules lack test coverage making
bugs more likely. Fix it by creating corresponding test files for each
library module to ensure your code works correctly.|};
    Rule.v ~issue:Test_without_library ~title:"Orphaned Test Files"
      ~category:Testing
      ~examples:
        [ Rule.bad Examples.E610.bad_ml; Rule.good Examples.E610.good_ml ]
      {|This issue means you have test files that don't correspond to any library
module making your test organization confusing. Fix it by either removing
orphaned test files or creating the corresponding library modules.|};
    Rule.v ~issue:Test_suite_not_included ~title:"Excluded Test Suites"
      ~category:Testing
      ~examples:
        [ Rule.bad Examples.E615.bad_ml; Rule.good Examples.E615.good_ml ]
      {|This issue means some test suites aren't included in your main test runner
so they never get executed. Fix it by adding them to the main test runner
to ensure all tests are run during development.|};
    (* Logging Rules *)
    Rule.v ~issue:Missing_log_source ~title:"Missing Log Source"
      ~category:Project_structure
      ~examples:
        [ Rule.bad Examples.E510.bad_ml; Rule.good Examples.E510.good_ml ]
      {|This issue means your module lacks a dedicated log source, making it harder
to filter and control logging output. Fix it by defining a log source at the
top of each module using Logs.Src.create with a hierarchical name.|};
  ]
