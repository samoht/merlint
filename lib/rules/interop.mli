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

val oracle_dirs : Project_index.t -> oracle_dir list
(** [oracle_dirs index] returns discovered interop oracle directories under
    every in-scope package in [index]. Cached per-index for the lifetime of the
    process. *)

val oracle_dirs_for : Context.project -> oracle_dir list
(** [oracle_dirs_for ctx] returns the in-scope package interop directories. For
    focused projects that have interop scaffolding but no indexed package, it
    also inspects [test/interop/*] under the project root. *)

val script_contains : dir:string -> file:string -> affix:string -> bool
(** [script_contains ~dir ~file ~affix] is [true] when [dir/file] is a script
    file whose text contains [affix]. Missing files count as [false]. *)
