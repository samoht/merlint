exception Type_error_fallback_needed
(** Exception raised when type errors are detected and fallback to parsetree is
    needed *)

(* Extract location from parsetree text *)
let extract_location_from_parsetree text =
  let location_regex =
    Re.compile
      (Re.seq
         [
           Re.str "(";
           Re.group (Re.rep1 (Re.compl [ Re.char '[' ]));
           Re.str "[";
           Re.group (Re.rep1 Re.digit);
           Re.str ",";
           Re.rep1 Re.digit;
           Re.str "+";
           Re.group (Re.rep1 Re.digit);
           Re.str "]";
         ])
  in
  try
    let substrings = Re.exec location_regex text in
    let line = int_of_string (Re.Group.get substrings 2) in
    let col = int_of_string (Re.Group.get substrings 3) in
    Some (line, col)
  with Not_found -> None

let extract_filename_from_parsetree text =
  let filename_regex =
    Re.compile
      (Re.seq
         [
           Re.str "("; Re.group (Re.rep1 (Re.compl [ Re.char '[' ])); Re.str "[";
         ])
  in
  try
    let substrings = Re.exec filename_regex text in
    Re.Group.get substrings 1
  with Not_found -> "unknown"

(** Check if this is a printf-like function *)
let is_printf_function base =
  String.ends_with ~suffix:"printf" base
  || String.ends_with ~suffix:"sprintf" base
  || String.ends_with ~suffix:"asprintf" base

(* TODO: E351 disabled - too imprecise, needs to distinguish global vs local state
(** Check for mutable state patterns in identifiers *)
let check_mutable_state identifiers =
  let issues = ref [] in

  List.iter
    (fun (id : Typedtree.elt) ->
      match id.location with
      | Some loc -> (
          let name = id.name in
          let base = name.base in

          (* Check for ref-related functions *)
          match base with
          | "ref" ->
              (* This is a ref constructor *)
              issues :=
                Issue.Mutable_state
                  { kind = "ref"; name = "<anonymous ref>"; location = loc }
                :: !issues
          | ":=" ->
              (* Assignment operator *)
              issues :=
                Issue.Mutable_state
                  { kind = "ref"; name = "assignment"; location = loc }
                :: !issues
          | _ -> ())
      | None -> ())
    identifiers;

  !issues
*)

(** Check for Error pattern usage *)
let check_error_patterns identifiers =
  let issues = ref [] in
  let error_seen = ref None in

  List.iter
    (fun (id : Typedtree.elt) ->
      match id.location with
      | Some loc -> (
          let name = id.name in
          let prefix = name.prefix in
          let base = name.base in

          match (prefix, base) with
          | _, "Error" ->
              (* Remember we saw Error constructor *)
              error_seen := Some loc
          | ([ "Stdlib"; "Format" ] | [ "Format" ]), "asprintf"
          | [ "Fmt" ], "str" -> (
              (* Check if this follows an Error constructor *)
              match !error_seen with
              | Some error_loc when error_loc.start_line = loc.start_line ->
                  (* Same line, likely Error (Fmt.str ...) pattern *)
                  let suggested =
                    match String.split_on_char '"' base with
                    | _ :: msg :: _ ->
                        let clean_msg =
                          String.map
                            (fun c -> if c = ' ' || c = ':' then '_' else c)
                            (String.lowercase_ascii msg)
                        in
                        "err_" ^ clean_msg
                    | _ -> "err_<specific_error>"
                  in
                  issues :=
                    Issue.Error_pattern
                      {
                        location = error_loc;
                        error_message = "Error (Fmt.str ...)";
                        suggested_function = suggested;
                      }
                    :: !issues;
                  error_seen := None
              | _ -> ())
          | _ -> ())
      | None -> ())
    identifiers;

  !issues

(** Check typedtree data structure *)
let check_typedtree ~identifiers ~patterns:_ =
  let issues = ref [] in

  (* Check identifiers for problematic patterns *)
  List.iter
    (fun (id : Typedtree.elt) ->
      match id.location with
      | Some loc -> (
          let name = id.name in
          let prefix = name.prefix in
          let base = name.base in

          (* Pattern match on the module path and base identifier *)
          match (prefix, base) with
          | [ "Stdlib"; "Obj" ], _ ->
              issues := Issue.No_obj_magic { location = loc } :: !issues
          | [ "Stdlib"; "Str" ], _ ->
              issues := Issue.Use_str_module { location = loc } :: !issues
          | [ "Stdlib"; "Printf" ], _ ->
              issues :=
                Issue.Use_printf_module
                  { location = loc; module_used = "Printf" }
                :: !issues
          | [ "Stdlib"; "Format" ], base when is_printf_function base ->
              issues :=
                Issue.Use_printf_module
                  { location = loc; module_used = "Format" }
                :: !issues
          | _, "*type-error*" ->
              (* This indicates we should fall back to parsetree *)
              raise Type_error_fallback_needed
          | _ -> ())
      | None -> ())
    identifiers;

  (* Note: Catch-all exception detection moved to ast_checks.ml
     because typedtree patterns don't provide enough context
     to distinguish exception handlers from other underscore uses *)

  (* Add mutable state checks *)
  (* TODO: E351 disabled - too imprecise, needs to distinguish global vs local state
  let mutable_issues = check_mutable_state identifiers in
  issues := mutable_issues @ !issues; *)

  (* Add error pattern checks *)
  let error_pattern_issues = check_error_patterns identifiers in
  issues := error_pattern_issues @ !issues;

  !issues

(** Check parsetree data structure *)
let check_parsetree ~identifiers ~patterns =
  let issues = ref [] in

  (* Check identifiers for problematic patterns *)
  List.iter
    (fun (id : Parsetree.elt) ->
      match id.location with
      | Some loc -> (
          let name = id.name in
          let prefix = name.prefix in
          let base = name.base in

          (* Pattern match on the module path and base identifier *)
          match (prefix, base) with
          | [ "Obj" ], _ ->
              issues := Issue.No_obj_magic { location = loc } :: !issues
          | [ "Str" ], _ ->
              issues := Issue.Use_str_module { location = loc } :: !issues
          | [ "Printf" ], _ ->
              issues :=
                Issue.Use_printf_module
                  { location = loc; module_used = "Printf" }
                :: !issues
          | [ "Format" ], base when is_printf_function base ->
              issues :=
                Issue.Use_printf_module
                  { location = loc; module_used = "Format" }
                :: !issues
          | _ -> ())
      | None -> ())
    identifiers;

  (* Check patterns for catch-all exception handlers *)
  List.iter
    (fun (pattern : Parsetree.elt) ->
      match pattern.location with
      | Some loc ->
          let name = pattern.name in
          let base = name.base in

          (* Check for catch-all pattern '_' *)
          if base = "_" then
            issues := Issue.Catch_all_exception { location = loc } :: !issues
      | None -> ())
    patterns;

  !issues

(** Legacy function for unit tests *)
let check (typedtree : Typedtree.t) =
  try
    check_typedtree ~identifiers:typedtree.identifiers
      ~patterns:typedtree.patterns
  with Type_error_fallback_needed -> []
