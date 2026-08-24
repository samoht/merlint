(** File processing utilities. *)

val is_in_examples : string -> bool
(** [is_in_examples path] returns [true] if [path] is in an examples directory.
*)

val is_in_fuzz_dir : Fpath.t -> bool
(** [is_in_fuzz_dir file] returns [true] if [file] is below a directory named
    [fuzz], at any depth: [fuzz/eio/fuzz_chaos.ml] is in a fuzz directory as
    much as [fuzz/fuzz_chaos.ml] is, because a package that fuzzes an Eio
    adapter separately from its pure core puts the adapter's driver there. The
    path should be relative to the analyzed project root, as for
    {!is_test_path}: the answer is read off the path's segments, so a segment
    named [fuzz] above that root would count. *)

val is_in_test_dir : Fpath.t -> bool
(** [is_in_test_dir file] returns [true] if [file] is in a test directory. *)

val is_test_path : Fpath.t -> bool
(** [is_test_path file] returns [true] if [file] names a test module or is below
    a [test] or [tests] directory. The path should be relative to the analyzed
    project root when checking project-local conventions. *)

val is_test : string -> bool
(** [is_test filename] is [is_test_path (Fpath.v filename)]. *)

val is_unit_companion_module : string -> bool
(** [is_unit_companion_module basename] returns [true] when [basename] is a
    companion implementation module such as [foo_intf]. These files belong to
    the same unit as [foo.ml]/[foo.mli], rather than defining a separate
    module-level API or test suite. *)

val is_in_private_library : Project_index.t -> string -> bool
(** [is_in_private_library index filename] returns [true] if [filename] belongs
    to a private library (no public_name). *)

val is_in_private_library_path : Project_index.t -> Fpath.t -> bool
(** [is_in_private_library_path index file] returns [true] if [file] belongs to
    a private library (no public_name). *)

val process_lines_with_location :
  string -> string -> (int -> string -> Location.t -> 'a option) -> 'a list
(** [process_lines_with_location filename content f] processes lines with
    location information. *)
