(** Shared helpers for E8xx interop testing rules. *)

type oracle_dir = {
  path : string;
  package : string;
  tool : string;
  has_scripts : bool;
  has_traces : bool;
  has_test_ml : bool;
  has_dune : bool;
}
(** [oracle_dir] describes one discovered interop oracle directory. *)

val oracle_dirs : string -> oracle_dir list
(** [oracle_dirs project_root] returns discovered interop oracle directories. *)

val read_file : string -> string
(** [read_file path] returns the contents of [path], or an empty string. *)

val dune_content : string -> string
(** [dune_content dir] returns the contents of [dir/dune], or an empty string. *)

val test_content : string -> string
(** [test_content dir] returns the contents of [dir/test.ml], or an empty string. *)
