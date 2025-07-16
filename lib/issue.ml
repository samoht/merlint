(** Issue categories/kinds *)
type kind =
  | Complexity
  | Function_length
  | Deep_nesting
  | Obj_magic
  | Catch_all_exception
  | Str_module
  | Printf_module
  | Variant_naming
  | Module_naming
  | Value_naming
  | Type_naming
  | Long_identifier
  | Function_naming
  | Redundant_module_name
  | Used_underscore_binding
  | Error_pattern
  | Boolean_blindness
  | Mutable_state
  | Missing_mli_doc
  | Missing_value_doc
  | Bad_doc_style
  | Missing_standard_function
  | Missing_ocamlformat_file
  | Missing_mli_file
  | Test_exports_module
  | Silenced_warning
  | Missing_test_file
  | Test_without_library
  | Test_suite_not_included
  (* Logging Rules *)
  | Missing_log_source

(** Concrete issue instances *)
type t =
  | Complexity_exceeded of {
      name : string;
      location : Location.t;
      complexity : int;
      threshold : int;
    }
  | Function_too_long of {
      name : string;
      location : Location.t;
      length : int;
      threshold : int;
    }
  | No_obj_magic of { location : Location.t }
  | Missing_mli_doc of { module_name : string; file : string }
  | Missing_value_doc of { value_name : string; location : Location.t }
  | Bad_doc_style of {
      value_name : string;
      location : Location.t;
      message : string;
    }
  | Bad_variant_naming of {
      variant : string;
      location : Location.t;
      expected : string;
    }
  | Bad_module_naming of {
      module_name : string;
      location : Location.t;
      expected : string;
    }
  | Bad_value_naming of {
      value_name : string;
      location : Location.t;
      expected : string;
    }
  | Bad_type_naming of {
      type_name : string;
      location : Location.t;
      message : string;
    }
  | Catch_all_exception of { location : Location.t }
  | Use_str_module of { location : Location.t }
  | Use_printf_module of { location : Location.t; module_used : string }
  | Deep_nesting of {
      name : string;
      location : Location.t;
      depth : int;
      threshold : int;
    }
  | Missing_standard_function of {
      module_name : string;
      type_name : string;
      missing : string list;
      file : string;
    }
  | Missing_ocamlformat_file of { location : Location.t }
  | Missing_mli_file of {
      ml_file : string;
      expected_mli : string;
      location : Location.t;
    }
  | Long_identifier_name of {
      name : string;
      location : Location.t;
      underscore_count : int;
      threshold : int;
    }
  | Bad_function_naming of {
      function_name : string;
      location : Location.t;
      suggestion : string;
    }
  | Redundant_module_name of {
      item_name : string;
      module_name : string;
      location : Location.t;
      item_type : string; (* "function" or "type" *)
    }
  | Used_underscore_binding of {
      binding_name : string;
      location : Location.t;
      usage_locations : Location.t list;
    }
  | Error_pattern of {
      location : Location.t;
      error_message : string;
      suggested_function : string;
    }
  | Boolean_blindness of {
      function_name : string;
      location : Location.t;
      bool_count : int;
      signature : string;
    }
  | Mutable_state of {
      kind : string; (* "ref", "mutable", "array" *)
      name : string;
      location : Location.t;
    }
  | Test_exports_module_name of {
      filename : string;
      location : Location.t;
      module_name : string;
    }
  | Silenced_warning of { location : Location.t; warning_number : string }
  | Missing_test_file of {
      module_name : string;
      expected_test_file : string;
      location : Location.t;
    }
  | Test_without_library of {
      test_file : string;
      expected_module : string;
      location : Location.t;
    }
  | Test_suite_not_included of {
      test_module : string;
      test_runner_file : string;
      location : Location.t;
    }
  | Missing_log_source of { module_name : string; location : Location.t }

let get_type = function
  | Complexity_exceeded _ -> Complexity
  | Function_too_long _ -> Function_length
  | Deep_nesting _ -> Deep_nesting
  | No_obj_magic _ -> Obj_magic
  | Catch_all_exception _ -> Catch_all_exception
  | Use_str_module _ -> Str_module
  | Use_printf_module _ -> Printf_module
  | Bad_variant_naming _ -> Variant_naming
  | Bad_module_naming _ -> Module_naming
  | Bad_value_naming _ -> Value_naming
  | Bad_type_naming _ -> Type_naming
  | Long_identifier_name _ -> Long_identifier
  | Bad_function_naming _ -> Function_naming
  | Redundant_module_name _ -> Redundant_module_name
  | Used_underscore_binding _ -> Used_underscore_binding
  | Error_pattern _ -> Error_pattern
  | Boolean_blindness _ -> Boolean_blindness
  | Mutable_state _ -> Mutable_state
  | Missing_mli_doc _ -> Missing_mli_doc
  | Missing_value_doc _ -> Missing_value_doc
  | Bad_doc_style _ -> Bad_doc_style
  | Missing_standard_function _ -> Missing_standard_function
  | Missing_ocamlformat_file _ -> Missing_ocamlformat_file
  | Missing_mli_file _ -> Missing_mli_file
  | Test_exports_module_name _ -> Test_exports_module
  | Silenced_warning _ -> Silenced_warning
  | Missing_test_file _ -> Missing_test_file
  | Test_without_library _ -> Test_without_library
  | Test_suite_not_included _ -> Test_suite_not_included
  | Missing_log_source _ -> Missing_log_source

(* Error code mapping *)
let error_code = function
  | Complexity -> "E001"
  | Function_length -> "E005"
  | Deep_nesting -> "E010"
  | Obj_magic -> "E100"
  | Catch_all_exception -> "E105"
  | Silenced_warning -> "E110"
  | Str_module -> "E200"
  | Printf_module -> "E205"
  | Variant_naming -> "E300"
  | Module_naming -> "E305"
  | Value_naming -> "E310"
  | Type_naming -> "E315"
  | Long_identifier -> "E320"
  | Function_naming -> "E325"
  | Redundant_module_name -> "E330"
  | Used_underscore_binding -> "E335"
  | Error_pattern -> "E340"
  | Boolean_blindness -> "E350"
  | Mutable_state -> "E351"
  | Missing_mli_doc -> "E400"
  | Missing_value_doc -> "E405"
  | Bad_doc_style -> "E410"
  | Missing_standard_function -> "E415"
  | Missing_ocamlformat_file -> "E500"
  | Missing_mli_file -> "E505"
  | Test_exports_module -> "E600"
  | Missing_test_file -> "E605"
  | Test_without_library -> "E610"
  | Test_suite_not_included -> "E615"
  | Missing_log_source -> "E510"

(* Build a reverse mapping from error codes to issue types *)
let error_code_to_kind =
  let map = Hashtbl.create 50 in
  let add_mapping issue_kind =
    let code = error_code issue_kind in
    Hashtbl.add map code issue_kind
  in
  (* Add all issue types - this ensures we don't miss any *)
  List.iter add_mapping
    [
      Complexity;
      Function_length;
      Deep_nesting;
      Obj_magic;
      Catch_all_exception;
      Silenced_warning;
      Str_module;
      Printf_module;
      Variant_naming;
      Module_naming;
      Value_naming;
      Type_naming;
      Long_identifier;
      Function_naming;
      Redundant_module_name;
      Used_underscore_binding;
      Error_pattern;
      Boolean_blindness;
      Mutable_state;
      Missing_mli_doc;
      Missing_value_doc;
      Bad_doc_style;
      Missing_standard_function;
      Missing_ocamlformat_file;
      Missing_mli_file;
      Test_exports_module;
      Missing_test_file;
      Test_without_library;
      Test_suite_not_included;
      Missing_log_source;
    ];
  map

(* Derive 'all' list from the error code mappings to ensure consistency *)
let all_kinds =
  let codes =
    Hashtbl.fold
      (fun code issue_kind acc -> (code, issue_kind) :: acc)
      error_code_to_kind []
  in
  (* Sort by error code to ensure consistent ordering *)
  codes |> List.sort (fun (a, _) (b, _) -> String.compare a b) |> List.map snd

(* Validation: ensure every issue type has a unique error code *)
let _ =
  let unique_codes = Hashtbl.length error_code_to_kind in
  let total_kinds = List.length all_kinds in
  if unique_codes <> total_kinds then
    failwith
      (Fmt.str
         "Issue type validation failed: %d unique error codes but %d issue \
          types"
         unique_codes total_kinds)

(* Helper function to get issue type from error code *)
let kind_of_error_code code =
  let upper_code = String.uppercase_ascii code in
  try Some (Hashtbl.find error_code_to_kind upper_code) with Not_found -> None

(* Helper to style error codes *)
let pp_error_code ppf code =
  Fmt.pf ppf "%a" (Fmt.styled `Yellow Fmt.string) (Fmt.str "[%s]" code)

(* Helper to style locations with bold filenames *)
let pp_location_styled ppf (loc : Location.t) =
  Fmt.pf ppf "%a:%d:%d"
    (Fmt.styled `Bold Fmt.string)
    loc.file loc.start_line loc.start_col

(* Helper to format a simple issue with location *)
let pp_simple_issue ppf code location message =
  Fmt.pf ppf "%a %a:@ %s" pp_error_code code pp_location_styled location message

(* Helper to format a naming issue *)
let pp_naming_issue ppf code location item_type name expected =
  Fmt.pf ppf "%a %a:@ %s@ '%s'@ should@ be@ '%s'" pp_error_code code
    pp_location_styled location item_type name expected

(* Helper to format a threshold issue *)
let pp_threshold_issue ppf code location name metric_type value threshold =
  Fmt.pf ppf "%a %a:@ Function@ '%s'@ %s@ %d@ (threshold:@ %d)" pp_error_code
    code pp_location_styled location name metric_type value threshold

(* Helper to format issue content *)
let pp_issue_content ppf issue =
  let code = error_code (get_type issue) in
  match issue with
  | Complexity_exceeded { name; location; complexity; threshold } ->
      pp_threshold_issue ppf code location name
        "has@ cyclomatic@ complexity@ of" complexity threshold
  | Function_too_long { name; location; length; threshold } ->
      Fmt.pf ppf "%a %a:@ Function@ '%s'@ is@ %d@ lines@ long@ (threshold:@ %d)"
        pp_error_code code pp_location_styled location name length threshold
  | Deep_nesting { name; location; depth; threshold } ->
      pp_threshold_issue ppf code location name "has@ nesting@ depth@ of" depth
        threshold
  | No_obj_magic { location } ->
      pp_simple_issue ppf code location "Never@ use@ Obj.magic"
  | Catch_all_exception { location } ->
      pp_simple_issue ppf code location "Avoid@ catch-all@ exception@ handler"
  | Use_str_module { location } ->
      pp_simple_issue ppf code location "Use@ Re@ module@ instead@ of@ Str"
  | Use_printf_module { location; module_used } ->
      pp_simple_issue ppf code location
        (Fmt.str "Use@ Fmt@ module@ instead@ of@ %s" module_used)
  | Bad_variant_naming { variant; location; expected } ->
      pp_naming_issue ppf code location "Variant" variant expected
  | Bad_module_naming { module_name; location; expected } ->
      pp_naming_issue ppf code location "Module" module_name expected
  | Bad_value_naming { value_name; location; expected } ->
      pp_naming_issue ppf code location "Value" value_name expected
  | Bad_type_naming { type_name; location; message } ->
      Fmt.pf ppf "%a %a:@ Type@ '%s'@ %s" pp_error_code code pp_location_styled
        location type_name message
  | Bad_function_naming { function_name; location; suggestion } ->
      Fmt.pf ppf
        "%a %a:@ Function@ '%s'@ should@ use@ '%s'@ (get_*@ for@ extraction,@ \
         find_*@ for@ search)"
        pp_error_code code pp_location_styled location function_name suggestion
  | Redundant_module_name { item_name; module_name; location; item_type } ->
      Fmt.pf ppf "%a %a:@ %s@ '%s'@ redundantly@ includes@ module@ name@ '%s'"
        pp_error_code code pp_location_styled location
        (String.capitalize_ascii item_type)
        item_name module_name
  | Used_underscore_binding { binding_name; location; usage_locations } ->
      let usage_count = List.length usage_locations in
      Fmt.pf ppf
        "%a %a:@ Binding@ '%s'@ is@ prefixed@ with@ underscore@ but@ used@ %d@ \
         time%s"
        pp_error_code code pp_location_styled location binding_name usage_count
        (if usage_count = 1 then "" else "s")
  | Error_pattern { location; error_message; suggested_function } ->
      Fmt.pf ppf
        "%a %a:@ Error@ pattern@ '%s'@ should@ use@ helper@ function@ '%s'"
        pp_error_code code pp_location_styled location error_message
        suggested_function
  | Boolean_blindness { function_name; location; bool_count; signature = _ } ->
      Fmt.pf ppf
        "%a %a:@ Function@ '%s'@ has@ %d@ boolean@ parameters@ making@ call@ \
         sites@ ambiguous"
        pp_error_code code pp_location_styled location function_name bool_count
  | Mutable_state { kind; name; location } ->
      Fmt.pf ppf "%a %a:@ %s@ '%s'@ introduces@ mutable@ state" pp_error_code
        code pp_location_styled location
        (String.capitalize_ascii kind)
        name
  | Missing_mli_doc { module_name; file } ->
      Fmt.pf ppf "%a %a:1:0:@ Module@ '%s'@ missing@ documentation@ comment"
        pp_error_code code
        (Fmt.styled `Bold Fmt.string)
        file module_name
  | Missing_value_doc { value_name; location } ->
      Fmt.pf ppf "%a %a:@ Value@ '%s'@ missing@ documentation" pp_error_code
        code pp_location_styled location value_name
  | Bad_doc_style { value_name; location; message } ->
      Fmt.pf ppf "%a %a:@ Value@ '%s'@ documentation@ issue:@ %s" pp_error_code
        code pp_location_styled location value_name message
  | Missing_standard_function { module_name; type_name; missing; file } ->
      Fmt.pf ppf
        "%a %a:@ Module@ '%s'@ with@ type@ '%s'@ missing@ standard@ \
         functions:@ %s"
        pp_error_code code
        (Fmt.styled `Bold Fmt.string)
        file module_name type_name
        (String.concat ", " missing)
  | Missing_ocamlformat_file _ ->
      Fmt.pf ppf
        "%a (project):@ Missing@ .ocamlformat@ file@ for@ consistent@ \
         formatting"
        pp_error_code code
  | Missing_mli_file { location; _ } ->
      pp_simple_issue ppf code location "missing@ interface@ file"
  | Long_identifier_name { name; location; underscore_count; _ } ->
      Fmt.pf ppf "%a %a:@ '%s'@ has@ too@ many@ underscores@ (%d)" pp_error_code
        code pp_location_styled location name underscore_count
  | Test_exports_module_name { filename = _; location; module_name } ->
      Fmt.pf ppf
        "%a %a:@ Test@ file@ exports@ module@ name@ '%s'@ instead@ of@ 'suite'"
        pp_error_code code pp_location_styled location module_name
  | Silenced_warning { location; warning_number } ->
      Fmt.pf ppf
        "%a %a:@ Warning@ %s@ is@ silenced@ -@ fix@ the@ underlying@ issue@ \
         instead"
        pp_error_code code pp_location_styled location warning_number
  | Missing_test_file { location; module_name; expected_test_file } ->
      Fmt.pf ppf "%a %a:@ Module@ '%s'@ is@ missing@ test@ file@ '%s'"
        pp_error_code code pp_location_styled location module_name
        expected_test_file
  | Test_without_library { location; test_file; expected_module } ->
      Fmt.pf ppf
        "%a %a:@ Test@ file@ '%s'@ has@ no@ corresponding@ library@ module@ \
         '%s'"
        pp_error_code code pp_location_styled location test_file expected_module
  | Test_suite_not_included { location; test_module; _ } ->
      Fmt.pf ppf
        "%a %a:@ Test@ suite@ '%s.suite'@ is@ not@ included@ in@ test@ runner"
        pp_error_code code pp_location_styled location test_module
  | Missing_log_source { location; module_name } ->
      Fmt.pf ppf "%a %a:@ Module@ '%s'@ is@ missing@ a@ log@ source@ definition"
        pp_error_code code pp_location_styled location module_name

(* Format issue with proper line wrapping using Fmt *)
let pp_wrapped ppf issue = Fmt.box ~indent:7 pp_issue_content ppf issue
let pp = pp_wrapped
let format v = Fmt.str "%a" pp v

(* Extract location from an issue *)
let find_location = function
  | Complexity_exceeded { location; _ }
  | Function_too_long { location; _ }
  | No_obj_magic { location }
  | Missing_value_doc { location; _ }
  | Bad_doc_style { location; _ }
  | Bad_variant_naming { location; _ }
  | Bad_module_naming { location; _ }
  | Bad_value_naming { location; _ }
  | Bad_type_naming { location; _ }
  | Catch_all_exception { location }
  | Use_str_module { location }
  | Use_printf_module { location; _ }
  | Deep_nesting { location; _ }
  | Long_identifier_name { location; _ }
  | Bad_function_naming { location; _ }
  | Redundant_module_name { location; _ }
  | Used_underscore_binding { location; _ }
  | Error_pattern { location; _ }
  | Boolean_blindness { location; _ }
  | Mutable_state { location; _ } ->
      Some location
  | Missing_mli_doc { file; _ } ->
      Some
        Location.
          { file; start_line = 1; start_col = 1; end_line = 1; end_col = 1 }
  | Missing_ocamlformat_file { location } -> Some location
  | Missing_mli_file { ml_file; _ } ->
      Some
        Location.
          {
            file = ml_file;
            start_line = 1;
            start_col = 1;
            end_line = 1;
            end_col = 1;
          }
  | Test_exports_module_name { location; _ }
  | Missing_test_file { location; _ }
  | Test_without_library { location; _ }
  | Test_suite_not_included { location; _ } ->
      Some location
  | Missing_log_source { location; _ } -> Some location
  | Silenced_warning { location; _ } -> Some location
  | Missing_standard_function _ -> None

(* Get issue description without location prefix *)
let get_description = function
  | Complexity_exceeded { name; complexity; threshold; _ } ->
      Fmt.str "Function '%s' has cyclomatic complexity of %d (threshold: %d)"
        name complexity threshold
  | Function_too_long { name; length; threshold; _ } ->
      Fmt.str "Function '%s' is too long (%d lines, threshold: %d)" name length
        threshold
  | No_obj_magic _ -> "Use of Obj.magic (unsafe type casting)"
  | Missing_mli_doc { module_name; _ } ->
      Fmt.str "Module '%s' is missing documentation comment" module_name
  | Missing_value_doc { value_name; _ } ->
      Fmt.str "Value '%s' is missing documentation comment" value_name
  | Bad_doc_style { value_name; message; _ } ->
      Fmt.str "Documentation for '%s': %s" value_name message
  | Bad_variant_naming { variant; expected; _ } ->
      Fmt.str "Variant '%s' should be '%s'" variant expected
  | Bad_module_naming { module_name; expected; _ } ->
      Fmt.str "Module '%s' should be '%s'" module_name expected
  | Bad_value_naming { value_name; expected; _ } ->
      Fmt.str "Value '%s' should be '%s'" value_name expected
  | Bad_type_naming { type_name; message; _ } ->
      Fmt.str "Type '%s': %s" type_name message
  | Catch_all_exception _ -> "Catch-all exception handler"
  | Use_str_module _ -> "Use of deprecated Str module"
  | Use_printf_module { module_used; _ } ->
      Fmt.str "Use Fmt module instead of %s" module_used
  | Deep_nesting { name; depth; threshold; _ } ->
      Fmt.str "Function '%s' has nesting depth of %d (threshold: %d)" name depth
        threshold
  | Long_identifier_name { name; underscore_count; _ } ->
      Fmt.str "'%s' has too many underscores (%d)" name underscore_count
  | Bad_function_naming { function_name; suggestion; _ } ->
      Fmt.str "Function '%s' should be '%s'" function_name suggestion
  | Redundant_module_name { item_name; module_name; _ } ->
      Fmt.str "'%s' has redundant module prefix '%s'" item_name module_name
  | Used_underscore_binding { binding_name; _ } ->
      Fmt.str "Binding '%s' has underscore prefix but is used in code"
        binding_name
  | Error_pattern { error_message; suggested_function; _ } ->
      Fmt.str "Error '%s' should use helper function '%s'" error_message
        suggested_function
  | Boolean_blindness { function_name; bool_count; _ } ->
      Fmt.str "Function '%s' has %d boolean parameters" function_name bool_count
  | Mutable_state { kind; name; _ } ->
      Fmt.str "%s '%s' introduces mutable state"
        (String.capitalize_ascii kind)
        name
  | Missing_ocamlformat_file _ -> "missing .ocamlformat file"
  | Missing_mli_file _ -> "missing interface file"
  | Test_exports_module_name { module_name; _ } ->
      Fmt.str "Test file '%s' should export 'suite' not individual tests"
        module_name
  | Missing_test_file { module_name; expected_test_file; _ } ->
      Fmt.str "Module '%s' is missing test file '%s'" module_name
        expected_test_file
  | Test_without_library { test_file; expected_module; _ } ->
      Fmt.str "Test file '%s' has no corresponding module '%s'" test_file
        expected_module
  | Test_suite_not_included { test_module; _ } ->
      Fmt.str "Test suite '%s.suite' is not included in test runner" test_module
  | Missing_log_source { module_name; _ } ->
      Fmt.str "Module '%s' is missing a log source definition" module_name
  | Silenced_warning { warning_number; _ } ->
      Fmt.str "Warning '%s' is silenced" warning_number
  | Missing_standard_function { type_name; missing; _ } ->
      Fmt.str "Type '%s' is missing: %s" type_name (String.concat ", " missing)

(* Assign priority to issues - lower number = higher priority *)
let priority = function
  | No_obj_magic _ | Catch_all_exception _ | Silenced_warning _
  | Mutable_state _ ->
      1
  | Complexity_exceeded _ | Deep_nesting _ | Function_too_long _ -> 2
  | Use_str_module _ | Use_printf_module _ | Bad_variant_naming _
  | Missing_mli_file _ | Bad_module_naming _ | Bad_value_naming _
  | Bad_type_naming _ | Long_identifier_name _ | Bad_function_naming _
  | Redundant_module_name _ | Used_underscore_binding _ | Error_pattern _
  | Boolean_blindness _ ->
      3
  | Missing_mli_doc _ | Missing_value_doc _ | Bad_doc_style _
  | Missing_standard_function _ | Missing_ocamlformat_file _
  | Test_exports_module_name _ | Missing_test_file _ | Test_without_library _
  | Test_suite_not_included _ | Missing_log_source _ ->
      4

let find_file = function
  | Missing_mli_doc { file; _ } | Missing_standard_function { file; _ } ->
      Some file
  | _ -> None

(* Get numeric severity for sorting - higher number = more severe *)
let numeric_severity = function
  | Function_too_long { length; _ } -> length
  | Complexity_exceeded { complexity; _ } -> complexity
  | Deep_nesting { depth; _ } -> depth
  | Long_identifier_name { underscore_count; _ } -> underscore_count
  | _ -> 0

(* Compare issues for sorting *)
let compare a b =
  let pa = priority a in
  let pb = priority b in
  if pa <> pb then compare pa pb
  else
    (* Within the same priority, sort by severity (higher first) *)
    let sa = numeric_severity a in
    let sb = numeric_severity b in
    if sa <> sb then compare sb sa (* Reverse order: higher severity first *)
    else
      match (find_file a, find_file b) with
      | Some f1, Some f2 -> String.compare f1 f2
      | _ -> (
          match (find_location a, find_location b) with
          | Some l1, Some l2 -> Location.compare l1 l2
          | _ -> 0)

let equal a b = compare a b = 0

exception Disabled of string
