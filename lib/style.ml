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

(** Check for Error pattern usage using expression trees *)
let check_error_patterns expressions =
  let issues = ref [] in

  List.iter
    (fun (expr, loc) ->
      match expr with
      | Typedtree.Construct { name = "Error"; args } -> (
          (* Check if any argument is Fmt.str *)
          match args with
          | [ Typedtree.Apply { func = Typedtree.Ident id; _ } ]
            when String.ends_with ~suffix:"Fmt.str" id -> (
              match loc with
              | Some location ->
                  issues :=
                    Issue.Error_pattern
                      {
                        location;
                        error_message = "Error (Fmt.str ...)";
                        suggested_function = "err_fmt";
                      }
                    :: !issues
              | None -> ())
          | _ -> ())
      | _ -> ())
    expressions;

  !issues

(** Check typedtree data structure *)
let check_typedtree ~identifiers ~patterns:_ ~expressions =
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
          | ([ "Obj" ] | [ "Stdlib"; "Obj" ]), "magic" ->
              issues := Issue.No_obj_magic { location = loc } :: !issues
          | [ "Stdlib"; "Str" ], _ ->
              issues := Issue.Use_str_module { location = loc } :: !issues
          | [ "Str" ], _ ->
              issues := Issue.Use_str_module { location = loc } :: !issues
          | [ "Stdlib"; "Printf" ], _ ->
              issues :=
                Issue.Use_printf_module
                  { location = loc; module_used = "Printf" }
                :: !issues
          | [ "Printf" ], _ ->
              issues :=
                Issue.Use_printf_module
                  { location = loc; module_used = "Printf" }
                :: !issues
          | [ "Stdlib"; "Format" ], base when is_printf_function base ->
              issues :=
                Issue.Use_printf_module
                  { location = loc; module_used = "Format" }
                :: !issues
          | [ "Format" ], base when is_printf_function base ->
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

  (* Note: Mutable state detection moved to mutable_state.ml
     and is now called from rules.ml with outline data to detect
     only global mutable state, not local refs inside functions *)

  (* Add error pattern checks *)
  let error_pattern_issues = check_error_patterns expressions in
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
      ~patterns:typedtree.patterns ~expressions:typedtree.expressions
  with Type_error_fallback_needed ->
    (* Fall back to parsetree when type errors are present *)
    []
(* TODO: Need parsetree data to implement fallback *)
