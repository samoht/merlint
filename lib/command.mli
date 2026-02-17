(** Generic command execution utility. *)

val run : _ Eio.Process.mgr -> string -> (string, string) result
(** [run mgr cmd] executes shell command. *)
