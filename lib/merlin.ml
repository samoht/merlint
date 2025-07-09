(** Wrapper for OCaml Merlin commands *)

let src = Logs.Src.create "merlint.merlin" ~doc:"Merlin interface"
module Log = (val Logs.src_log src : Logs.LOG)

type file_analysis = {
  browse: (Yojson.Safe.t, string) result;
  parsetree: (Yojson.Safe.t, string) result;
  outline: (Yojson.Safe.t, string) result;
}

let get_outline file =
  (* Ensure file exists before trying to analyze it *)
  if not (Sys.file_exists file) then
    Error (Printf.sprintf "File not found: %s" file)
  else
    let cmd = Printf.sprintf "ocamlmerlin single outline -filename %s < %s" (Filename.quote file) (Filename.quote file) in
    Log.info (fun m -> m "Running merlin outline command: %s" cmd);
    try
    let ic = Unix.open_process_in cmd in
    let rec read_all acc =
      try
        let line = input_line ic in
        read_all (line :: acc)
      with End_of_file -> List.rev acc
    in
    let lines = read_all [] in
    let content = String.concat "\n" lines in
    let _ = Unix.close_process_in ic in
    Log.debug (fun m -> m "Merlin outline result length: %d chars" (String.length content));
    match Yojson.Safe.from_string content with
    | `Assoc fields -> (
        match List.assoc_opt "value" fields with
        | Some outline -> 
            Log.debug (fun m -> m "Successfully extracted outline for %s" file);
            Ok outline
        | None -> 
            Log.warn (fun m -> m "No value in outline response for %s" file);
            Error "No value in outline response")
    | _ -> 
        Log.warn (fun m -> m "Invalid outline response format for %s" file);
        Error "Invalid outline response format"
  with
  | exn -> 
    Log.err (fun m -> m "Exception in get_outline for %s: %s" file (Printexc.to_string exn));
    Error (Printexc.to_string exn)

let run_merlin_dump_raw format file =
  let cmd =
    Printf.sprintf "ocamlmerlin single dump -what %s -filename %s < %s" format
      (Filename.quote file) (Filename.quote file)
  in
  Log.info (fun m -> m "Running merlin dump command: %s" cmd);
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
      Log.debug (fun m -> m "Merlin dump successful for %s, JSON length: %d" file (String.length json_str));
      try Ok (Yojson.Safe.from_string json_str)
      with Yojson.Json_error msg ->
        Log.err (fun m -> m "Failed to parse Merlin JSON for %s: %s" file msg);
        Error (Printf.sprintf "Failed to parse Merlin JSON: %s" msg))
  | Unix.WEXITED 127 ->
      Log.err (fun m -> m "ocamlmerlin not found when processing %s" file);
      Error "ocamlmerlin not found. Please run: eval $(opam env)"
  | Unix.WEXITED code ->
      Log.err (fun m -> m "Merlin command failed for %s with exit code %d" file code);
      Error (Printf.sprintf "Merlin command failed with exit code %d" code)
  | Unix.WSIGNALED n ->
      Log.err (fun m -> m "Merlin command killed by signal %d for %s" n file);
      Error (Printf.sprintf "Merlin command was killed by signal %d" n)
  | Unix.WSTOPPED n ->
      Log.err (fun m -> m "Merlin command stopped by signal %d for %s" n file);
      Error (Printf.sprintf "Merlin command was stopped by signal %d" n)

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

let analyze_file file =
  (* Run all three merlin commands for the file *)
  Log.info (fun m -> m "Analyzing file %s with merlin" file);
  {
    browse = dump_value "browse" file;
    parsetree = dump_value "parsetree" file;
    outline = get_outline file;
  }
