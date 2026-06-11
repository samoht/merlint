(** Runtime probes emitted by merlint. *)

val analysis :
  project_root:string -> files:int -> rules:int -> (unit -> 'a) -> 'a
(** [analysis ~project_root ~files ~rules f] runs [f] inside the top-level
    analysis span. *)

val project_rules : rules:int -> jobs:int -> (unit -> 'a) -> 'a
(** [project_rules ~rules ~jobs f] runs [f] inside the project-rule batch span.
*)

val project_rule : rule:string -> (unit -> 'a) -> 'a
(** [project_rule ~rule f] runs [f] inside a single project-rule span. *)

val file_analysis :
  file:string -> file_rules:int -> pass_rules:int -> (unit -> 'a) -> 'a
(** [file_analysis ~file ~file_rules ~pass_rules f] runs [f] inside the per-file
    analysis span. *)

val file_rule : rule:string -> file:string -> (unit -> 'a) -> 'a
(** [file_rule ~rule ~file f] runs [f] inside a direct file-rule span. *)
