(** E205: Consider Using Fmt Module *)

(** Check if this is a printf-like function *)
let is_printf_function base =
  String.ends_with ~suffix:"printf" base
  || String.ends_with ~suffix:"sprintf" base
  || String.ends_with ~suffix:"asprintf" base

let check typedtree =
  let issues = ref [] in

  (* Check identifiers for Printf/Format module usage *)
  List.iter
    (fun (id : Ast.elt) ->
      match id.location with
      | Some loc -> (
          let name = id.name in
          let prefix = name.prefix in
          let base = name.base in

          (* Check for Printf/Format module usage *)
          match prefix with
          | [ "Printf" ] | [ "Stdlib"; "Printf" ] ->
              issues :=
                Issue.Use_printf_module
                  { location = loc; module_used = "Printf" }
                :: !issues
          | ([ "Format" ] | [ "Stdlib"; "Format" ]) when is_printf_function base
            ->
              issues :=
                Issue.Use_printf_module
                  { location = loc; module_used = "Format" }
                :: !issues
          | _ -> ())
      | None -> ())
    typedtree.Typedtree.identifiers;

  !issues
