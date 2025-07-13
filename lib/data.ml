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
      ~examples:
        [
          bad
            {|let process_everything user data config =
  (* 100+ lines of mixed concerns: validation, processing, formatting *)
  let valid = check_user user && verify_data data in
  (* ... many more lines ... *)
  format_output result|};
          good
            {|let validate_inputs user data = 
  check_user user && verify_data data

let process_data data config = 
  (* focused processing logic *)

let process_everything user data config =
  let valid = validate_inputs user data in
  let result = process_data data config in
  format_output result|};
        ]
      {|This issue means your functions are too long and hard to read. Fix them by
extracting logical sections into separate functions with descriptive names.
Note: Functions with pattern matching get additional allowance (2 lines per case).
Pure data structures (lists, records) are also exempt from length checks.
For better readability, consider using helper functions for complex logic.
Aim for functions under 50 lines of actual logic.|};
    Rule.v ~issue:Deep_nesting ~title:"Deep Nesting" ~category:Complexity
      ~examples:
        [
          bad
            {|let process_order order user =
  if order.valid then
    if user.authenticated then
      if order.total > 0 then
        if check_inventory order then
          (* deeply nested logic *)
          process_payment order
        else Error "Out of stock"
      else Error "Invalid total"
    else Error "Not authenticated"
  else Error "Invalid order"|};
          good
            {|let process_order order user =
  if not order.valid then Error "Invalid order" else
  if not user.authenticated then Error "Not authenticated" else
  if order.total <= 0 then Error "Invalid total" else
  if not (check_inventory order) then Error "Out of stock" else
  process_payment order|};
        ]
      {|This issue means your code has too many nested conditions making it hard to
follow. Fix it by using pattern matching, early returns with 'when' guards,
or extracting nested logic into helper functions.|};
    (* Security/Safety Rules *)
    Rule.v ~issue:Obj_magic ~title:"Unsafe Type Casting"
      ~category:Security_safety
      ~examples:
        [
          bad {|let coerce x = Obj.magic x|};
          good
            {|(* Use proper type conversions *)
let int_of_string_opt s =
  try Some (int_of_string s) with _ -> None

(* Or use variant types *)
type value = Int of int | String of string
let to_int = function Int i -> Some i | _ -> None|};
        ]
      {|This issue means you're using unsafe type casting that can crash your
program. Fix it by replacing Obj.magic with proper type definitions,
variant types, or GADTs to represent different cases safely.|};
    Rule.v ~issue:Catch_all_exception ~title:"Underscore Pattern Warning"
      ~category:Security_safety
      ~examples:
        [
          bad {|try risky_operation () with _ -> default_value|};
          good
            {|try risky_operation () with
| Not_found -> default_value  
| Invalid_argument _ -> error_value|};
        ]
      {|WARNING: This rule currently detects ANY underscore (_) pattern, not just 
exception handlers. This is a known limitation. The rule is intended to catch
dangerous patterns like 'try ... with _ ->' but currently flags all uses of _.
To avoid this warning, use named bindings with underscore prefix (e.g., _unused)
for intentionally unused values. This will be fixed in a future version.|};
    Rule.v ~issue:Silenced_warning ~title:"Silenced Compiler Warnings"
      ~category:Security_safety
      ~examples:
        [
          bad
            {|[@@@ocaml.warning "-32"] (* unused value *)
let unused_function x = x + 1|};
          good
            {|(* Remove unused code or use it *)
let helper x = x + 1
let result = helper 42|};
        ]
      {|This issue means you're hiding compiler warnings that indicate potential
problems. Fix it by removing warning silencing attributes and addressing
the underlying issues that trigger the warnings.|};
    (* Style/Modernization Rules *)
    Rule.v ~issue:Str_module ~title:"Outdated Str Module"
      ~category:Style_modernization
      ~examples:
        [
          bad {|let is_email s = 
  Str.string_match (Str.regexp ".*@.*") s 0|};
          good
            {|let email_re = Re.compile (Re.seq [Re.any; Re.char '@'; Re.any])
let is_email s = Re.execp email_re s|};
        ]
      {|This issue means you're using the outdated Str module for regular
expressions. Fix it by switching to the modern Re module: add 're' to your
dune dependencies and replace Str functions with Re equivalents.|};
    Rule.v ~issue:Printf_module ~title:"Consider Using Fmt Module"
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
      {|This is a style suggestion. While Printf and Format are part of OCaml's
standard library and perfectly fine to use, the Fmt library offers additional
features like custom formatters and better composability. Consider using Fmt
for new code, but Printf/Format remain valid choices for many use cases.|};
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
      ~examples:
        [
          bad {|module UserProfile = struct ... end|};
          good {|module User_profile = struct ... end|};
        ]
      {|This issue means your module names don't follow OCaml naming conventions.
Fix them by using underscores between words while keeping the first letter capitalized (e.g., MyModule → My_module).|};
    Rule.v ~issue:Value_naming ~title:"Value Naming Convention"
      ~category:Naming_conventions
      ~examples:
        [
          bad {|let myValue = 42
let getUserName user = user.name|};
          good {|let my_value = 42
let get_user_name user = user.name|};
        ]
      {|This issue means your value names don't follow OCaml naming conventions.
Fix them by renaming to snake_case (e.g., myValue → my_value).|};
    Rule.v ~issue:Type_naming ~title:"Type Naming Convention"
      ~category:Naming_conventions
      ~examples:
        [
          bad
            {|type userProfile = { name: string }
type HTTPResponse = Ok | Error|};
          good
            {|type user_profile = { name: string }
type http_response = Ok | Error|};
        ]
      {|This issue means your type names don't follow OCaml naming conventions. Fix
them by renaming to snake_case (e.g., myType → my_type).|};
    Rule.v ~issue:Long_identifier ~title:"Long Identifier Names"
      ~category:Naming_conventions
      ~examples:
        [
          bad {|let get_user_profile_data_from_database_by_id id = ...|};
          good {|let get_user_by_id id = ...|};
        ]
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
        [
          bad
            {|let get_user id = List.find_opt (fun u -> u.id = id) users
let find_name user = user.name|};
          good
            {|let find_user id = List.find_opt (fun u -> u.id = id) users  
let get_name user = user.name|};
        ]
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
    Rule.v ~issue:Boolean_blindness ~title:"Boolean Blindness"
      ~category:Naming_conventions
      ~examples:
        [
          bad
            {|let create_window visible resizable fullscreen =
  (* What do these booleans mean at the call site? *)
  ...
  
let w = create_window true false true|};
          good
            {|type visibility = Visible | Hidden
type window_mode = Windowed | Fullscreen
type resizable = Resizable | Fixed_size

let create_window ~visibility ~mode ~resizable =
  ...
  
let w = create_window ~visibility:Visible ~mode:Fullscreen ~resizable:Fixed_size|};
        ]
      {|This issue means your function has multiple boolean parameters, making call
sites ambiguous and error-prone. Fix it by using explicit variant types that
leverage OCaml's type system for clarity and safety.|};
    Rule.v ~issue:Error_pattern ~title:"Inline Error Construction"
      ~category:Style_modernization
      ~examples:
        [
          bad
            {|let process_data data =
  match validate data with
  | None -> Error (Fmt.str "Invalid data: %s" data.id)
  | Some v -> 
      if v.size > max_size then
        Error (Fmt.str "Data too large: %d" v.size)
      else Ok v|};
          good
            {|(* Define error helpers at the top of the file *)
let err_invalid_data id = Error (`Invalid_data id)
let err_fmt fmt = Fmt.kstr (fun msg -> Error (`Msg msg)) fmt

let process_data data =
  match validate data with
  | None -> err_invalid_data data.id
  | Some v -> 
      if v.size > max_size then
        err_fmt "Data too large: %d bytes" v.size
      else Ok v|};
        ]
      {|This issue means you're constructing errors inline instead of using helper
functions. Fix by defining err_* functions at the top of your file for each
error case. This promotes consistency, enables easy error message updates, and
makes error handling patterns clearer.|};
    Rule.v ~issue:Mutable_state ~title:"Global Mutable State"
      ~category:Style_modernization
      ~examples:
        [
          bad
            {|(* Global mutable state - avoid this *)
let counter = ref 0
let incr_counter () = counter := !counter + 1

let global_cache = Array.make 100 None
let cached_results = Hashtbl.create 100|};
          good
            {|(* Local mutable state is fine *)
let compute_sum lst =
  let sum = ref 0 in
  List.iter (fun x -> sum := !sum + x) lst;
  !sum

(* Or better, use functional approach *)
let compute_sum lst = List.fold_left (+) 0 lst

(* Pass state explicitly *)
let incr_counter counter = counter + 1|};
        ]
      {|This issue warns about global mutable state which makes code harder to test
and reason about. Local mutable state within functions is perfectly acceptable
in OCaml. Fix by either using local refs within functions, or preferably by
using functional approaches with explicit state passing.|};
    (* Documentation Rules *)
    Rule.v ~issue:Missing_mli_doc ~title:"Missing Module Documentation"
      ~category:Documentation
      ~examples:
        [
          bad {|(* user.mli - no module doc *)
val create : string -> t|};
          good
            {|(** User management module 
    
    Handles user creation and authentication. *)
val create : string -> t|};
        ]
      {|This issue means your modules lack documentation making them hard to
understand. Fix it by adding module documentation at the top of .mli files
with a brief summary and description of the module's purpose.|};
    Rule.v ~issue:Missing_value_doc ~title:"Missing Value Documentation"
      ~category:Documentation
      ~examples:
        [
          bad {|val parse : string -> t|};
          good
            {|(** [parse str] converts a string to type [t].
    @raise Invalid_argument if [str] is malformed. *)
val parse : string -> t|};
        ]
      {|This issue means your public functions and values lack documentation making
them hard to use. Fix it by adding documentation comments that explain what
each function does, its parameters, and return value.|};
    Rule.v ~issue:Bad_doc_style ~title:"Documentation Style Issues"
      ~category:Documentation
      ~examples:
        [
          bad {|(* this function parses strings *)
val parse : string -> t|};
          good
            {|(** [parse str] parses a string into type [t]. *)
val parse : string -> t|};
        ]
      {|This issue means your documentation doesn't follow OCaml conventions making
it inconsistent. Fix it by following the standard OCaml documentation
format with proper syntax and structure.|};
    Rule.v ~issue:Missing_standard_function ~title:"Missing Standard Functions"
      ~category:Documentation
      ~examples:
        [
          bad
            {|type user = { id: int; name: string }
(* No standard functions *)|};
          good
            {|type user = { id: int; name: string }
val equal : user -> user -> bool
val compare : user -> user -> int
val pp : Format.formatter -> user -> unit|};
        ]
      {|This issue means your types lack standard functions making them hard to use
in collections and debugging. Fix it by implementing equal, compare, pp
(pretty-printer), and to_string functions for your types.|};
    (* Project Structure Rules *)
    Rule.v ~issue:Missing_ocamlformat_file ~title:"Missing Code Formatter"
      ~category:Project_structure
      ~examples:
        [
          bad {|(* No .ocamlformat file in project root *)|};
          good {|(* .ocamlformat *)
profile = default
version = 0.26.2|};
        ]
      {|This issue means your project lacks consistent code formatting. Fix it by
creating a .ocamlformat file in your project root with 'profile = default'
and a version number to ensure consistent formatting.|};
    Rule.v ~issue:Missing_mli_file ~title:"Missing Interface Files"
      ~category:Project_structure
      ~examples:
        [
          bad {|(* Only user.ml exists, no user.mli *)|};
          good
            {|(* user.mli *)
type t
val create : string -> int -> t
val name : t -> string|};
        ]
      {|This issue means your modules lack interface files making their public API
unclear. Fix it by creating .mli files that document which functions and
types should be public. Copy public signatures from the .ml file and remove
private ones.|};
    (* Testing Rules *)
    Rule.v ~issue:Test_exports_module ~title:"Test Module Convention"
      ~category:Testing
      ~examples:
        [
          bad
            {|(* test_user.ml *)
let () = Alcotest.run "tests" [("user", tests)]|};
          good {|(* test_user.ml *)
let suite = ("user", tests)|};
        ]
      {|This issue means your test files don't follow the expected convention for
test organization. Fix it by exporting a 'suite' value instead of running
tests directly, allowing better test composition and organization.|};
    Rule.v ~issue:Missing_test_file ~title:"Missing Test Coverage"
      ~category:Testing
      ~examples:
        [
          bad {|(* lib/parser.ml exists but no test/test_parser.ml *)|};
          good
            {|(* test/test_parser.ml *)
let suite = ("parser", [test_parse; test_errors])|};
        ]
      {|This issue means some of your library modules lack test coverage making
bugs more likely. Fix it by creating corresponding test files for each
library module to ensure your code works correctly.|};
    Rule.v ~issue:Test_without_library ~title:"Orphaned Test Files"
      ~category:Testing
      ~examples:
        [
          bad
            {|(* test/test_old_feature.ml exists but lib/old_feature.ml was removed *)|};
          good
            {|(* Remove test/test_old_feature.ml or restore lib/old_feature.ml *)|};
        ]
      {|This issue means you have test files that don't correspond to any library
module making your test organization confusing. Fix it by either removing
orphaned test files or creating the corresponding library modules.|};
    Rule.v ~issue:Test_suite_not_included ~title:"Excluded Test Suites"
      ~category:Testing
      ~examples:
        [
          bad
            {|(* test/test.ml *)
let () = Alcotest.run "all" [Test_user.suite] 
(* Missing Test_parser.suite *)|};
          good
            {|(* test/test.ml *)
let () = Alcotest.run "all" [
  Test_user.suite;
  Test_parser.suite
]|};
        ]
      {|This issue means some test suites aren't included in your main test runner
so they never get executed. Fix it by adding them to the main test runner
to ensure all tests are run during development.|};
  ]
