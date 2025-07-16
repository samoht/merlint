(** E350: Boolean Blindness - functions with 2+ boolean parameters *)

(** Count boolean parameters in a function signature *)
let count_bool_params type_sig =
  (* Count occurrences of "bool" in the signature, excluding the return type *)
  let parts = String.split_on_char '>' type_sig in
  let param_part =
    match List.rev parts with
    | [] -> type_sig
    | _return_type :: rest -> String.concat ">" (List.rev rest)
  in
  (* Use the traverse helper to count "bool" occurrences *)
  Traverse.count_parameters param_part "bool"

(** Check for boolean blindness in function signatures *)
let check_boolean_blindness ~filename ~outline =
  match outline with
  | None -> []
  | Some items ->
      List.filter_map
        (fun (item : Outline.item) ->
          match (item.kind, item.type_sig) with
          | Outline.Value, Some sig_str when Traverse.is_function_type sig_str
            ->
              let bool_count = count_bool_params sig_str in
              if bool_count >= 2 then
                match Traverse.extract_outline_location filename item with
                | Some loc ->
                    Some
                      (Issue.boolean_blindness ~function_name:item.name ~loc
                         ~bool_count ~signature:sig_str)
                | None -> None
              else None
          | _ -> None)
        items

(** Main check function *)
let check (ctx : Context.file) =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  check_boolean_blindness ~filename ~outline:(Some outline_data)
