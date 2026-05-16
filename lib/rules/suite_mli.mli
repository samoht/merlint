(** Shared helpers for [.mli] files that should expose exactly one [suite] value
    with the expected test-suite type. *)

open Ocaml_parsing

val is_compliant_signature : expected:string -> Parsetree.signature -> bool
(** [is_compliant_signature ~expected sg] is [true] iff [sg] exposes exactly one
    value, [suite], whose type structurally matches [expected]. Floating
    attributes are ignored. *)

val is_compliant_view : expected:string -> File_view.t -> bool
(** [is_compliant_view ~expected view] checks an interface through the shared
    file view cache. *)
