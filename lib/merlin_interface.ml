let run_merlin_dump file =
  let cmd = Printf.sprintf "ocamlmerlin single dump -what browse -filename %s < %s" file file in
  let ic = Unix.open_process_in cmd in
  let rec read_all acc =
    try
      let line = input_line ic in
      read_all (line :: acc)
    with End_of_file ->
      List.rev acc
  in
  let output = read_all [] in
  let status = Unix.close_process_in ic in
  match status with
  | Unix.WEXITED 0 ->
      let json_str = String.concat "\n" output in
      begin try
        Ok (Yojson.Safe.from_string json_str)
      with Yojson.Json_error msg ->
        Error (Printf.sprintf "Failed to parse Merlin output: %s" msg)
      end
  | Unix.WEXITED 127 ->
      Error "ocamlmerlin not found. Please run: eval $(opam env)"
  | Unix.WEXITED code ->
      Error (Printf.sprintf "Merlin command failed with exit code %d" code)
  | Unix.WSIGNALED n ->
      Error (Printf.sprintf "Merlin command was killed by signal %d" n)
  | Unix.WSTOPPED n ->
      Error (Printf.sprintf "Merlin command was stopped by signal %d" n)

let analyze_file config file =
  match run_merlin_dump file with
  | Ok structure -> 
      let violations = Cyclomatic_complexity.analyze_structure config structure in
      Ok violations
  | Error msg -> Error msg