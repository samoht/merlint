(** Context for rule checking - holds all parameters and data needed by rules.
*)

exception Analysis_error of string
(** Raised when analysis fails (e.g., Merlint_backend error, file read error).
*)

type path = Path.t
(** A canonical merlint path; an alias of {!Path.t}. Use the {!Path} module's
    operations on values of this type. *)

val path : string -> path
(** [path s] is the canonical path for [s]. *)

val path_under : root:path -> string -> path
(** [path_under ~root s] resolves [s] under [root], raising [Invalid_argument]
    if it escapes [root]. *)

val fpath_of_path : path -> Fpath.t
(** [fpath_of_path p] returns [p] as an {!Fpath.t}. *)

val string_of_path : path -> string
(** [string_of_path p] returns [p]'s canonical string for external APIs and
    diagnostics. *)

val relative_to : root:path -> path -> string
(** [relative_to ~root p] is [p] relative to [root] for display, or its absolute
    string when [p] is not below [root]. *)

type 'a memo
(** Opaque project memo. Values are forced only through Context accessors, so
    project rules cannot accidentally bypass the shared cache lock. *)

type unevaluated
(** What this run's rules could not decide. A rule that consulted the project
    index for a fact the index does not hold cannot say either "this is a
    finding" or "this is clean", and the empty list it returns is the same list
    a rule that checked everything and found nothing returns. It records the
    undecided question here instead, under its own code, and the run reports it
    apart from the findings. Shared across the project rules, which run
    concurrently, so it carries its own lock. *)

type file = {
  filename : path;  (** The current file being analyzed. *)
  config : Config.t;  (** The merlint configuration. *)
  project_root : path;  (** The project root directory. *)
  analyze_set : path list;  (** The source files selected for this run. *)
  selected_file : path -> bool;
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
  project_root : path;  (** The project root directory. *)
  analyze_set : path list;
      (** The user's request: the source files matched by the [merlint <args>]
          command. Project-scoped rules use this to limit their scan to what was
          actually asked about, rather than walking the whole monorepo. *)
  in_analyze_set : path -> bool;
      (** Fast membership query for {!analyze_set}. *)
  executable_modules : string list memo;
      (** List of executable module names (memoized). *)
  lib_modules : string list memo;
      (** List of library module names (memoized). *)
  test_modules : string list memo;  (** List of test module names (memoized). *)
  index : Project_index.t memo;
      (** Monopam package/library index: opam pkg -> dune library -> modules,
          tags, depends, source directories. Walks the monorepo source tree and
          the [_opam/lib/] install tree. Built on first access. *)
  file_view_cache : path -> File_view.t;
      (** Project-wide memoized file views, shared by project-scoped and
          file-scoped rules. *)
  file_content_cache : path -> string;
      (** Project-wide memoized raw file bytes for text-format rules. *)
  unevaluated : unevaluated;
      (** The questions this run's rules could not answer. Written through
          {!cannot_evaluate}, read through {!unevaluated_questions}. *)
  index_is_partial : bool;
      (** Whether {!field-index} was built over part of the tree only. See
          {!index_is_partial}. *)
}

val file :
  analyze_set:path list ->
  selected_file:(path -> bool) ->
  project_index:Project_index.t option ->
  filename:path ->
  config:Config.t ->
  project_root:path ->
  load_content:(unit -> string) ->
  file
(** [file ~analyze_set ~selected_file ~project_index ~filename ~config
     ~project_root ~load_content] creates a file context. [load_content] is
    invoked on first access; rules that don't touch source data pay nothing. *)

val file_with_view :
  analyze_set:path list ->
  selected_file:(path -> bool) ->
  project_index:Project_index.t option ->
  filename:path ->
  config:Config.t ->
  project_root:path ->
  view:File_view.t ->
  load_content:(unit -> string) ->
  file
(** [file_with_view ~analyze_set ~selected_file ~project_index ~filename ~config
     ~project_root ~view ~load_content] creates a file context backed by an
    existing shared {!File_view.t}. *)

val project :
  ?file_view:(path -> File_view.t) ->
  ?file_content:(path -> string) ->
  ?index_is_partial:bool ->
  config:Config.t ->
  project_root:path ->
  analyze_set:path list ->
  index:Project_index.t Lazy.t ->
  unit ->
  project
(** [project ~config ~project_root ~analyze_set ~index ()] creates a project
    context. [analyze_set] is the source set matched by the user's
    [merlint <args>] invocation; project-scoped rules should restrict their work
    to it. *)

val index : project -> Project_index.t
(** [index p] forces and returns the monopam package/library index. *)

val index_is_partial : project -> bool
(** [index_is_partial p] is [true] when this run built its project index over
    part of the source tree only, because the caller named directories or files
    rather than the whole project. A lookup that resolves to nothing then says
    two different things -- nothing provides this name, or nothing this scan
    read provides it -- and a rule cannot tell which. Over a whole-project index
    the same lookup is an answer: every in-tree package was read, and anything
    else would have to come from the switch, which is scanned for exactly the
    names the sources reference. *)

val cannot_evaluate : project -> rule:string -> string -> unit
(** [cannot_evaluate p ~rule question] records that [rule] could not decide
    [question] on this run, because a fact it needed is not in the project
    index. [question] is one sentence naming what could not be resolved and what
    it was needed for; it is shown to the user verbatim.

    Call it where a resolution query answers "nothing" for a reason that is not
    an answer -- a library or binary whose providing package this run's index
    never scanned, an installed root that was not populated. Do not call it
    where "nothing" is the answer: a rule that looked and found the tree clean
    reports that by returning no issues, which is what it means. *)

val unevaluated_questions : project -> (string * string) list
(** [unevaluated_questions p] is every question recorded by {!cannot_evaluate},
    as [(rule code, question)], deduplicated and sorted. One rule asking the
    same undecidable question of forty packages is one thing the run could not
    do, not forty. *)

(** {2 File context accessors} *)

val view : file -> File_view.t
(** [view file] returns the underlying {!File_view.t}. *)

val content : file -> string
(** [content file] returns the raw file bytes. *)

val values : file -> Function_metrics.value list
(** [values file] returns top-level value bindings with typedtree-derived
    control-flow metrics. *)

val filename : file -> string
(** [filename f] returns [f.filename] as a string for diagnostics and parsers
    that still require string paths. *)

val project_root_string : file -> string
(** [project_root_string f] returns [f.project_root] as a string. *)

val file_path : file -> path
(** [file_path f] returns the normalized current file path. *)

val project_relative_file : file -> string
(** [project_relative_file f] returns [f]'s file path relative to its project
    root when possible. Use this for project-local classification such as
    [test/] and [examples/] checks. *)

val resolve_file : file -> Fpath.t -> path
(** [resolve_file f file] resolves [file] against [f]'s project root and raises
    [Invalid_argument] if the normalized path escapes that root. *)

val resolve_file_path : file -> Fpath.t -> string
(** [resolve_file_path f file] is [resolve_file f file] as a string. *)

(** {2 Project context accessors} *)

val analyze_set : project -> path list
(** [analyze_set p] is the user's analyze-set: the source files matched by the
    [merlint <args>] invocation. *)

val project_root : project -> path
(** [project_root p] is the Dune project root used for the analysis. *)

val project_root_path : project -> string
(** [project_root_path p] returns [project_root p] as a string. *)

val project_relative_path : project -> path -> string
(** [project_relative_path p file] returns [file] relative to [p]'s project root
    when possible. *)

val resolve : project -> Fpath.t -> path
(** [resolve p file] resolves [file] against [p]'s project root. Relative source
    paths accepted from the CLI or project index are normalized without
    consulting the process current directory. Raises [Invalid_argument] if the
    normalized path escapes the project root. *)

val resolve_path : project -> Fpath.t -> string
(** [resolve_path p file] is [resolve p file] as a string. *)

val executable_modules : project -> string list
(** [executable_modules project] returns executable module names. *)

val lib_modules : project -> string list
(** [lib_modules project] returns library module names. *)

val test_modules : project -> string list
(** [test_modules project] returns test module names. *)

val executable_stanzas : project -> Project_index.source_stanza list
(** [executable_stanzas project] returns the executable stanzas discovered by
    the shared project index. *)

val test_stanzas : project -> Project_index.source_stanza list
(** [test_stanzas project] returns the test stanzas discovered by the shared
    project index. *)

val file_view : project -> path -> File_view.t
(** [file_view project filename] returns the shared, lazy file view for
    [filename]. *)

val file_content : project -> path -> string
(** [file_content project filename] returns the shared raw file bytes for
    [filename]. *)
