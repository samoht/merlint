open Printf

let read_file path =
  if Sys.file_exists path then (
    let ic = open_in path in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    Some content)
  else None

(* Extract error code from directory name, e.g., "e105.t" -> "E105" *)
let extract_error_code dir_name =
  if String.length dir_name > 2 && String.ends_with ~suffix:".t" dir_name then
    let code = String.sub dir_name 0 (String.length dir_name - 2) in
    Some (String.uppercase_ascii code)
  else None

(* Convert filename to valid OCaml identifier *)
let filename_to_identifier filename =
  (* Replace dots and non-alphanumeric chars with underscore *)
  let buf = Buffer.create (String.length filename) in
  String.iter
    (fun c ->
      if
        (c >= 'a' && c <= 'z')
        || (c >= 'A' && c <= 'Z')
        || (c >= '0' && c <= '9')
        || c = '_'
      then Buffer.add_char buf c
      else Buffer.add_char buf '_')
    filename;
  Buffer.contents buf

let collect_example_files test_dir =
  if Sys.file_exists test_dir && Sys.is_directory test_dir then
    let files = Sys.readdir test_dir |> Array.to_list in
    List.filter
      (fun f ->
        Filename.check_suffix f ".ml"
        || Filename.check_suffix f ".mli"
        || f = "dune" || f = ".ocamlformat")
      files
    |> List.sort String.compare
  else []

let generate () =
  (* When run by dune, we're in _build/default, so need ../../test/cram *)
  let cram_dir = "../../test/cram" in
  let test_dirs =
    Sys.readdir cram_dir |> Array.to_list
    |> List.filter (fun e ->
           Filename.check_suffix e ".t"
           && Sys.is_directory (Filename.concat cram_dir e))
    |> List.sort String.compare
  in

  printf "(** Auto-generated examples from test/cram/*.t/\n";
  printf "    DO NOT EDIT - Run 'dune build @gen' to regenerate *)\n\n";

  List.iter
    (fun dir_name ->
      let test_dir = Filename.concat cram_dir dir_name in
      match extract_error_code dir_name with
      | Some error_code ->
          let files = collect_example_files test_dir in
          if files <> [] then (
            printf "module %s = struct\n" error_code;
            List.iter
              (fun filename ->
                let file_path = Filename.concat test_dir filename in
                match read_file file_path with
                | Some content ->
                    let var_name = filename_to_identifier filename in
                    printf "  let %s = {|%s|}\n" var_name content
                | None -> ())
              files;
            printf "end\n\n")
      | None -> eprintf "Warning: Invalid directory name %s\n" dir_name)
    test_dirs

let () = generate ()
