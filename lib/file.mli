(** File processing utilities. *)

val is_in_examples : string -> bool
(** [is_in_examples path] returns [true] if [path] is in an examples directory.
*)

val is_in_fuzz_dir : Fpath.t -> bool
(** [is_in_fuzz_dir file] returns [true] if [file] is in a fuzz directory. *)

val is_in_test_dir : Fpath.t -> bool
(** [is_in_test_dir file] returns [true] if [file] is in a test directory. *)

val is_test_file : string -> bool
(** [is_test_file filename] returns [true] if [filename] names a test module or
    is below a [test] or [tests] directory. *)

val is_unit_companion_module : string -> bool
(** [is_unit_companion_module basename] returns [true] when [basename] is a
    companion implementation module such as [foo_intf]. These files belong to
    the same unit as [foo.ml]/[foo.mli], rather than defining a separate
    module-level API or test suite. *)

val is_in_private_library : Project_index.t -> string -> bool
(** [is_in_private_library index filename] returns [true] if [filename] belongs
    to a private library (no public_name). *)

val process_ocaml_files :
  Context.project -> (string -> string -> 'a list) -> 'a list
(** [process_ocaml_files ctx f] processes all OCaml files in project with
    function [f]. *)

val process_lines_with_location :
  string -> string -> (int -> string -> Location.t -> 'a option) -> 'a list
(** [process_lines_with_location filename content f] processes lines with
    location information. *)
