(** Context for rule checking - holds all parameters and data needed by rules *)

exception Analysis_error of string
(** Raised when analysis fails (e.g., Merlin error, file read error) *)

type file_context = {
  filename : string;  (** The current file being analyzed *)
  config : Config.t;  (** The merlint configuration *)
  project_root : string;  (** The project root directory *)
  browse : Browse.t Lazy.t;  (** Browse tree from Merlin (lazy) *)
  ast : Ast.t Lazy.t;
      (** AST from Merlin (lazy) - falls back to parsetree if typedtree fails *)
  outline : Outline.t Lazy.t;  (** Outline from Merlin (lazy) *)
  content : string Lazy.t;  (** File content (lazy) *)
}

type project_context = {
  config : Config.t;  (** The merlint configuration *)
  project_root : string;  (** The project root directory *)
  all_files : string list Lazy.t;  (** All files in the project (lazy) *)
  dune_describe : Dune.describe Lazy.t;  (** Dune project description (lazy) *)
  executable_modules : string list Lazy.t;
      (** List of executable module names (lazy) *)
  lib_modules : string list Lazy.t;  (** List of library module names (lazy) *)
  test_modules : string list Lazy.t;  (** List of test module names (lazy) *)
}

type t = File of file_context | Project of project_context

val create_file :
  filename:string ->
  config:Config.t ->
  project_root:string ->
  merlin_result:Merlin.t ->
  file_context
(** Create a file context from the given parameters *)

val create_project :
  config:Config.t ->
  project_root:string ->
  all_files:string list ->
  dune_describe:Dune.describe ->
  project_context
(** Create a project context from the given parameters *)

val filename : t -> string
(** Get filename from context (fails for project context) *)

val config : t -> Config.t
(** Get config from any context *)

val project_root : t -> string
(** Get project root from any context *)

val browse : t -> Browse.t
(** Force evaluation of the browse field, raising an exception if it's an error
    or project context *)

val ast : t -> Ast.t
(** Force evaluation of the ast field, raising an exception if it's an error or
    project context *)

val outline : t -> Outline.t
(** Force evaluation of the outline field, raising an exception if it's an error
    or project context *)

val content : t -> string
(** Force evaluation of the content field (fails for project context) *)

val all_files : t -> string list
(** Force evaluation of the all_files field (fails for file context) *)

val dune_describe : t -> Dune.describe
(** Force evaluation of the dune_describe field (fails for file context) *)

val executable_modules : t -> string list
(** Get the list of executable module names (fails for file context) *)

val lib_modules : t -> string list
(** Get the list of library module names (fails for file context) *)

val test_modules : t -> string list
(** Get the list of test module names (fails for file context) *)
