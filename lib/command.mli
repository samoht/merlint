(** Generic command execution utility *)

val run : string -> (string, string) result
(** [run cmd] executes a shell command and returns its stdout or an error.
    Returns Ok with the command output on success, or Error with an error
    message on failure. *)
