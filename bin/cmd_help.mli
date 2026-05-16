(** [merlint help <topic>]: render the manual for [merlint] or one of its
    subcommands. *)

val cmd : unit Cmdliner.Cmd.t
(** [cmd] is the [merlint help] subcommand definition. *)
