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
  file_view_cache : string -> File_view.t;
      (** Project-wide memoized file views, shared by project-scoped and
          file-scoped rules. *)
}

val file :
  filename:string ->
  config:Config.t ->
  project_root:string ->
  load_content:(unit -> string) ->
  outline:(unit -> (Outline.t, string) result) ->
  dump:(unit -> (Merlin.ast_dump, string) result) ->
  file
(** [file ~filename ~config ~project_root ~load_content ~outline ~dump] creates
    a file context. [load_content], [outline] and [dump] are invoked on first
    access; rules that don't touch them pay nothing. *)

val file_with_view :
  filename:string ->
  config:Config.t ->
  project_root:string ->
  view:File_view.t ->
  file
(** [file_with_view ~filename ~config ~project_root ~view] creates a file
    context backed by an existing shared {!File_view.t}. *)

val project :
  ?file_view:(string -> File_view.t) ->
  config:Config.t ->
  project_root:string ->
  all_files:string list ->
  dune_describe:Dune_describe.describe ->
  index:Project_index.t Lazy.t ->
  unit ->
  project
(** [project ?file_view ~config ~project_root ~all_files ~dune_describe ~index
     ()] creates a project context. [index] is the lazy monopam index (built
    once per run). [file_view], when provided, is memoized and used as the
    project-wide source for per-file views. *)

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

val file_view : project -> string -> File_view.t
(** [file_view project filename] returns the shared, lazy file view for
    [filename]. *)
