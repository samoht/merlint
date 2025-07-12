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
        [
          bad
            {|let process_data data user =
  if data.valid then
    if user.authenticated then
      if data.size < 1000 then
        if has_permission user data then
          (* complex processing logic *)
        else Error "No permission"
      else Error "Data too large"
    else Error "Not authenticated"
  else Error "Invalid data"|};
          good
            {|let validate_data data = 
  if not data.valid then Error "Invalid data" else Ok ()

let check_auth user = 
  if not user.authenticated then Error "Not authenticated" else Ok ()

let check_size data = 
  if data.size >= 1000 then Error "Data too large" else Ok ()

let check_permission user data = 
  if not (has_permission user data) then Error "No permission" else Ok ()

let process_data data user =
  let open Result.Syntax in
  let* () = validate_data data in
  let* () = check_auth user in
  let* () = check_size data in
  let* () = check_permission user data in
  (* complex processing logic *)|};
        ]
      {|This issue means your functions have too much conditional logic. Fix them
by extracting complex logic into smaller helper functions with clear names
that describe their purpose.|};
    Rule.v ~issue:Function_length ~title:"Long Functions" ~category:Complexity
      {|This issue means your functions are too long and hard to read. Fix them by
extracting logical sections into separate functions with descriptive names.
Note: Functions with pattern matching get additional allowance (2 lines per case).
Pure data structures (lists, records) are also exempt from length checks.
For better readability, consider using helper functions for complex logic.
Aim for functions under 50 lines of actual logic.|};
    Rule.v ~issue:Deep_nesting ~title:"Deep Nesting" ~category:Complexity
      {|This issue means your code has too many nested conditions making it hard to
follow. Fix it by using pattern matching, early returns with 'when' guards,
or extracting nested logic into helper functions.|};
    (* Security/Safety Rules *)
    Rule.v ~issue:Obj_magic ~title:"Unsafe Type Casting"
      ~category:Security_safety
      {|This issue means you're using unsafe type casting that can crash your
program. Fix it by replacing Obj.magic with proper type definitions,
variant types, or GADTs to represent different cases safely.|};
    Rule.v ~issue:Catch_all_exception ~title:"Catch-All Exception Handlers"
      ~category:Security_safety
      {|This issue means you're catching all exceptions which can hide bugs. Fix it
by replacing catch-all handlers with specific exception patterns and add
explicit handlers for each expected exception type.|};
    Rule.v ~issue:Silenced_warning ~title:"Silenced Compiler Warnings"
      ~category:Security_safety
      {|This issue means you're hiding compiler warnings that indicate potential
problems. Fix it by removing warning silencing attributes and addressing
the underlying issues that trigger the warnings.|};
    (* Style/Modernization Rules *)
    Rule.v ~issue:Str_module ~title:"Outdated Str Module"
      ~category:Style_modernization
      {|This issue means you're using the outdated Str module for regular
expressions. Fix it by switching to the modern Re module: add 're' to your
dune dependencies and replace Str functions with Re equivalents.|};
    Rule.v ~issue:Printf_module ~title:"Outdated Printf/Format Modules"
      ~category:Style_modernization
      ~examples:
        [
          bad
            {|let error_msg = Printf.sprintf "Error: %s at line %d" msg line
let () = Printf.printf "Processing %d items...\n" count|};
          good
            {|let error_msg = Fmt.str "Error: %s at line %d" msg line
let () = Fmt.pr "Processing %d items...@." count

(* Even better with custom formatters *)
let pp_error ppf (msg, line) = 
  Fmt.pf ppf "Error: %s at line %d" msg line|};
        ]
      {|This issue means you're using outdated Printf/Format modules for
formatting. Fix it by switching to the modern Fmt module: add 'fmt' to your
dune dependencies and replace Printf/Format functions with Fmt
equivalents.|};
    (* Naming Convention Rules *)
    Rule.v ~issue:Variant_naming ~title:"Variant Naming Convention"
      ~category:Naming_conventions
      ~examples:
        [
          bad
            {|type status = 
  | WaitingForInput    (* CamelCase *)
  | ProcessingData
  | errorOccurred      (* lowerCamelCase *)|};
          good
            {|type status = 
  | Waiting_for_input  (* Snake_case *)
  | Processing_data
  | Error_occurred|};
        ]
      {|This issue means your variant constructors don't follow OCaml naming
conventions. Fix them by renaming to Snake_case (e.g., MyVariant →
My_variant).|};
    Rule.v ~issue:Module_naming ~title:"Module Naming Convention"
      ~category:Naming_conventions
      {|This issue means your module names don't follow OCaml naming conventions.
Fix them by renaming to lowercase_with_underscores (e.g., MyModule → my_module).|};
    Rule.v ~issue:Value_naming ~title:"Value Naming Convention"
      ~category:Naming_conventions
      {|This issue means your value names don't follow OCaml naming conventions.
Fix them by renaming to snake_case (e.g., myValue → my_value).|};
    Rule.v ~issue:Type_naming ~title:"Type Naming Convention"
      ~category:Naming_conventions
      {|This issue means your type names don't follow OCaml naming conventions. Fix
them by renaming to snake_case (e.g., myType → my_type).|};
    Rule.v ~issue:Long_identifier ~title:"Long Identifier Names"
      ~category:Naming_conventions
      {|This issue means your identifier has too many underscores making it hard to
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
      {|This issue means your function names don't match their return types. Fix
them by using consistent naming: get_* for extraction (returns value
directly), find_* for search (returns option type).|};
    Rule.v ~issue:Redundant_module_name ~title:"Redundant Module Names"
      ~category:Naming_conventions
      ~examples:
        [
          bad
            {|(* In process.ml *)
let process_start () = ...
let process_stop () = ...
type process_config = ...|};
          good
            {|(* In process.ml *)
let start () = ...
let stop () = ...
type config = ...
(* Usage: Process.start (), Process.config *)|};
        ]
      {|This issue means your function or type name redundantly includes the module
name. Fix it by removing the redundant prefix since the module context is
already clear from usage.|};
    Rule.v ~issue:Used_underscore_binding
      ~title:"Used Underscore-Prefixed Binding" ~category:Naming_conventions
      ~examples:
        [
          bad
            {|let _debug_mode = true in
if _debug_mode then
  print_endline "Debug mode enabled"|};
          good
            {|let debug_mode = true in
if debug_mode then
  print_endline "Debug mode enabled"|};
        ]
      {|This issue means a binding prefixed with underscore (indicating it should be
unused) is actually used in the code. Fix it by removing the underscore prefix
to clearly indicate the binding is intentionally used.|};
    (* Documentation Rules *)
    Rule.v ~issue:Missing_mli_doc ~title:"Missing Module Documentation"
      ~category:Documentation
      {|This issue means your modules lack documentation making them hard to
understand. Fix it by adding module documentation at the top of .mli files
with a brief summary and description of the module's purpose.|};
    Rule.v ~issue:Missing_value_doc ~title:"Missing Value Documentation"
      ~category:Documentation
      {|This issue means your public functions and values lack documentation making
them hard to use. Fix it by adding documentation comments that explain what
each function does, its parameters, and return value.|};
    Rule.v ~issue:Bad_doc_style ~title:"Documentation Style Issues"
      ~category:Documentation
      {|This issue means your documentation doesn't follow OCaml conventions making
it inconsistent. Fix it by following the standard OCaml documentation
format with proper syntax and structure.|};
    Rule.v ~issue:Missing_standard_function ~title:"Missing Standard Functions"
      ~category:Documentation
      {|This issue means your types lack standard functions making them hard to use
in collections and debugging. Fix it by implementing equal, compare, pp
(pretty-printer), and to_string functions for your types.|};
    (* Project Structure Rules *)
    Rule.v ~issue:Missing_ocamlformat_file ~title:"Missing Code Formatter"
      ~category:Project_structure
      {|This issue means your project lacks consistent code formatting. Fix it by
creating a .ocamlformat file in your project root with 'profile = default'
and a version number to ensure consistent formatting.|};
    Rule.v ~issue:Missing_mli_file ~title:"Missing Interface Files"
      ~category:Project_structure
      {|This issue means your modules lack interface files making their public API
unclear. Fix it by creating .mli files that document which functions and
types should be public. Copy public signatures from the .ml file and remove
private ones.|};
    (* Testing Rules *)
    Rule.v ~issue:Test_exports_module ~title:"Test Module Convention"
      ~category:Testing
      {|This issue means your test files don't follow the expected convention for
test organization. Fix it by exporting a 'suite' value instead of running
tests directly, allowing better test composition and organization.|};
    Rule.v ~issue:Missing_test_file ~title:"Missing Test Coverage"
      ~category:Testing
      {|This issue means some of your library modules lack test coverage making
bugs more likely. Fix it by creating corresponding test files for each
library module to ensure your code works correctly.|};
    Rule.v ~issue:Test_without_library ~title:"Orphaned Test Files"
      ~category:Testing
      {|This issue means you have test files that don't correspond to any library
module making your test organization confusing. Fix it by either removing
orphaned test files or creating the corresponding library modules.|};
    Rule.v ~issue:Test_suite_not_included ~title:"Excluded Test Suites"
      ~category:Testing
      {|This issue means some test suites aren't included in your main test runner
so they never get executed. Fix it by adding them to the main test runner
to ensure all tests are run during development.|};
  ]
