(** Merlin dump commands for merlint.

    This module provides the dump functionality (typedtree/parsetree) that's
    specific to merlint's code analysis needs. *)

let src = Logs.Src.create "merlint.merlin_dump" ~doc:"Merlin dump interface"

module Log = (val Logs.src_log src : Logs.LOG)

(* JSON schema for dump responses using jsont *)
type raw_dump_response = { dump_class : string option; dump_value : string }

let raw_dump_response_jsont =
  Jsont.Object.map ~kind:"dump_response" (fun dump_class dump_value ->
      { dump_class; dump_value })
  |> Jsont.Object.opt_mem "class" Jsont.string ~enc:(fun r -> r.dump_class)
  |> Jsont.Object.mem "value" Jsont.string ~enc:(fun r -> r.dump_value)
  |> Jsont.Object.skip_unknown |> Jsont.Object.finish

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
      match Jsont_bytesrw.decode_string raw_dump_response_jsont json_str with
      | Ok response -> Ok response.dump_value
      | Error msg ->
          Log.err (fun m -> m "Failed to parse Merlin JSON for %s: %s" file msg);
          Error ("Failed to parse Merlin JSON: " ^ msg))

let dump file =
  match run_merlin_dump_raw "typedtree" file with
  | Ok text -> Ok (Dump.typedtree text)
  | Error msg -> (
      (* Typedtree failed, try parsetree instead *)
      Log.info (fun m ->
          m "Typedtree failed for %s, trying parsetree: %s" file msg);
      match run_merlin_dump_raw "parsetree" file with
      | Ok text -> Ok (Dump.parsetree text)
      | Error msg2 ->
          Error
            ("Both typedtree and parsetree failed: " ^ msg ^ ", " ^ msg2))
