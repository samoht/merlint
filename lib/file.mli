(** File processing utilities. *)

val process_ocaml_files :
  Context.project -> (string -> string -> 'a list) -> 'a list
(** [process_ocaml_files ctx f] processes all OCaml files in project with
    function [f]. *)

val process_lines_with_location :
  string -> string -> (int -> string -> Location.t -> 'a option) -> 'a list
(** [process_lines_with_location filename content f] processes lines with
    location information. *)
