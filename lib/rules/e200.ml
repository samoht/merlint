(** E200: Outdated Str Module *)

let check typedtree =
  let issues = ref [] in

  (* Check identifiers for Str module usage *)
  List.iter
    (fun (id : Ast.elt) ->
      match id.location with
      | Some loc -> (
          let name = id.name in
          let prefix = name.prefix in

          (* Check for any Str module usage *)
          match prefix with
          | [ "Str" ] | [ "Stdlib"; "Str" ] ->
              issues := Issue.Use_str_module { location = loc } :: !issues
          | _ -> ())
      | None -> ())
    typedtree.Typedtree.identifiers;

  !issues
