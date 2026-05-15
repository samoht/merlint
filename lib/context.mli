(** Context for rule checking - holds all parameters and data needed by rules.
*)

exception Analysis_error of string
(** Raised when analysis fails (e.g., Merlint_backend error, file read error).
*)

type file = {
  filename : string;  (** The current file being analyzed. *)
  config : Config.t;  (** The merlint configuration. *)
  project_root : string;  (** The project root directory. *)
  view : File_view.t;
      (** Unified file view: shared parsetree, raw content, Merlin outline /
          dump. See {!File_view}. *)
}

type project = {
  config : Config.t;  (** The merlint configuration. *)
  project_root : string;  (** The project root directory. *)
  all_files : string list Lazy.t;  (** All files in the project (lazy). *)
  dune_describe : Dune_describe.describe Lazy.t;
      (** Dune project description (lazy). *)
  executable_modules : string list Lazy.t;
      (** List of executable module names (lazy). *)
  lib_modules : string list Lazy.t;  (** List of library module names (lazy). *)
  test_modules : string list Lazy.t;  (** List of test module names (lazy). *)
  index : Project_index.t Lazy.t;
      (** Monopam package/library index: opam pkg -> dune library -> modules,
          tags, depends, source directories. Walks the monorepo source tree and
          the [_opam/lib/] install tree. Built lazily on first access. *)
}

val file :
  filename:string ->
  config:Config.t ->
  project_root:string ->
  outline:(unit -> (Outline.t, string) result) ->
  dump:(unit -> (Merlin.Dump.t, string) result) ->
  file
(** [file ~filename ~config ~project_root ~outline ~dump] creates a file
    context. The [outline] and [dump] thunks are invoked on first access (via
    {!val-outline} / {!val-dump}); rules that don't touch either pay no Merlin
    cost. *)

val project :
  config:Config.t ->
  project_root:string ->
  all_files:string list ->
  dune_describe:Dune_describe.describe ->
  index:Project_index.t Lazy.t ->
  project
(** [project ~config ~project_root ~all_files ~dune_describe ~index] creates a
    project context. [index] is the lazy monopam index (built once per run). *)

val index : project -> Project_index.t
(** [index p] forces and returns the monopam package/library index. *)

(** {2 File context accessors} *)

val view : file -> File_view.t
(** [view file] returns the underlying {!File_view.t}. *)

val ast : file -> Ast.t
(** [ast file] returns the control-flow AST. *)

val dump : file -> Merlin.Dump.t
(** [dump file] returns the Merlin dump (identifiers, variants, patterns). *)

val outline : file -> Outline.t
(** [outline file] returns the Merlin outline. *)

val content : file -> string
(** [content file] returns the raw file bytes. *)

val functions : file -> (string * Ast.expr) list
(** [functions file] returns top-level functions extracted from the shared
    parsetree. *)

val parsetree : file -> Parsetree.structure option
(** [parsetree file] returns the shared compiler-libs parsetree. [None] for
    [.mli] and parse errors. *)

(** {2 Project context accessors} *)

val all_files : project -> string list
(** [all_files project] returns all files. *)

val executable_modules : project -> string list
(** [executable_modules project] returns executable module names. *)

val lib_modules : project -> string list
(** [lib_modules project] returns library module names. *)

val test_modules : project -> string list
(** [test_modules project] returns test module names. *)

val dune_describe : project -> Dune_describe.describe
(** [dune_describe project] returns the dune project description. *)
