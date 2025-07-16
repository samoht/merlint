(** Implementation of the new issue design *)

type data =
  | Complexity_exceeded of {
      name : string;
      complexity : int;
      threshold : int;
    }
  | Function_too_long of {
      name : string;
      length : int;
      threshold : int;
    }
  | No_obj_magic
  | Missing_mli_doc of { module_name : string; file : string }
  | Missing_value_doc of { value_name : string }
  | Bad_doc_style of {
      value_name : string;
      message : string;
    }
  | Bad_variant_naming of {
      variant : string;
      expected : string;
    }
  | Bad_module_naming of {
      module_name : string;
      expected : string;
    }
  | Bad_value_naming of {
      value_name : string;
      expected : string;
    }
  | Bad_type_naming of {
      type_name : string;
      message : string;
    }
  | Catch_all_exception
  | Use_str_module
  | Use_printf_module of { module_used : string }
  | Deep_nesting of {
      name : string;
      depth : int;
      threshold : int;
    }
  | Missing_standard_function of {
      module_name : string;
      type_name : string;
      missing : string list;
      file : string;
    }
  | Missing_ocamlformat_file
  | Missing_mli_file of {
      ml_file : string;
      expected_mli : string;
    }
  | Long_identifier_name of {
      name : string;
      underscore_count : int;
      threshold : int;
    }
  | Bad_function_naming of {
      function_name : string;
      suggestion : string;
    }
  | Redundant_module_name of {
      item_name : string;
      module_name : string;
      item_type : string;
    }
  | Used_underscore_binding of {
      binding_name : string;
      usage_locations : Location.t list;
    }
  | Error_pattern of {
      error_message : string;
      suggested_function : string;
    }
  | Boolean_blindness of {
      function_name : string;
      bool_count : int;
      signature : string;
    }
  | Mutable_state of {
      kind : string;
      name : string;
    }
  | Test_exports_module_name of {
      filename : string;
      module_name : string;
    }
  | Silenced_warning of { warning_number : string }
  | Missing_test_file of {
      module_name : string;
      expected_test_file : string;
    }
  | Test_without_library of {
      test_file : string;
      expected_module : string;
    }
  | Test_suite_not_included of {
      test_module : string;
      test_runner_file : string;
    }
  | Missing_log_source of { module_name : string }

type t = {
  rule_code : string;
  location : Location.t option;
  data : data;
}

let create ~rule_id ?location ~data =
  { rule_id; location; data }

(* This will need to be provided the rules list to format properly *)
let pp_with_rules rules ppf issue =
  match Rule.get_by_id rules issue.rule_id with
  | None -> 
      let code = rule_id_to_code issue.rule_id in
      Fmt.pf ppf "[%s] Unknown rule" code
  | Some rule ->
      let formatted = rule.format_issue issue.data in
      let code = rule_id_to_code issue.rule_id in
      match issue.location with
      | None -> Fmt.pf ppf "[%s] %s" code formatted
      | Some loc ->
          Fmt.pf ppf "[%s] %a: %s" code Location.pp loc formatted

(* For compatibility, we'll need a default pp that doesn't require rules *)
let pp ppf issue =
  let code = rule_id_to_code issue.rule_id in
  match issue.location with
  | None -> Fmt.pf ppf "[%s] Issue" code
  | Some loc -> Fmt.pf ppf "[%s] %a: Issue" code Location.pp loc

let compare a b =
  (* First compare by priority (based on rule id) *)
  let pa = priority a.rule_id in
  let pb = priority b.rule_id in
  if pa <> pb then compare pa pb
  else
    (* Then by location *)
    match (a.location, b.location) with
    | Some la, Some lb -> Location.compare la lb
    | None, Some _ -> -1
    | Some _, None -> 1
    | None, None -> 0

(* Priority based on rule id *)
let priority rule_id =
  match rule_id with
  (* High priority security/safety *)
  | Obj_magic | Catch_all_exception | Silenced_warning | Mutable_state -> 1
  (* Code quality *)
  | Complexity | Function_length | Deep_nesting -> 2
  (* Style and naming *)
  | Str_module | Printf_module | Variant_naming | Module_naming 
  | Value_naming | Type_naming | Long_identifier | Function_naming
  | Redundant_module_name | Used_underscore_binding | Error_pattern
  | Boolean_blindness -> 3
  (* Documentation and project structure *)
  | Missing_mli_doc | Missing_value_doc | Bad_doc_style 
  | Missing_standard_function | Missing_ocamlformat_file | Missing_mli_file
  | Missing_log_source | Test_exports_module | Missing_test_file 
  | Test_without_library | Test_suite_not_included -> 4

(* Convert rule ID to error code string *)
let rule_id_to_code = function
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
  | Missing_log_source -> "E510"
  | Test_exports_module -> "E600"
  | Missing_test_file -> "E605"
  | Test_without_library -> "E610"
  | Test_suite_not_included -> "E615"