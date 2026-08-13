(** Project root discovery *)

val root : string -> string
(** [root path] finds the enclosing Dune root: the nearest [dune-workspace]
    ancestor when present, otherwise the nearest [dune-project]. If [path] is a
    directory, searches from that directory. If [path] is a file, searches from
    its parent directory. Returns the current working directory if no project
    root is found. *)

val workspace_root : string -> string
(** [workspace_root path] is kept for compatibility and uses the same Dune root
    policy as {!root}. *)

val config_files : string -> string list
(** [config_files path] returns all [merlint.toml] config file paths from [path]
    up to the workspace root, ordered outermost-first. Closer configs override
    settings from outer ones; exclusions accumulate. *)

type link = {
  checkout : Fpath.t;  (** the checkout's own Dune root *)
  workspace : Fpath.t;  (** the Dune workspace that builds it *)
  path : Fpath.t;  (** the directory that workspace reaches the checkout by *)
}
(** The type for a checkout built from a workspace elsewhere. *)

val workspace_link : string -> (link option, string) result
(** [workspace_link path] is the workspace the checkout enclosing [path]
    declares it is built from, as [workspace = "<path>"] in its [merlint.toml],
    with the directory that workspace reaches the checkout by.

    A checkout whose dependencies resolve only inside a larger workspace is
    built there, and its [.cmt]/[.cmti] artefacts are written there too, so it
    must be analysed as the workspace knows it. Nothing in the checkout points
    back at the workspace, and several workspaces may link the same sources, so
    the checkout names the one that builds it. The declared path is relative to
    the [merlint.toml] that sets it.

    [Ok None] when no [merlint.toml] up to the workspace root declares one, or
    when the declared workspace is the checkout's own Dune root, so a run
    started inside the workspace stays put.

    [Error] says why a declaration cannot be honoured -- the declared directory
    is not a Dune root, or its source tree does not reach this checkout, which
    is what a second working tree of the checkout sees. It is a reason to
    analyse the checkout where it stands, not a reason to refuse: a checkout
    that builds where it is needs no declaration to be checked, and one that
    does not is told so by the run itself. *)

module Query : sig
  (** Structural queries over the shared {!Project_index.t}. These helpers
      answer project-shape questions for rules without re-reading or re-parsing
      dune files. *)

  val source_libraries : Project_index.t -> Project_index.Library.t list
  (** [source_libraries index] returns every library stanza discovered in the
      source tree. *)

  val library_module_map : Project_index.t -> (string * string list) list
  (** [library_module_map index] maps each [.ml] module basename to the local
      names of source libraries that own it. *)

  val library_module_map_of :
    Project_index.Library.t list -> (string * string list) list
  (** [library_module_map_of libs] is {!library_module_map} restricted to
      [libs], for callers that resolve modules within a single package rather
      than across the whole workspace (bare module names collide between
      unrelated packages). *)

  val resolve_library : Project_index.t -> string -> string
  (** [resolve_library index name] maps a public library reference back to the
      local stanza name when the referenced library is in the source tree.
      Unknown and already-local names pass through unchanged. *)

  val test_file_library : (string * string list) list -> string -> string option
  (** [test_file_library module_map basename] returns the unique source library
      tested by [basename] when [basename] follows the [test_<module>] naming
      convention. *)
end
