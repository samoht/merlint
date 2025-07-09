type location = { file : string; line : int; col : int }

type t =
  | Complexity_exceeded of {
      name : string;
      location : location;
      complexity : int;
      threshold : int;
    }
  | Function_too_long of {
      name : string;
      location : location;
      length : int;
      threshold : int;
    }
  | No_obj_magic of { location : location }
  | Missing_mli_doc of { module_name : string; file : string }
  | Missing_value_doc of { value_name : string; location : location }
  | Bad_doc_style of {
      value_name : string;
      location : location;
      message : string;
    }
  | Bad_variant_naming of {
      variant : string;
      location : location;
      expected : string;
    }
  | Bad_module_naming of {
      module_name : string;
      location : location;
      expected : string;
    }
  | Bad_value_naming of {
      value_name : string;
      location : location;
      expected : string;
    }
  | Bad_type_naming of {
      type_name : string;
      location : location;
      message : string;
    }
  | Catch_all_exception of { location : location }
  | Use_str_module of { location : location }
  | Deep_nesting of {
      name : string;
      location : location;
      depth : int;
      threshold : int;
    }
  | Missing_standard_function of {
      module_name : string;
      type_name : string;
      missing : string list;
      file : string;
    }
  | Missing_ocamlformat_file of { location : location }
  | Missing_mli_file of {
      ml_file : string;
      expected_mli : string;
      location : location;
    }
  | Long_identifier_name of {
      name : string;
      location : location;
      underscore_count : int;
      threshold : int;
    }

let format_location loc = Printf.sprintf "%s:%d:%d" loc.file loc.line loc.col

let format_complexity v =
  match v with
  | Complexity_exceeded { name; location; complexity; threshold } ->
      Printf.sprintf
        "%s: Function '%s' has cyclomatic complexity of %d (threshold: %d)"
        (format_location location) name complexity threshold
  | Function_too_long { name; location; length; threshold } ->
      Printf.sprintf "%s: Function '%s' is %d lines long (threshold: %d)"
        (format_location location) name length threshold
  | Deep_nesting { name; location; depth; threshold } ->
      Printf.sprintf "%s: Function '%s' has nesting depth of %d (threshold: %d)"
        (format_location location) name depth threshold
  | _ -> ""

let format_naming v =
  match v with
  | Bad_variant_naming { variant; location; expected } ->
      Printf.sprintf "%s: Variant '%s' should be '%s'"
        (format_location location) variant expected
  | Bad_module_naming { module_name; location; expected } ->
      Printf.sprintf "%s: Module '%s' should be '%s'" (format_location location)
        module_name expected
  | Bad_value_naming { value_name; location; expected } ->
      Printf.sprintf "%s: Value '%s' should be '%s'" (format_location location)
        value_name expected
  | Bad_type_naming { type_name; location; message } ->
      Printf.sprintf "%s: Type '%s' %s" (format_location location) type_name
        message
  | _ -> ""

let format_doc v =
  match v with
  | Missing_mli_doc { module_name; file } ->
      Printf.sprintf "%s:1:0: Module '%s' missing documentation comment" file
        module_name
  | Missing_value_doc { value_name; location } ->
      Printf.sprintf "%s: Value '%s' missing documentation"
        (format_location location) value_name
  | Bad_doc_style { value_name; location; message } ->
      Printf.sprintf "%s: Value '%s' documentation issue: %s"
        (format_location location) value_name message
  | Missing_standard_function { module_name; type_name; missing; file } ->
      Printf.sprintf
        "%s: Module '%s' with type '%s' missing standard functions: %s" file
        module_name type_name
        (String.concat ", " missing)
  | _ -> ""

let format_style v =
  match v with
  | No_obj_magic { location } ->
      Printf.sprintf "%s: Never use Obj.magic" (format_location location)
  | Catch_all_exception { location } ->
      Printf.sprintf "%s: Avoid catch-all exception handler"
        (format_location location)
  | Use_str_module { location } ->
      Printf.sprintf "%s: Use Re module instead of Str"
        (format_location location)
  | Missing_ocamlformat_file { location = _ } ->
      Printf.sprintf
        "(project): Missing .ocamlformat file for consistent formatting"
  | Missing_mli_file { location; _ } ->
      Printf.sprintf "%s: missing interface file" (format_location location)
  | Long_identifier_name { location; _ } ->
      Printf.sprintf "%s is too long" (format_location location)
  | _ -> ""

let format v =
  let result = format_complexity v in
  if result <> "" then result
  else
    let result = format_naming v in
    if result <> "" then result
    else
      let result = format_doc v in
      if result <> "" then result else format_style v

(* Assign priority to issues - lower number = higher priority *)
let priority = function
  (* Critical issues - code correctness/safety *)
  | No_obj_magic _ -> 1
  | Catch_all_exception _ -> 2
  
  (* High priority - code quality *)
  | Complexity_exceeded _ -> 3
  | Deep_nesting _ -> 4
  | Function_too_long _ -> 5
  
  (* Medium priority - style and conventions *)
  | Use_str_module _ -> 6
  | Bad_variant_naming _ -> 7
  | Missing_mli_file _ -> 8
  | Bad_module_naming _ -> 9
  | Bad_value_naming _ -> 10
  | Bad_type_naming _ -> 11
  | Long_identifier_name _ -> 12
  
  (* Low priority - documentation and structure *)
  | Missing_mli_doc _ -> 13
  | Missing_value_doc _ -> 14
  | Bad_doc_style _ -> 15
  | Missing_standard_function _ -> 16
  | Missing_ocamlformat_file _ -> 17

(* Compare issues for sorting *)
let compare a b =
  let pa = priority a in
  let pb = priority b in
  if pa <> pb then compare pa pb
  else
    (* Same priority - sort by location *)
    match (a, b) with
    | (Missing_mli_doc { file = f1; _ }, Missing_mli_doc { file = f2; _ })
    | (Missing_standard_function { file = f1; _ }, Missing_standard_function { file = f2; _ }) ->
        String.compare f1 f2
    | _ ->
        let loc_a = match a with
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
          | Deep_nesting { location; _ }
          | Missing_ocamlformat_file { location }
          | Missing_mli_file { location; _ }
          | Long_identifier_name { location; _ } -> Some location
          | _ -> None
        in
        let loc_b = match b with
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
          | Deep_nesting { location; _ }
          | Missing_ocamlformat_file { location }
          | Missing_mli_file { location; _ }
          | Long_identifier_name { location; _ } -> Some location
          | _ -> None
        in
        match (loc_a, loc_b) with
        | (Some l1, Some l2) ->
            let fc = String.compare l1.file l2.file in
            if fc <> 0 then fc
            else compare l1.line l2.line
        | _ -> 0
