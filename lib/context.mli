(** Context for rule checking - holds all parameters and data needed by rules *)

exception Analysis_error of string
(** Raised when analysis fails (e.g., Merlin error, file read error) *)

type file = {
  filename : string;  (** The current file being analyzed *)
  config : Config.t;  (** The merlint configuration *)
  project_root : string;  (** The project root directory *)
  ast : Ast.t Lazy.t;  (** AST from Merlin typedtree dump (lazy) *)
  outline : Outline.t Lazy.t;  (** Outline from Merlin (lazy) *)
  content : string Lazy.t;  (** File content (lazy) *)
}

type project = {
  config : Config.t;  (** The merlint configuration *)
  project_root : string;  (** The project root directory *)
  all_files : string list Lazy.t;  (** All files in the project (lazy) *)
  dune_describe : Dune.describe Lazy.t;  (** Dune project description (lazy) *)
  executable_modules : string list Lazy.t;
      (** List of executable module names (lazy) *)
  lib_modules : string list Lazy.t;  (** List of library module names (lazy) *)
  test_modules : string list Lazy.t;  (** List of test module names (lazy) *)
}

val create_file :
  filename:string ->
  config:Config.t ->
  project_root:string ->
  merlin_result:Merlin.t ->
  file
(** Create a file context from the given parameters *)

val create_project :
  config:Config.t ->
  project_root:string ->
  all_files:string list ->
  dune_describe:Dune.describe ->
  project
(** Create a project context from the given parameters *)

(* File context accessors *)
val ast : file -> Ast.t
(** Force evaluation of the ast field, raising an exception if it's an error *)

val outline : file -> Outline.t
(** Force evaluation of the outline field, raising an exception if it's an error
*)

val content : file -> string
(** Force evaluation of the content field *)

(* Project context accessors *)
val all_files : project -> string list
(** Force evaluation of the all_files field *)

val executable_modules : project -> string list
(** Get the list of executable module names *)

val lib_modules : project -> string list
(** Get the list of library module names *)

val test_modules : project -> string list
(** Get the list of test module names *)
