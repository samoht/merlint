(** Wrapper for OCaml Merlin commands *)

let src = Logs.Src.create "merlint.merlin" ~doc:"Merlin interface"

module Log = (val Logs.src_log src : Logs.LOG)

(* Error helper functions *)
let err_file_not_found file = Error ("File not found: " ^ file)
let err_json_parse msg = Error ("Failed to parse Merlin JSON: " ^ msg)

let err_both_failed msg1 msg2 =
  Error ("Both typedtree and parsetree failed: " ^ msg1 ^ ", " ^ msg2)

type t = {
  outline : (Outline.t, string) result;
  dump : (Dump.t, string) result;
}

(** Standard functions using polymorphic equality and comparison *)
let equal = ( = )

let compare = compare

let pp ppf t =
  let pp_result pp_ok ppf = function
    | Ok v -> pp_ok ppf v
    | Error e -> Fmt.pf ppf "Error: %s" e
  in
  Fmt.pf ppf "@[<v>Merlin result:@,  outline: %a@,  dump: %a@]"
    (pp_result Outline.pp) t.outline (pp_result Dump.pp) t.dump

let outline file =
  (* Ensure file exists before trying to analyze it *)
  if not (Sys.file_exists file) then err_file_not_found file
  else
    let cmd =
      Fmt.str "ocamlmerlin single outline -filename %s < %s"
        (Filename.quote file) (Filename.quote file)
    in
    Log.info (fun m -> m "Running merlin outline command: %s" cmd);
    match Command.run cmd with
    | Error msg ->
        Log.err (fun m -> m "Merlin outline command failed: %s" msg);
        Error msg
    | Ok content -> (
        Log.debug (fun m ->
            m "Merlin outline result length: %d chars" (String.length content));
        try
          match Yojson.Safe.from_string content with
          | `Assoc fields -> (
              match List.assoc_opt "value" fields with
              | Some outline ->
                  Log.debug (fun m ->
                      m "Successfully extracted outline for %s" file);
                  Ok (Outline.of_json outline)
              | None ->
                  Log.warn (fun m ->
                      m "No value in outline response for %s" file);
                  Error "No value in outline response")
          | _ ->
              Log.warn (fun m ->
                  m "Invalid outline response format for %s" file);
              Error "Invalid outline response format"
        with exn ->
          Log.err (fun m ->
              m "Exception parsing outline for %s: %s" file
                (Printexc.to_string exn));
          Error (Printexc.to_string exn))

let run_merlin_dump_raw format file =
  let cmd =
    Fmt.str "ocamlmerlin single dump -what %s -filename %s < %s" format
      (Filename.quote file) (Filename.quote file)
  in
  Log.info (fun m -> m "Running merlin dump command: %s" cmd);
  match Command.run cmd with
  | Error msg ->
      Log.err (fun m -> m "Merlin dump command failed: %s" msg);
      Error msg
  | Ok json_str -> (
      Log.debug (fun m ->
          m "Merlin dump successful for %s, JSON length: %d" file
            (String.length json_str));
      try Ok (Yojson.Safe.from_string json_str)
      with Yojson.Json_error msg ->
        Log.err (fun m -> m "Failed to parse Merlin JSON for %s: %s" file msg);
        err_json_parse msg)

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

let dump file =
  match dump_value "typedtree" file with
  | Ok json -> (
      match json with
      | `String text -> Ok (Dump.typedtree text)
      | _ -> Error "Invalid typedtree format")
  | Error msg -> (
      (* Typedtree failed, try parsetree instead *)
      Log.info (fun m ->
          m "Typedtree failed for %s, trying parsetree: %s" file msg);
      match dump_value "parsetree" file with
      | Ok json -> (
          match json with
          | `String text -> Ok (Dump.parsetree text)
          | _ -> Error "Invalid parsetree format")
      | Error msg2 -> err_both_failed msg msg2)

let analyze_file file =
  (* Run merlin commands for the file *)
  Log.info (fun m -> m "Analyzing file %s with merlin" file);
  { outline = outline file; dump = dump file }
