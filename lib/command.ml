(** Generic command execution utility *)

let src = Logs.Src.create "merlint.command" ~doc:"Command execution"

module Log = (val Logs.src_log src : Logs.LOG)

let err_exit_code code =
  Log.err (fun m -> m "Command failed with exit code %d" code);
  Error (Fmt.str "Command failed with exit code %d" code)

let err_signal n =
  Log.err (fun m -> m "Command killed by signal %d" n);
  Error (Fmt.str "Command killed by signal %d" n)

let err_exception exn =
  Log.err (fun m -> m "Exception running command: %s" (Printexc.to_string exn));
  Error (Fmt.str "Exception: %s" (Printexc.to_string exn))

let run mgr cmd =
  Log.info (fun m -> m "Running command: %s (cwd: %s)" cmd (Sys.getcwd ()));
  try
    let buf = Buffer.create 256 in
    let stdout = Eio.Flow.buffer_sink buf in
    let status =
      Eio.Switch.run @@ fun sw ->
      let proc =
        Eio.Process.spawn ~sw mgr ~stdout ~executable:"/bin/sh"
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
    | `Exited code -> err_exit_code code
    | `Signaled n -> err_signal n
  with exn -> err_exception exn
