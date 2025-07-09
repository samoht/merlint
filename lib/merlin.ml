(** Wrapper for OCaml Merlin commands *)

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

let dump = run_merlin_dump_raw

let dump_value format file =
  match run_merlin_dump_raw format file with
  | Ok json -> (
      match json with
      | `Assoc fields -> (
          match List.assoc_opt "value" fields with
          | Some value -> Ok value
          | None -> Error "Failed to extract value from Merlin output")
      | _ -> Error "Invalid Merlin JSON format")
  | Error msg -> Error msg
