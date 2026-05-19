(** Context for rule checking - holds all parameters and data needed by rules.
*)

exception Analysis_error of string
(** Raised when analysis fails (e.g., Merlint_backend error, file read error).
*)

type 'a memo
(** Opaque project memo. Values are forced only through Context accessors, so
    project rules cannot accidentally bypass the shared cache lock. *)

type file = {
  filename : string;  (** The current file being analyzed. *)
  config : Config.t;  (** The merlint configuration. *)
  project_root : string;  (** The project root directory. *)
  analyze_set : string list;  (** The source files selected for this run. *)
  selected_file : string -> bool;
      (** [selected_file file] is true when [file] is selected for this run. *)
  project_index : Project_index.t option;
      (** Shared project index, when available. *)
  view : File_view.t;
      (** Unified typedtree-backed file view. See {!File_view}. *)
  content : string Lazy.t;
      (** Raw file bytes for text-only rules. OCaml semantic rules should use
          {!view}. *)
}

type project = {
  config : Config.t;  (** The merlint configuration. *)
  project_root : string;  (** The project root directory. *)
  analyze_set : string list;
      (** The user's request: the source files matched by the [merlint <args>]
          command. Project-scoped rules use this to limit their scan to what was
          actually asked about, rather than walking the whole monorepo. *)
  in_analyze_set : string -> bool;
      (** Fast membership query for {!analyze_set}. *)
  dune_describe : Dune_describe.describe memo;
      (** Dune project description (memoized). *)
  executable_modules : string list memo;
      (** List of executable module names (memoized). *)
  lib_modules : string list memo;
      (** List of library module names (memoized). *)
  test_modules : string list memo;  (** List of test module names (memoized). *)
  index : Project_index.t memo;
      (** Monopam package/library index: opam pkg -> dune library -> modules,
          tags, depends, source directories. Walks the monorepo source tree and
          the [_opam/lib/] install tree. Built on first access. *)
  file_view_cache : string -> File_view.t;
      (** Project-wide memoized file views, shared by project-scoped and
          file-scoped rules. *)
  file_content_cache : string -> string;
      (** Project-wide memoized raw file bytes for text-format rules. *)
}

val file :
  analyze_set:string list ->
  selected_file:(string -> bool) ->
  project_index:Project_index.t option ->
  filename:string ->
  config:Config.t ->
  project_root:string ->
  load_content:(unit -> string) ->
  file
(** [file ~analyze_set ~selected_file ~project_index ~filename ~config
     ~project_root ~load_content] creates a file context. [load_content] is
    invoked on first access; rules that don't touch source data pay nothing. *)

val file_with_view :
  analyze_set:string list ->
  selected_file:(string -> bool) ->
  project_index:Project_index.t option ->
  filename:string ->
  config:Config.t ->
  project_root:string ->
  view:File_view.t ->
  load_content:(unit -> string) ->
  file
(** [file_with_view ~analyze_set ~selected_file ~project_index ~filename ~config
     ~project_root ~view ~load_content] creates a file context backed by an
    existing shared {!File_view.t}. *)

val project :
  ?file_view:(string -> File_view.t) ->
  ?file_content:(string -> string) ->
  config:Config.t ->
  project_root:string ->
  analyze_set:string list ->
  dune_describe:Dune_describe.describe ->
  index:Project_index.t Lazy.t ->
  unit ->
  project
(** [project ~config ~project_root ~analyze_set ~dune_describe ~index ()]
    creates a project context. [analyze_set] is the source set matched by the
    user's [merlint <args>] invocation; project-scoped rules should restrict
    their work to it. *)

val index : project -> Project_index.t
(** [index p] forces and returns the monopam package/library index. *)

(** {2 File context accessors} *)

val view : file -> File_view.t
(** [view file] returns the underlying {!File_view.t}. *)

val content : file -> string
(** [content file] returns the raw file bytes. *)

val values : file -> Function_metrics.value list
(** [values file] returns top-level value bindings with typedtree-derived
    control-flow metrics. *)

(** {2 Project context accessors} *)

val analyze_set : project -> string list
(** [analyze_set p] is the user's analyze-set: the source files matched by the
    [merlint <args>] invocation. *)

val project_root : project -> string
(** [project_root p] is the Dune project root used for the analysis. *)

val executable_modules : project -> string list
(** [executable_modules project] returns executable module names. *)

val lib_modules : project -> string list
(** [lib_modules project] returns library module names. *)

val test_modules : project -> string list
(** [test_modules project] returns test module names. *)

val dune_describe : project -> Dune_describe.describe
(** [dune_describe project] returns the dune project description. *)

val executable_stanzas : project -> Project_index.source_stanza list
(** [executable_stanzas project] returns the executable stanzas discovered by
    the shared project index. *)

val test_stanzas : project -> Project_index.source_stanza list
(** [test_stanzas project] returns the test stanzas discovered by the shared
    project index. *)

val file_view : project -> string -> File_view.t
(** [file_view project filename] returns the shared, lazy file view for
    [filename]. *)

val file_content : project -> string -> string
(** [file_content project filename] returns the shared raw file bytes for
    [filename]. *)
