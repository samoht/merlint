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

let rec collect_files_recursively base_dir current_path =
  let full_path =
    if current_path = "" then base_dir
    else Filename.concat base_dir current_path
  in

  if Sys.file_exists full_path && Sys.is_directory full_path then
    let entries = Sys.readdir full_path |> Array.to_list in
    List.fold_left
      (fun acc entry ->
        let entry_path =
          if current_path = "" then entry
          else Filename.concat current_path entry
        in
        let full_entry_path = Filename.concat base_dir entry_path in

        if Sys.is_directory full_entry_path then
          (* Skip _build directories *)
          if entry = "_build" then acc
          else
            (* Recursively collect from subdirectory *)
            acc @ collect_files_recursively base_dir entry_path
        else if
          Filename.check_suffix entry ".ml"
          || Filename.check_suffix entry ".mli"
        then
          (* Include the relative path from test_dir *)
          (entry_path, full_entry_path) :: acc
        else acc)
      [] entries
    |> List.sort (fun (a, _) (b, _) -> String.compare a b)
  else []

let get_test_directories cram_dir =
  Sys.readdir cram_dir |> Array.to_list
  |> List.filter (fun e ->
         Filename.check_suffix e ".t"
         && Sys.is_directory (Filename.concat cram_dir e))
  |> List.sort String.compare

let group_files_by_directory files =
  let by_dir = Hashtbl.create 10 in
  List.iter
    (fun (rel_path, full_path) ->
      let dir = Filename.dirname rel_path in
      let basename = Filename.basename rel_path in
      let existing = try Hashtbl.find by_dir dir with Not_found -> [] in
      Hashtbl.replace by_dir dir ((basename, full_path) :: existing))
    files;
  Hashtbl.fold (fun k v acc -> (k, v) :: acc) by_dir []
  |> List.sort (fun (a, _) (b, _) -> String.compare a b)

let sanitize_module_name dir =
  let name = String.capitalize_ascii dir in
  String.map
    (fun c ->
      if
        (c >= 'A' && c <= 'Z')
        || (c >= 'a' && c <= 'z')
        || (c >= '0' && c <= '9')
        || c = '_'
      then c
      else '_')
    name

let print_file_content indent filename full_path =
  match read_file full_path with
  | Some content ->
      let var_name = filename_to_identifier filename in
      Fmt.pr "%s  let %s = {|%s|}\n" indent var_name content
  | None -> ()

let process_directory (dir, dir_files) =
  if dir = "." then
    (* Top-level files *)
    List.iter
      (fun (filename, full_path) -> print_file_content "" filename full_path)
      (List.rev dir_files)
  else
    (* Subdirectory - create nested module *)
    let module_name = sanitize_module_name dir in
    Fmt.pr "  module %s = struct\n" module_name;
    List.iter
      (fun (filename, full_path) -> print_file_content "  " filename full_path)
      (List.rev dir_files);
    Fmt.pr "  end\n"

let process_test_directory cram_dir dir_name =
  let test_dir = Filename.concat cram_dir dir_name in
  match extract_error_code dir_name with
  | Some error_code ->
      let files = collect_files_recursively test_dir "" in
      if files <> [] then (
        Fmt.pr "module %s = struct\n" error_code;
        let sorted_dirs = group_files_by_directory files in
        List.iter process_directory sorted_dirs;
        Fmt.pr "end\n\n")
  | None -> Fmt.epr "Warning: Invalid directory name %s\n" dir_name

let generate () =
  let cram_dir = "test/cram" in
  let test_dirs = get_test_directories cram_dir in

  Fmt.pr "(** Auto-generated examples from test/cram/*.t/\n";
  Fmt.pr "    DO NOT EDIT - Run 'dune build @gen' to regenerate *)\n\n";

  List.iter (process_test_directory cram_dir) test_dirs

let () = generate ()
