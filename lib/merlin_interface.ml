let run_merlin_dump_raw format file =
  let cmd =
    Printf.sprintf "ocamlmerlin single dump -what %s -filename %s < %s" format
      file file
  in
  let ic = Unix.open_process_in cmd in
  let rec read_all acc =
    try
      let line = input_line ic in
      read_all (line :: acc)
    with End_of_file -> List.rev acc
  in
  let output = read_all [] in
  let status = Unix.close_process_in ic in
  match status with
  | Unix.WEXITED 0 -> (
      let json_str = String.concat "\n" output in
      try Ok (Yojson.Safe.from_string json_str)
      with Yojson.Json_error msg ->
        Error (Printf.sprintf "Failed to parse Merlin JSON: %s" msg))
  | Unix.WEXITED 127 ->
      Error "ocamlmerlin not found. Please run: eval $(opam env)"
  | Unix.WEXITED code ->
      Error (Printf.sprintf "Merlin command failed with exit code %d" code)
  | Unix.WSIGNALED n ->
      Error (Printf.sprintf "Merlin command was killed by signal %d" n)
  | Unix.WSTOPPED n ->
      Error (Printf.sprintf "Merlin command was stopped by signal %d" n)

let run_merlin_dump_with_format format file =
  match run_merlin_dump_raw format file with
  | Ok json -> (
      match json with
      | `Assoc fields -> (
          match List.assoc_opt "value" fields with
          | Some value -> Ok value
          | None -> Error "Failed to extract value from Merlin output")
      | _ -> Error "Invalid Merlin JSON format")
  | Error msg -> Error msg

let run_merlin_dump_full_json format file = run_merlin_dump_raw format file

let analyze_file config file =
  (* Use browse for complexity analysis (needs full JSON) *)
  let complexity_violations =
    match run_merlin_dump_full_json "browse" file with
    | Ok full_json -> Cyclomatic_complexity.analyze_structure config full_json
    | Error _ -> []
  in

  (* Use parsetree for naming and style analysis (needs extracted value) *)
  let naming_and_style_violations =
    match run_merlin_dump_with_format "parsetree" file with
    | Ok structure ->
        let naming_violations = Naming_rules.check structure in
        let style_violations = Style_rules.check structure in
        naming_violations @ style_violations
    | Error _ -> []
  in

  Ok (complexity_violations @ naming_and_style_violations)
