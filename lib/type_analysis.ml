(** Type signature analysis utilities *)

let is_function_type signature =
  String.contains signature '-' && String.contains signature '>'

let extract_return_type signature =
  (* Extract the rightmost part after -> *)
  match String.rindex_opt signature '>' with
  | Some idx when idx > 0 && signature.[idx - 1] = '-' ->
      let return_part =
        String.sub signature (idx + 1) (String.length signature - idx - 1)
      in
      String.trim return_part
  | _ -> signature

let count_parameters signature param_type =
  (* Count occurrences of param_type in function signature *)
  let rec count_matches str pattern acc start =
    match String.index_from_opt str start pattern.[0] with
    | None -> acc
    | Some idx ->
        if
          String.length str >= idx + String.length pattern
          && String.sub str idx (String.length pattern) = pattern
        then count_matches str pattern (acc + 1) (idx + String.length pattern)
        else count_matches str pattern acc (idx + 1)
  in
  count_matches signature param_type 0 0
