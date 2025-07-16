(** E205: Consider Using Fmt Module *)

(** Check if this is a printf-like function *)
let is_printf_function base =
  String.ends_with ~suffix:"printf" base
  || String.ends_with ~suffix:"sprintf" base
  || String.ends_with ~suffix:"asprintf" base

let check ctx =
  let issues = ref [] in

  (* Check identifiers for Printf/Format module usage *)
  Traverse.iter_identifiers_with_location (Context.ast ctx) (fun id loc ->
      let name = id.name in
      let prefix = name.prefix in
      let base = name.base in

      (* Check for Printf/Format module usage *)
      match prefix with
      | [ "Stdlib"; "Printf" ] ->
          issues :=
            Issue.use_printf_module ~loc ~module_used:"Printf" :: !issues
      | [ "Stdlib"; "Format" ] when is_printf_function base ->
          issues :=
            Issue.use_printf_module ~loc ~module_used:"Format" :: !issues
      | _ -> ());

  !issues
