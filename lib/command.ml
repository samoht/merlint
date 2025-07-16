(** Generic command execution utility *)

let src = Logs.Src.create "merlint.command" ~doc:"Command execution"

module Log = (val Logs.src_log src : Logs.LOG)

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
        Error (Fmt.str "Command failed with exit code %d" code)
    | Unix.WSIGNALED n ->
        Log.err (fun m -> m "Command killed by signal %d" n);
        Error (Fmt.str "Command killed by signal %d" n)
    | Unix.WSTOPPED n ->
        Log.err (fun m -> m "Command stopped by signal %d" n);
        Error (Fmt.str "Command stopped by signal %d" n)
  with exn ->
    Log.err (fun m ->
        m "Exception running command: %s" (Printexc.to_string exn));
    Error (Fmt.str "Exception: %s" (Printexc.to_string exn))
