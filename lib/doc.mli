(** Legacy documentation module - all checks have been moved to rules/e400.ml *)

val check_mli_documentation_content :
  module_name:string -> filename:string -> string -> Issue.t option
(** Legacy function for unit tests - exposed for testing *)

val check_mli_files : string list -> Issue.t list
(** Legacy function for unit tests - now delegates to E400.check *)
