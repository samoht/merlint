(** File processing utilities *)

let process_ocaml_files ctx f =
  let files = Context.all_files ctx in
  List.concat_map
    (fun filename ->
      if
        String.ends_with ~suffix:".ml" filename
        || String.ends_with ~suffix:".mli" filename
      then
        try
          let content =
            In_channel.with_open_text filename In_channel.input_all
          in
          f filename content
        with _ -> []
      else [])
    files

let process_lines_with_location filename content f =
  let lines = String.split_on_char '\n' content in
  List.concat_map
    (fun (line_idx, line) ->
      let location =
        Location.create ~file:filename ~start_line:(line_idx + 1) ~start_col:0
          ~end_line:(line_idx + 1) ~end_col:(String.length line)
      in
      match f line_idx line location with
      | Some result -> [ result ]
      | None -> [])
    (List.mapi (fun i line -> (i, line)) lines)
