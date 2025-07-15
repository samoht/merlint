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
  (* Count "bool" occurrences in parameter part *)
  let rec count acc pos str =
    match String.index_from_opt str pos 'b' with
    | None -> acc
    | Some idx ->
        if idx + 4 <= String.length str && String.sub str idx 4 = "bool" then
          count (acc + 1) (idx + 4) str
        else count acc (idx + 1) str
  in
  count 0 0 param_part

(** Extract location from outline item *)
let extract_location filename (item : Outline.item) =
  match item.range with
  | Some range ->
      Location.create ~file:filename ~start_line:range.start.line
        ~start_col:range.start.col ~end_line:range.start.line
        ~end_col:range.start.col
  | None ->
      (* Fallback location *)
      Location.create ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
        ~end_col:0

(** Check for boolean blindness in function signatures *)
let check_boolean_blindness ~filename ~outline =
  match outline with
  | None -> []
  | Some items ->
      List.filter_map
        (fun (item : Outline.item) ->
          match (item.kind, item.type_sig) with
          | Outline.Value, Some sig_str when String.contains sig_str '>' ->
              let bool_count = count_bool_params sig_str in
              if bool_count >= 2 then
                Some
                  (Issue.Boolean_blindness
                     {
                       function_name = item.name;
                       location = extract_location filename item;
                       bool_count;
                       signature = sig_str;
                     })
              else None
          | _ -> None)
        items

(** Main check function *)
let check ~filename ~outline (_typedtree : Typedtree.t) =
  check_boolean_blindness ~filename ~outline
