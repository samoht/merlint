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

let is_test_file_path path =
  let path = Fpath.normalize path in
  let basename = Fpath.basename path in
  let module_name =
    Fpath.rem_ext (Fpath.v basename)
    |> Fpath.to_string |> String.lowercase_ascii
  in
  String.equal basename "test.ml"
  || String.starts_with ~prefix:"test_" module_name
  || List.exists
       (fun part -> String.equal part "test" || String.equal part "tests")
       (Fpath.segs path)

let is_test_file filename = is_test_file_path (Fpath.v filename)

let is_unit_companion_module basename =
  String.ends_with ~suffix:"_intf" basename

let is_in_private_library_path index fp =
  let fp = Fpath.normalize fp in
  Project_index.libraries_of_file index fp
  |> List.exists (fun lib ->
      Option.is_none (Project_index.Library.public_name lib))

let is_in_private_library index filename =
  is_in_private_library_path index (Fpath.v filename)

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
