(** File processing utilities *)

let is_in_examples path =
  Astring.String.is_infix ~affix:"/examples/" path
  || Astring.String.is_infix ~affix:"/example/" path

let is_in_fuzz_dir file =
  let dir = Fpath.parent file |> Fpath.basename in
  String.equal dir "fuzz"

let is_in_test_dir file =
  let dir = Fpath.parent file |> Fpath.basename in
  String.equal dir "test"

let is_in_private_library dune_describe filename =
  let fp = Fpath.v filename |> Fpath.normalize in
  List.exists
    (fun (lib : Dune_describe.library_info) ->
      Option.is_none lib.public_name
      && List.exists (fun f -> Fpath.equal (Fpath.normalize f) fp) lib.files)
    (Dune_describe.libraries dune_describe)

let process_ocaml_files ctx f =
  Context.analyze_set ctx
  |> List.concat_map (fun filename ->
      if File_kind.is_ml_or_mli filename then
        try
          let content = Context.file_content ctx filename in
          f filename content
        with Sys_error _ -> []
      else [])

let process_lines_with_location filename content f =
  let lines = String.split_on_char '\n' content in
  List.concat_map
    (fun (line_idx, line) ->
      let location =
        Location.v ~file:filename ~start_line:(line_idx + 1) ~start_col:0
          ~end_line:(line_idx + 1) ~end_col:(String.length line)
      in
      match f line_idx line location with
      | Some result -> [ result ]
      | None -> [])
    (List.mapi (fun i line -> (i, line)) lines)
