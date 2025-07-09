(** Documentation rules

    This module enforces documentation requirements for OCaml code, particularly
    ensuring that .mli files have proper module-level documentation. *)

val check_mli_files : string list -> Violation.t list
(** [check_mli_files files] checks that all .mli files have module
    documentation. *)
