(** Shared helpers for [.mli] files that should expose exactly one [suite] value
    with the expected test-suite type. *)

val is_compliant_view : expected:string -> File_view.t -> bool
(** [is_compliant_view ~expected view] checks an interface through the shared
    file view cache. *)
