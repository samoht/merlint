(** Generic command execution utility *)

let src = Logs.Src.create "merlint.command" ~doc:"Command execution"

module Log = (val Logs.src_log src : Logs.LOG)

let err fmt = Fmt.kstr (fun s -> Error s) fmt

(* What the command said on its way out. Without it a caller sees only an exit
   code, and cannot tell a busy build daemon from broken code -- dune reports
   both by exiting 1, and says which on stderr. *)
let with_diagnosis message = function
  | "" -> message
  | diagnosis -> Fmt.str "%s: %s" message (String.trim diagnosis)

(* The failure is returned, not announced. Its one caller decides what to do
   about it and says so in its own words; logging it here as well put the same
   sentence on the terminal twice, once in a voice that reads as the last word
   on it and once in the voice that actually is. *)
let err_exit_code ~diagnosis code =
  let message = Fmt.str "Command failed with exit code %d" code in
  Log.info (fun m -> m "%s" (with_diagnosis message diagnosis));
  err "%s" (with_diagnosis message diagnosis)

let err_signal n =
  Log.err (fun m -> m "Command killed by signal %d" n);
  err "Command killed by signal %d" n

let err_exception exn =
  Log.err (fun m -> m "Exception running command: %s" (Printexc.to_string exn));
  err "Exception: %s" (Printexc.to_string exn)

let run mgr cmd =
  Log.info (fun m -> m "Running command: %s (cwd: %s)" cmd (Sys.getcwd ()));
  try
    let buf = Buffer.create 256 in
    let errbuf = Buffer.create 256 in
    let stdout = Eio.Flow.buffer_sink buf in
    let stderr = Eio.Flow.buffer_sink errbuf in
    let status =
      Eio.Switch.run @@ fun sw ->
      let proc =
        Eio.Process.spawn ~sw mgr ~stdout ~stderr ~executable:"/bin/sh"
          [ "sh"; "-c"; cmd ]
      in
      Eio.Process.await proc
    in
    let result = Buffer.contents buf in
    String.split_on_char '\n' result
    |> List.iter (fun line ->
        if line <> "" then Log.debug (fun m -> m "%s" line));
    match status with
    | `Exited 0 ->
        Log.info (fun m ->
            m "Command successful (output: %d bytes)" (String.length result));
        Ok result
    | `Exited 127 ->
        Log.err (fun m -> m "Command not found: %s" cmd);
        Error "Command not found"
    | `Exited code -> err_exit_code ~diagnosis:(Buffer.contents errbuf) code
    | `Signaled n -> err_signal n
  with exn -> err_exception exn
