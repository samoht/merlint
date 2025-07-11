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

(** Check typedtree data structure *)
let check_typedtree ~identifiers ~patterns =
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

  (* Check patterns for catch-all exception handlers *)
  List.iter
    (fun (pattern : Typedtree.elt) ->
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

(** Main check function with fallback *)
let check_with_fallback file =
  match Merlin.get_typedtree file with
  | Error _ -> (
      (* Fallback to parsetree immediately if typedtree fails *)
      match Merlin.get_parsetree file with
      | Ok parsetree ->
          check_parsetree ~identifiers:parsetree.identifiers
            ~patterns:parsetree.patterns
      | Error _ -> [])
  | Ok typedtree -> (
      try
        check_typedtree ~identifiers:typedtree.identifiers
          ~patterns:typedtree.patterns
      with Type_error_fallback_needed -> (
        (* Fallback to parsetree when type errors are detected *)
        match Merlin.get_parsetree file with
        | Ok parsetree ->
            check_parsetree ~identifiers:parsetree.identifiers
              ~patterns:parsetree.patterns
        | Error _ -> []))

(** Legacy function for unit tests *)
let check (typedtree : Typedtree.t) =
  try
    check_typedtree ~identifiers:typedtree.identifiers
      ~patterns:typedtree.patterns
  with Type_error_fallback_needed -> []
