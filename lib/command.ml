(** Generic command execution utility *)

let src = Logs.Src.create "merlint.command" ~doc:"Command execution"

module Log = (val Logs.src_log src : Logs.LOG)

(* Error helper functions *)
let err_exit_code code = Error (Fmt.str "Command failed with exit code %d" code)
let err_signal n = Error (Fmt.str "Command killed by signal %d" n)
let err_stopped n = Error (Fmt.str "Command stopped by signal %d" n)
let err_exception exn = Error (Fmt.str "Exception: %s" (Printexc.to_string exn))

let run cmd =
  Log.debug (fun m -> m "Running command: %s" cmd);
  try
    let ic = Unix.open_process_in cmd in
    let rec read_all acc =
      try
        let line = input_line ic in
        read_all (line :: acc)
      with End_of_file -> List.rev acc
    in
    let output = read_all [] in
    let status = Unix.close_process_in ic in
    let result = String.concat "\n" output in
    match status with
    | Unix.WEXITED 0 ->
        Log.debug (fun m ->
            m "Command successful, output length: %d" (String.length result));
        Ok result
    | Unix.WEXITED 127 ->
        Log.err (fun m -> m "Command not found: %s" cmd);
        Error "Command not found"
    | Unix.WEXITED code ->
        Log.err (fun m -> m "Command failed with exit code %d" code);
        err_exit_code code
    | Unix.WSIGNALED n ->
        Log.err (fun m -> m "Command killed by signal %d" n);
        err_signal n
    | Unix.WSTOPPED n ->
        Log.err (fun m -> m "Command stopped by signal %d" n);
        err_stopped n
  with exn ->
    Log.err (fun m ->
        m "Exception running command: %s" (Printexc.to_string exn));
    err_exception exn
